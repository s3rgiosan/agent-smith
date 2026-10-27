#!/usr/bin/env bash
# Re-exec under real bash if invoked via sh/dash or bash-in-POSIX-mode
# (this script uses process substitution, which POSIX sh rejects at parse time).
if ! (eval ': < <(:)') 2>/dev/null; then
  exec bash "$0" "$@"
fi
# =============================================================================
# manage_claude_projects.sh
# Lists every project a Claude Code home knows about and lets you move or
# purge them. Move rewrites a project's state after its folder moved; purge
# removes its sessions and config entry (memory is kept unless you say so).
#
# Usage:
#   ./manage_claude_projects.sh [--claude <claude_dir>] [--dry-run]
#   ./manage_claude_projects.sh --old <old_dir> --new <new_dir> [--claude <claude_dir>]
#
# Examples:
#   # Open the project list for ~/.claude
#   ./manage_claude_projects.sh
#
#   # Use another Claude home (one set through CLAUDE_CONFIG_DIR)
#   ./manage_claude_projects.sh --claude /Users/MrAnderson/.claude-work
#
#   # Move without the list (no confirmation)
#   ./manage_claude_projects.sh \
#     --old /Users/MrAnderson/projects \
#     --new /Users/MrAnderson/work/projects
#
# Keys:
#   ↑/↓ or k/j  Move cursor         space  Tick / untick the current row
#   PgUp/PgDn   Jump by page        a      Tick / untick all
#   g/G         Top / bottom        m      Move the project under the cursor
#   q           Quit                d      Purge the ticked projects
#                                          (the cursor row when none is ticked)
#
# Flags:
#   --claude   Path to the Claude home (default: ~/.claude)
#   --old      Original project path; with --new, moves without the list
#   --new      New project path
#   --dry-run  Preview every action without writing anything
#   --backup   Keep .bak copies of files a move rewrites
#   --no-tilde Skip the extra tilde pass (~/foo refs) on a move
#   --help     Show this help message
#
# Requires python3.
# =============================================================================

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
CLAUDE_DIR="${HOME}/.claude"
OLD_DIR=""
NEW_DIR=""
DRY_RUN=false
BACKUP=false
NO_TILDE=false

# ── Colors ────────────────────────────────────────────────────────────────────
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
DIM=$'\033[2m'
BOLD=$'\033[1m'
RESET=$'\033[0m'

# ── Helpers ───────────────────────────────────────────────────────────────────
usage() {
  grep '^#' "$0" \
    | grep -v '^#!' \
    | grep -v '^# =\{3,\}' \
    | sed 's/^# \{0,2\}//'
  exit 0
}

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }

print_banner() {
  echo ""
  echo -e "${BOLD}╔══════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}║   Claude Projects                        ║${RESET}"
  echo -e "${BOLD}╚══════════════════════════════════════════╝${RESET}"
  echo ""
}

print_modes() {
  $DRY_RUN && warn "DRY-RUN mode — no files will be modified."
  $BACKUP  && info  "Backup mode — .bak copies will be kept."
  return 0
}

# Claude names a project's folder by replacing every non-alphanumeric char of
# its absolute path with '-'. E.g.
#   /Users/MrAnderson/my project → -Users-MrAnderson-my-project
encode_path() {
  printf '%s' "$1" | sed 's/[^A-Za-z0-9]/-/g'
}

# Removes a project folder's memory/ when it holds nothing but .DS_Store, so
# it does not keep the folder alive.
remove_empty_memory() {
  local memory="$1/memory"
  [[ -d "$memory" && ! -L "$memory" ]] || return 0
  rm -f "$memory/.DS_Store"
  rmdir "$memory" 2>/dev/null || true
}

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --claude)   CLAUDE_DIR="$2"; shift 2 ;;
    --old)      OLD_DIR="$2";    shift 2 ;;
    --new)      NEW_DIR="$2";    shift 2 ;;
    --dry-run)  DRY_RUN=true;    shift ;;
    --backup)   BACKUP=true;     shift ;;
    --no-tilde) NO_TILDE=true;   shift ;;
    --help|-h)  usage ;;
    *) error "Unknown argument: $1. Run with --help for usage." ;;
  esac
done

# ── Validation ────────────────────────────────────────────────────────────────
CLAUDE_DIR="${CLAUDE_DIR%/}"
[[ -d "$CLAUDE_DIR" ]] || error "Claude directory not found: $CLAUDE_DIR"
CLAUDE_DIR=$(cd "$CLAUDE_DIR" && pwd)
command -v python3 >/dev/null 2>&1 || error "python3 is required."

PROJECTS_ROOT="$CLAUDE_DIR/projects"

# Claude Code keeps its config at ~/.claude.json for the default home and at
# <dir>/.claude.json for a home set through CLAUDE_CONFIG_DIR.
if [[ "$CLAUDE_DIR" == "$HOME/.claude" ]]; then
  CONFIG_FILE="$HOME/.claude.json"
else
  CONFIG_FILE="$CLAUDE_DIR/.claude.json"
fi

# ── Project rows ──────────────────────────────────────────────────────────────
R_PATH=()
R_SLUG=()
R_SESSIONS=()
R_LATEST=()
R_MISSING=()
R_MEMORY=()
R_CONFIG_ONLY=()

# Fills the R_* arrays with one row per project: every folder under projects/
# plus every config key without a folder. The folder encoding is lossy, so a
# folder's real path comes from the config key that encodes to it, else from
# the first session cwd that encodes to it, else from a history.jsonl project
# that encodes to it; R_PATH stays empty when none exists.
load_projects() {
  R_PATH=(); R_SLUG=(); R_SESSIONS=(); R_LATEST=()
  R_MISSING=(); R_MEMORY=(); R_CONFIG_ONLY=()

  local path slug sessions latest missing memory config_only
  while IFS= read -r -d '' path && IFS= read -r -d '' slug \
     && IFS= read -r -d '' sessions && IFS= read -r -d '' latest \
     && IFS= read -r -d '' missing && IFS= read -r -d '' memory \
     && IFS= read -r -d '' config_only; do
    R_PATH+=("$path")
    R_SLUG+=("$slug")
    R_SESSIONS+=("$sessions")
    R_LATEST+=("$latest")
    R_MISSING+=("$missing")
    R_MEMORY+=("$memory")
    R_CONFIG_ONLY+=("$config_only")
  done < <(python3 - "$CONFIG_FILE" "$PROJECTS_ROOT" "$CLAUDE_DIR/history.jsonl" <<'PY'
import json, os, re, sys, time

cfg, root, hist = sys.argv[1], sys.argv[2], sys.argv[3]
uuid_re = re.compile(r"^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$")
cwd_re = re.compile(r'"cwd":"((?:[^"\\]|\\.)*)"')


def encode(path):
    return re.sub(r"[^A-Za-z0-9]", "-", path)


keys = []
try:
    with open(cfg) as fh:
        keys = [k for k in json.load(fh).get("projects", {}) if k.startswith("/")]
except (OSError, ValueError):
    pass

key_by_slug = {}
for key in sorted(keys):
    key_by_slug.setdefault(encode(key), key)

history_by_slug = {}
try:
    with open(hist, encoding="utf-8", errors="ignore") as fh:
        for line in fh:
            try:
                project = json.loads(line).get("project")
            except (ValueError, AttributeError):
                continue
            if isinstance(project, str) and project.startswith("/"):
                history_by_slug.setdefault(encode(project), project)
except OSError:
    pass

folders = sorted(os.listdir(root)) if os.path.isdir(root) else []
folders = [f for f in folders if os.path.isdir(os.path.join(root, f))]


def from_sessions(folder):
    # A session can cd elsewhere, so take the first cwd that encodes to the folder.
    for dirpath, _, files in os.walk(folder):
        for name in files:
            if not name.endswith(".jsonl"):
                continue
            try:
                with open(os.path.join(dirpath, name), errors="ignore") as fh:
                    for line in fh:
                        for match in cwd_re.finditer(line):
                            path = json.loads('"' + match.group(1) + '"')
                            if encode(path) == os.path.basename(folder):
                                return path
            except (OSError, ValueError):
                pass
    return ""


def has_memory(folder):
    # An empty memory/ folder (or one with only .DS_Store) holds nothing.
    if os.path.isfile(os.path.join(folder, "MEMORY.md")):
        return True
    try:
        return any(name != ".DS_Store" for name in os.listdir(os.path.join(folder, "memory")))
    except OSError:
        return False


def folder_stats(folder):
    sessions, newest = set(), 0
    for name in os.listdir(folder):
        stem = name[:-6] if name.endswith(".jsonl") else name
        if uuid_re.match(stem):
            sessions.add(stem)
    for dirpath, _, files in os.walk(folder):
        for name in files:
            if name.endswith(".jsonl"):
                try:
                    newest = max(newest, os.path.getmtime(os.path.join(dirpath, name)))
                except OSError:
                    pass
    latest = time.strftime("%Y-%m-%d %H:%M", time.localtime(newest)) if newest else "-"
    return len(sessions), latest, has_memory(folder)


rows, used = [], set()
for slug in folders:
    folder = os.path.join(root, slug)
    path = key_by_slug.get(slug) or from_sessions(folder) or history_by_slug.get(slug, "")
    used.add(path)
    sessions, latest, memory = folder_stats(folder)
    rows.append((path, slug, sessions, latest, memory, False))
for key in keys:
    if key not in used:
        rows.append((key, encode(key), 0, "-", False, True))

resolved = sorted((r for r in rows if r[0]), key=lambda r: r[0].split("/"))
unresolved = sorted((r for r in rows if not r[0]), key=lambda r: r[1])
for path, slug, sessions, latest, memory, config_only in resolved + unresolved:
    missing = bool(path) and not os.path.exists(path)
    fields = [path, slug, str(sessions), latest, str(int(missing)), str(int(memory)), str(int(config_only))]
    sys.stdout.write("\0".join(fields) + "\0")
PY
  )
}

# Prints row i's path, or its folder name dimmed when the path is unknown.
row_label() {
  if [[ -n "${R_PATH[$1]}" ]]; then
    printf '%s' "${R_PATH[$1]}"
  else
    printf '%s' "${DIM}${R_SLUG[$1]}${RESET}"
  fi
}

MARKERS=""
MARKERS_PLAIN=""

# Sets MARKERS (colored) and MARKERS_PLAIN to row i's markers:
# [missing] [memory] [config only]. An optional width keeps only the markers
# that fit in it.
row_markers() {
  local max="${2:-9999}"
  MARKERS=""
  MARKERS_PLAIN=""
  if [[ "${R_MISSING[$1]}" == "1" ]] && (( ${#MARKERS_PLAIN} + 10 <= max )); then
    MARKERS+=" ${RED}[missing]${RESET}"
    MARKERS_PLAIN+=" [missing]"
  fi
  if [[ "${R_MEMORY[$1]}" == "1" ]] && (( ${#MARKERS_PLAIN} + 9 <= max )); then
    MARKERS+=" ${YELLOW}[memory]${RESET}"
    MARKERS_PLAIN+=" [memory]"
  fi
  if [[ "${R_CONFIG_ONLY[$1]}" == "1" ]] && (( ${#MARKERS_PLAIN} + 14 <= max )); then
    MARKERS+=" ${DIM}[config only]${RESET}"
    MARKERS_PLAIN+=" [config only]"
  fi
  return 0
}

FITTED=""

# Sets FITTED to text cut to width chars. The end is kept, since a path's
# tail is what tells projects apart.
fit_left() {
  local text="$1" width="$2"
  if (( width < 2 )); then
    FITTED=""
  elif (( ${#text} > width )); then
    FITTED="…${text: -$((width - 1))}"
  else
    FITTED="$text"
  fi
}

# ── Move ──────────────────────────────────────────────────────────────────────
MOVED_DIRS=0
CHANGED_FILES=0

# Detect sed in-place flag (BSD vs GNU); set once BACKUP is known.
sed_inplace() {
  if sed --version 2>/dev/null | grep -q 'GNU'; then
    if $BACKUP; then SED_INPLACE=(-i.bak); else SED_INPLACE=(-i); fi
  else
    # macOS / BSD sed requires explicit suffix (empty string = no backup)
    if $BACKUP; then SED_INPLACE=(-i .bak); else SED_INPLACE=(-i ''); fi
  fi
}

# Pattern side (sed BRE): escape \ / . * [ ] ^ $
escape_pattern() {
  printf '%s' "$1" | sed 's/[][\\/.*^$]/\\&/g'
}
# Replacement side: escape \ / &
escape_replacement() {
  printf '%s' "$1" | sed 's/[\\/&]/\\&/g'
}
# Pattern side (grep ERE): also escape + ? ( ) { } |
escape_ere() {
  printf '%s' "$1" | sed 's/[][\\.^$*+?(){}|/]/\\&/g'
}

# A path ends a segment when the next char is NOT a name char. Anchoring the
# match to such a boundary (or end-of-line) stops OLD from clobbering siblings
# that merely share it as a prefix (e.g. /x/proj vs /x/proj-v2).
SEGMENT_CHARS='A-Za-z0-9._-'

# Prints a reason and returns 1 when old → new cannot be moved.
check_move() {
  local old="$1" new="$2"
  if [[ "$old" != /* || "$new" != /* ]]; then
    warn "Both paths must be absolute."
    return 1
  fi
  if [[ "$old" == "$new" ]]; then
    warn "Old and new paths are identical. Nothing to do."
    return 1
  fi
  if [[ "$CLAUDE_DIR" == "$old" || "$CLAUDE_DIR" == "$old"/* ]]; then
    warn "${old} contains the Claude home; moving it would corrupt the replacements."
    return 1
  fi
  # Checked before any write so a bad config cannot leave a half-done move.
  if [[ -f "$CONFIG_FILE" ]] && ! python3 -c 'import json, sys; json.load(open(sys.argv[1]))' "$CONFIG_FILE" 2>/dev/null; then
    warn "Config is not valid JSON: ${CONFIG_FILE}"
    return 1
  fi
  return 0
}

MOVE_ROWS=()
MOVE_SKIPPED=()

# Sets MOVE_ROWS to the rows whose projects/ folder belongs to old or a
# sub-path of it, and MOVE_SKIPPED to folders whose name matches old but whose
# path is unknown. A folder qualifies by its resolved path: the encoded name
# alone cannot tell a child (/x/proj/v2) from a sibling (/x/proj-v2).
move_rows() {
  local old="$1" old_enc i path slug
  old_enc=$(encode_path "$old")
  MOVE_ROWS=()
  MOVE_SKIPPED=()

  for i in "${!R_PATH[@]}"; do
    path="${R_PATH[$i]}"
    slug="${R_SLUG[$i]}"
    # A config-only row's slug can name another project's folder.
    [[ "${R_CONFIG_ONLY[$i]}" == "1" ]] && continue
    [[ -d "$PROJECTS_ROOT/$slug" ]] || continue

    if [[ -z "$path" ]]; then
      [[ "$slug" == "$old_enc"* ]] && MOVE_SKIPPED+=("$slug")
      continue
    fi
    [[ "$path" == "$old" || "$path" == "$old"/* ]] && MOVE_ROWS+=("$i")
  done
  return 0
}

# Prints the folders a move edits: each moving folder, plus the target it
# merges into when that already exists.
move_dirs() {
  local old="$1" new="$2" i src target
  for i in ${MOVE_ROWS[@]+"${MOVE_ROWS[@]}"}; do
    src="$PROJECTS_ROOT/${R_SLUG[$i]}"
    target="$PROJECTS_ROOT/$(encode_path "${new}${R_PATH[$i]#"$old"}")"
    echo "$src"
    [[ -d "$target" && "$target" != "$src" ]] && echo "$target"
  done
  return 0
}

# Renames the folders in MOVE_ROWS to their place under new.
move_folders() {
  local old="$1" new="$2"
  local i path slug src target_slug target entry kept

  for i in ${MOVE_ROWS[@]+"${MOVE_ROWS[@]}"}; do
    path="${R_PATH[$i]}"
    slug="${R_SLUG[$i]}"
    src="$PROJECTS_ROOT/$slug"
    target_slug=$(encode_path "${new}${path#"$old"}")
    target="$PROJECTS_ROOT/$target_slug"
    [[ "$src" == "$target" ]] && continue

    if [[ ! -e "$target" ]]; then
      if $DRY_RUN; then
        echo -e "  ${YELLOW}[DRY-RUN]${RESET} Would rename: projects/${slug} → projects/${target_slug}"
      else
        mv "$src" "$target"
        success "Renamed: projects/${slug} → projects/${target_slug}"
      fi
    elif $DRY_RUN; then
      echo -e "  ${YELLOW}[DRY-RUN]${RESET} Would merge: projects/${slug} → projects/${target_slug}"
    else
      # Move what the target lacks; anything it already has stays in the source.
      while IFS= read -r -d '' entry; do
        [[ -e "$target/$(basename "$entry")" ]] || mv "$entry" "$target/"
      done < <(find "$src" -mindepth 1 -maxdepth 1 -print0)
      remove_empty_memory "$src"
      rm -f "$src/.DS_Store"
      if rmdir "$src" 2>/dev/null; then
        success "Merged: projects/${slug} → projects/${target_slug}"
      else
        kept=$(find "$src" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')
        warn "Kept ${src}: ${kept} entries already exist in projects/${target_slug}."
      fi
    fi
    MOVED_DIRS=$((MOVED_DIRS + 1))
  done

  if [[ ${#MOVE_SKIPPED[@]} -gt 0 ]]; then
    warn "Skipped folders whose path is unknown (their name matches $(encode_path "$old")):"
    printf '  %s\n' "${MOVE_SKIPPED[@]}"
  fi
  return 0
}

# Rewrites old → new in the text files under the given folders.
run_sweep() {
  local old="$1" new="$2" label="$3"
  shift 3
  local old_esc new_esc old_ere
  [[ $# -gt 0 ]] || return 0
  old_esc=$(escape_pattern "$old")
  new_esc=$(escape_replacement "$new")
  old_ere=$(escape_ere "$old")

  info "Scanning files (${label}): ${old} → ${new}"

  local matched=()
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ -L "$file" ]] && continue
    matched+=("$file")
  done < <(grep -rlIE \
    --exclude-dir=.git \
    --exclude-dir=node_modules \
    -- "${old_ere}([^${SEGMENT_CHARS}]|\$)" "$@" 2>/dev/null || true)

  local count=${#matched[@]}
  if [[ $count -eq 0 ]]; then
    return 0
  fi

  if $DRY_RUN; then
    local cap=20 shown=0
    for f in "${matched[@]}"; do
      echo -e "  ${YELLOW}[DRY-RUN]${RESET} Would update: ${f}"
      ((shown+=1))
      if [[ $shown -ge $cap && $count -gt $cap ]]; then
        echo -e "  ${YELLOW}... and $((count - cap)) more${RESET}"
        break
      fi
    done
  else
    info "Applying sed to ${count} file(s)..."
    printf '%s\0' "${matched[@]}" \
      | xargs -0 sed "${SED_INPLACE[@]}" \
          -e "s/${old_esc}\\([^${SEGMENT_CHARS}]\\)/${new_esc}\\1/g" \
          -e "s/${old_esc}\$/${new_esc}/g"
    success "Updated ${count} file(s)."
  fi

  CHANGED_FILES=$((CHANGED_FILES + count))
}

# Rewrites every string key and value of the config file for each old/new
# pair, at path-segment boundaries. When a renamed key collides with an
# existing one, the existing entry wins and the moved entry fills the fields
# it lacks.
rewrite_config() {
  [[ -f "$CONFIG_FILE" ]] || return 0

  local dry=0 backup=0 changed
  $DRY_RUN && dry=1
  $BACKUP && backup=1

  changed=$(python3 - "$CONFIG_FILE" "$dry" "$backup" "$@" <<'PY'
import json, re, shutil, sys

cfg, dry, backup = sys.argv[1], sys.argv[2] == "1", sys.argv[3] == "1"
pairs = sys.argv[4:]
rules = [
    (re.compile(re.escape(pairs[i]) + r"(?=[^A-Za-z0-9._-]|$)"), pairs[i + 1])
    for i in range(0, len(pairs), 2)
]


def rewrite(text):
    for pattern, new in rules:
        text = pattern.sub(lambda _: new, text)
    return text


def merge(winner, loser):
    if not (isinstance(winner, dict) and isinstance(loser, dict)):
        return winner
    out = dict(winner)
    for key, value in loser.items():
        out[key] = merge(out[key], value) if key in out else value
    return out


def walk(node):
    if isinstance(node, dict):
        out = {}
        for key, value in node.items():
            new_key, new_value = rewrite(key), walk(value)
            if new_key not in out:
                out[new_key] = new_value
            elif new_key == key:
                # The unrenamed key is the existing entry: it wins.
                out[new_key] = merge(new_value, out[new_key])
            else:
                out[new_key] = merge(out[new_key], new_value)
        return out
    if isinstance(node, list):
        return [walk(item) for item in node]
    if isinstance(node, str):
        return rewrite(node)
    return node


with open(cfg) as fh:
    text = fh.read()
data = json.loads(text)
result = walk(data)
if result == data:
    print(0)
    sys.exit(0)
print(1)
if not dry:
    if backup:
        shutil.copy2(cfg, cfg + ".bak")
    with open(cfg, "w") as fh:
        json.dump(result, fh, indent=2, ensure_ascii=False)
        if text.endswith("\n"):
            fh.write("\n")
PY
  )

  [[ "$changed" == "1" ]] || return 0
  info "Scanning config: ${CONFIG_FILE}"
  if $DRY_RUN; then
    echo -e "  ${YELLOW}[DRY-RUN]${RESET} Would update: ${CONFIG_FILE}"
  else
    success "Updated config: ${CONFIG_FILE}"
  fi
  CHANGED_FILES=$((CHANGED_FILES + 1))
}

# Rewrites the "project" field of history.jsonl entries for old and its
# sub-paths, so prompt history follows the project. Prompt text is kept.
rewrite_history() {
  local old="$1" new="$2" hist="$CLAUDE_DIR/history.jsonl" dry=0 backup=0 changed
  [[ -f "$hist" ]] || return 0
  $DRY_RUN && dry=1
  $BACKUP && backup=1

  changed=$(python3 - "$hist" "$old" "$new" "$dry" "$backup" <<'PY'
import json, shutil, sys

hist, old, new = sys.argv[1:4]
dry, backup = sys.argv[4] == "1", sys.argv[5] == "1"
out, changed = [], 0
with open(hist, encoding="utf-8") as fh:
    for line in fh:
        try:
            entry = json.loads(line)
        except ValueError:
            out.append(line)
            continue
        project = entry.get("project") if isinstance(entry, dict) else None
        if isinstance(project, str) and (project == old or project.startswith(old + "/")):
            entry["project"] = new + project[len(old):]
            line = json.dumps(entry, ensure_ascii=False, separators=(",", ":")) + "\n"
            changed += 1
        out.append(line)
print(changed)
if changed and not dry:
    if backup:
        shutil.copy2(hist, hist + ".bak")
    with open(hist, "w", encoding="utf-8") as fh:
        fh.writelines(out)
PY
  )

  [[ "${changed:-0}" != "0" ]] || return 0
  if $DRY_RUN; then
    echo -e "  ${YELLOW}[DRY-RUN]${RESET} Would update: ${hist} (${changed} prompt(s))"
  else
    success "Updated ${hist} (${changed} prompt(s))"
  fi
  CHANGED_FILES=$((CHANGED_FILES + 1))
}

# Moves old to new: the projects/ folders, the text inside them, the config
# and the prompt history. Other projects and the rest of the Claude home are
# left as they are. Uses the current R_* rows to resolve folders. Honors
# DRY_RUN.
run_move() {
  local old="$1" new="$2"
  MOVED_DIRS=0
  CHANGED_FILES=0
  sed_inplace

  move_rows "$old"
  local dirs=() dir
  while IFS= read -r dir; do
    dirs+=("$dir")
  done < <(move_dirs "$old" "$new")

  local pairs=("$old" "$new")
  run_sweep "$old" "$new" "absolute" ${dirs[@]+"${dirs[@]}"}

  # Tilde pass: rewrite ~/... forms when old is under $HOME.
  if ! $NO_TILDE && [[ -n "${HOME:-}" && ( "$old" == "$HOME" || "$old" == "$HOME"/* ) ]]; then
    local old_tilde new_tilde
    old_tilde="~${old#"$HOME"}"
    if [[ "$new" == "$HOME" || "$new" == "$HOME"/* ]]; then
      new_tilde="~${new#"$HOME"}"
    else
      new_tilde="$new"
    fi
    echo ""
    run_sweep "$old_tilde" "$new_tilde" "tilde" ${dirs[@]+"${dirs[@]}"}
    pairs+=("$old_tilde" "$new_tilde")
  fi

  rewrite_config "${pairs[@]}"
  rewrite_history "$old" "$new"
  echo ""
  move_folders "$old" "$new"

  echo ""
  echo -e "${BOLD}── Summary ────────────────────────────────${RESET}"
  if $DRY_RUN; then
    echo -e "  Files that ${YELLOW}would be updated${RESET}: ${CHANGED_FILES}"
    echo -e "  Dirs that ${YELLOW}would be moved${RESET}   : ${MOVED_DIRS}"
  else
    echo -e "  Files updated   : ${GREEN}${CHANGED_FILES}${RESET}"
    echo -e "  Dirs moved      : ${GREEN}${MOVED_DIRS}${RESET}"
  fi
  echo ""

  if [[ $CHANGED_FILES -eq 0 && $MOVED_DIRS -eq 0 ]]; then
    warn "Nothing matched ${old}."
  elif ! $DRY_RUN; then
    success "Moved ${old} → ${new}."
  fi
  return 0
}

# ── Picker ────────────────────────────────────────────────────────────────────
TUI_ACTION=""
TUI_CURSOR=0
TUI_TICKED=()

tui_cleanup() {
  # stty -g output is space-separated — must be unquoted so stty parses tokens.
  if [[ -n "${TUI_STTY_SAVE:-}" ]]; then
    stty $TUI_STTY_SAVE 2>/dev/null || stty sane
  else
    stty sane 2>/dev/null || true
  fi
  tput cnorm 2>/dev/null || true
  printf '\n'
}

# Shows the list until an action key. Sets TUI_ACTION (move|purge|quit),
# TUI_CURSOR and TUI_TICKED. Starts with the cursor at TUI_CURSOR.
tui_list() {
  local n=${#R_PATH[@]}
  local sel=() cursor=$TUI_CURSOR offset=0 i
  for ((i=0; i<n; i++)); do sel+=(0); done
  (( cursor > n - 1 )) && cursor=$((n - 1))

  tput civis 2>/dev/null || true
  stty -echo -icanon min 1 time 0

  local key key2 key3 count_sel
  while true; do
    local lines cols rows width sep k size budget path_min
    # stty reads the size from the terminal on stdin. tput inside $(…) sees a
    # pipe on stdout and falls back to 80x24.
    size=$(stty size 2>/dev/null) || size=""
    lines=${size% *}
    cols=${size#* }
    [[ "$lines" =~ ^[1-9][0-9]*$ ]] || lines=$(tput lines 2>/dev/null || echo 24)
    [[ "$cols" =~ ^[1-9][0-9]*$ ]] || cols=$(tput cols 2>/dev/null || echo 80)
    rows=$((lines - 5))
    (( rows < 3 )) && rows=3
    # Every line stays narrower than the terminal: a wrapped line makes the
    # screen taller than the terminal and scrolls the footer up.
    width=$((cols - 1))
    sep=""
    for ((k=0; k<width && k<60; k++)); do sep+="─"; done

    (( cursor < offset ))            && offset=$cursor
    (( cursor >= offset + rows ))    && offset=$((cursor - rows + 1))
    (( offset < 0 ))                 && offset=0

    count_sel=0
    for ((i=0; i<n; i++)); do (( sel[i] == 1 )) && count_sel=$((count_sel + 1)); done

    tput clear
    local counter="${count_sel}/${n} selected"
    fit_left "$CLAUDE_DIR" $((width - ${#counter} - 21))
    printf "${BOLD}Claude Projects${RESET}  ${DIM}(%s)${RESET}  ${CYAN}%s${RESET}\n" "$FITTED" "$counter"
    printf "${DIM}%s${RESET}\n" "$sep"

    local end=$((offset + rows))
    (( end > n )) && end=$n
    for ((i=offset; i<end; i++)); do
      local mark="[ ]" pointer="  " row_color="" label="${R_PATH[$i]}" label_color=""
      (( sel[i] == 1 )) && mark="${GREEN}[✓]${RESET}"
      if (( i == cursor )); then
        pointer="${BOLD}▶ ${RESET}"
        row_color="$BOLD"
      fi
      if [[ -z "$label" ]]; then
        label="${R_SLUG[$i]}"
        label_color="$DIM"
      fi
      # 38 = pointer, checkbox, date and session columns. The path keeps up
      # to 24 chars; markers get what is left.
      budget=$((width - 38))
      path_min=${#label}
      (( path_min > 24 )) && path_min=24
      row_markers "$i" $((budget - path_min))
      fit_left "$label" $((budget - ${#MARKERS_PLAIN}))
      printf "%b%s ${CYAN}%-16s${RESET}  %b%3d sessions${RESET}  %s%s${RESET}%s\n" \
        "$pointer" "$mark" "${R_LATEST[$i]}" "$row_color" "${R_SESSIONS[$i]}" "$label_color" "$FITTED" "$MARKERS"
    done

    local remaining=$((rows - (end - offset)))
    for ((i=0; i<remaining; i++)); do echo ""; done

    printf "${DIM}%s${RESET}\n" "$sep"
    if (( width >= 90 )); then
      printf "${BOLD}↑/↓${RESET} or ${BOLD}j/k${RESET} move  ${BOLD}PgUp/PgDn${RESET} page  ${BOLD}g/G${RESET} top/bot  ${BOLD}space${RESET} toggle  ${BOLD}a${RESET} all  ${BOLD}m${RESET} move  ${BOLD}d${RESET} purge  ${BOLD}q${RESET} quit"
    elif (( width >= 54 )); then
      printf "${BOLD}j/k${RESET} move  ${BOLD}space${RESET} toggle  ${BOLD}a${RESET} all  ${BOLD}m${RESET} move  ${BOLD}d${RESET} purge  ${BOLD}q${RESET} quit"
    else
      printf "${BOLD}m${RESET} move  ${BOLD}d${RESET} purge  ${BOLD}q${RESET} quit"
    fi

    IFS= read -rsn1 key
    if [[ "$key" == $'\e' ]]; then
      # Bash 3.2 timeout must be integer; arrow seqs arrive instantly so 1s is fine.
      IFS= read -rsn2 -t 1 key2 2>/dev/null || key2=""
      # Page Up/Down deliver 4 chars total (\e[5~ or \e[6~) — try to slurp the tilde.
      if [[ "$key2" == "[5" || "$key2" == "[6" ]]; then
        key3=""
        IFS= read -rsn1 -t 1 key3 2>/dev/null || key3=""
        key2="$key2$key3"
      fi
      key="$key$key2"
    fi

    case "$key" in
      j|$'\e[B')   (( cursor < n - 1 )) && cursor=$((cursor + 1)) ;;
      k|$'\e[A')   (( cursor > 0 )) && cursor=$((cursor - 1)) ;;
      $'\e[6~')    cursor=$((cursor + rows)); (( cursor > n - 1 )) && cursor=$((n - 1)) ;;
      $'\e[5~')    cursor=$((cursor - rows)); (( cursor < 0 )) && cursor=0 ;;
      g)           cursor=0 ;;
      G)           cursor=$((n - 1)) ;;
      ' ')         sel[$cursor]=$((1 - sel[$cursor])) ;;
      a|A)
        local all=1
        for ((i=0; i<n; i++)); do (( sel[i] == 0 )) && { all=0; break; }; done
        local new=$((1 - all))
        for ((i=0; i<n; i++)); do sel[$i]=$new; done
        ;;
      m|M)         TUI_ACTION=move;  break ;;
      d|D)         TUI_ACTION=purge; break ;;
      q|Q|$'\e')   TUI_ACTION=quit;  break ;;
    esac
  done

  tui_cleanup

  TUI_CURSOR=$cursor
  TUI_TICKED=()
  for ((i=0; i<n; i++)); do
    (( sel[i] == 1 )) && TUI_TICKED+=("$i")
  done
  return 0
}

# ── Actions ───────────────────────────────────────────────────────────────────
PROMPTED=""

# Prints the absolute, normalized form of a typed path: ~ expanded, relative
# paths resolved against the current directory, '.', '..' and trailing '/'
# collapsed.
expand_path() {
  local input="$1"
  [[ -z "$input" ]] && return 0
  [[ "$input" == "~" || "$input" == "~/"* ]] && input="${HOME}${input#\~}"
  [[ "$input" != /* ]] && input="${PWD}/${input}"
  python3 -c 'import os, sys; sys.stdout.write(os.path.normpath(sys.argv[1]))' "$input"
}

READ_INPUT=""

# Reads a path with readline, so tab-completion works. Sets READ_INPUT;
# returns 1 on Ctrl-D. Readline on bash 3.2 leaves the terminal in a state
# where Ctrl-C no longer interrupts later reads, so the state is restored.
read_path() {
  local saved rc=0
  saved=$(stty -g)
  # No -r: readline tab-completion escapes spaces as '\ ', which read unescapes.
  read -e -p "$1" READ_INPUT || rc=1
  # stty -g output is space-separated — must be unquoted so stty parses tokens.
  stty $saved
  return $rc
}

pause() {
  read -rsn1 -p "Press any key to return to the list..." _ || true
  echo ""
}

# Asks for the real path of an unresolved row until one encodes to its
# folder name. Sets PROMPTED; returns 1 on empty input or Ctrl-D.
prompt_old_path() {
  local slug="$1" input
  while true; do
    read_path "Old path: " || { echo ""; return 1; }
    input="$READ_INPUT"
    input=$(expand_path "$input")
    [[ -z "$input" ]] && return 1
    if [[ "$(encode_path "$input")" == "$slug" ]]; then
      PROMPTED="$input"
      return 0
    fi
    warn "That path does not match ${slug}. Enter the path this project had."
  done
}

# Asks for the new location of old. Sets PROMPTED; returns 1 on empty input
# or Ctrl-D.
prompt_new_path() {
  local old="$1" input reply
  while true; do
    read_path "New path: " || { echo ""; return 1; }
    input="$READ_INPUT"
    input=$(expand_path "$input")

    [[ -z "$input" ]] && return 1
    if [[ "$input" == "$old" ]]; then
      warn "That is the old path. Enter the folder the project was moved to."
      continue
    fi
    if [[ ! -d "$input" ]]; then
      warn "Folder not found: ${input}"
      read -r -p "Use it anyway? [y/N] " reply
      [[ "$reply" =~ ^[Yy]$ ]] || continue
    fi

    PROMPTED="$input"
    return 0
  done
}

# Moves row i: prompts for paths, previews, confirms, applies.
action_move() {
  local i="$1" old="${R_PATH[$1]}" new reply

  echo ""
  echo -e "${BOLD}── Marked for move ────────────────────────${RESET}"
  printf "  ${CYAN}▸${RESET} %s\n" "$(row_label "$i")"
  printf "    ${DIM}%s${RESET}  ${BOLD}%s${RESET} sessions\n" "${R_SLUG[$i]}" "${R_SESSIONS[$i]}"
  echo ""
  echo -e "${DIM}Leave empty to go back to the list.${RESET}"

  if [[ -z "$old" ]]; then
    prompt_old_path "${R_SLUG[$i]}" || return 0
    old="$PROMPTED"
    # Resolve the row so move_folders picks it up.
    R_PATH[$i]="$old"
  fi
  prompt_new_path "$old" || return 0
  new="$PROMPTED"
  echo ""

  if ! check_move "$old" "$new"; then
    pause
    return 0
  fi

  info "Old path  : ${old}"
  info "New path  : ${new}"
  echo ""

  if $DRY_RUN; then
    run_move "$old" "$new"
    pause
    return 0
  fi

  DRY_RUN=true
  run_move "$old" "$new"
  DRY_RUN=false

  if [[ $CHANGED_FILES -eq 0 && $MOVED_DIRS -eq 0 ]]; then
    pause
    return 0
  fi

  read -r -p "Apply these changes? [y/N] " reply
  if [[ "$reply" =~ ^[Yy]$ ]]; then
    echo ""
    run_move "$old" "$new"
  else
    info "Cancelled."
  fi
  pause
}

PURGED_ENTRIES=0

# Removes path, or prints what would be removed.
remove_entry() {
  if $DRY_RUN; then
    printf "  ${YELLOW}[DRY-RUN]${RESET} rm -rf %s\n" "$1"
  else
    rm -rf "$1"
    printf "  ${RED}✗${RESET} %s\n" "$1"
  fi
  PURGED_ENTRIES=$((PURGED_ENTRIES + 1))
}

# Removes row i's sessions (and their file-history backups), its memory when
# wipe_memory is true, and its folder once empty.
purge_folder() {
  local i="$1" wipe_memory="$2"
  local dir="$PROJECTS_ROOT/${R_SLUG[$i]}" entry base uuid
  # A config-only row's slug can name another project's folder.
  [[ "${R_CONFIG_ONLY[$i]}" == "1" ]] && return 0
  [[ -d "$dir" ]] || return 0

  while IFS= read -r -d '' entry; do
    base=$(basename "$entry")
    uuid="${base%.jsonl}"
    [[ "$uuid" =~ ^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$ ]] || continue
    remove_entry "$entry"
    [[ -e "$CLAUDE_DIR/file-history/$uuid" ]] && remove_entry "$CLAUDE_DIR/file-history/$uuid"
  done < <(find "$dir" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)
  # Claude Code's index of the folder's sessions, which are all gone now.
  [[ -e "$dir/sessions-index.json" ]] && remove_entry "$dir/sessions-index.json"

  if $wipe_memory; then
    [[ -e "$dir/memory" ]]    && remove_entry "$dir/memory"
    [[ -e "$dir/MEMORY.md" ]] && remove_entry "$dir/MEMORY.md"
  fi

  $DRY_RUN && return 0
  remove_empty_memory "$dir"
  rm -f "$dir/.DS_Store"
  if rmdir "$dir" 2>/dev/null; then
    printf "  ${RED}✗${RESET} %s\n" "$dir"
  else
    printf "  ${DIM}kept %s (memory or other files remain)${RESET}\n" "$dir"
  fi
}

# Removes the given keys from the config file's "projects" map. Writes a
# timestamped backup first. Prints one "backup <path>" line, then each
# removed key.
remove_config_keys() {
  [[ -f "$CONFIG_FILE" && $# -gt 0 ]] || return 0
  local dry=0
  $DRY_RUN && dry=1
  python3 - "$CONFIG_FILE" "$dry" "$@" <<'PY'
import json, shutil, sys, time

cfg, dry, keys = sys.argv[1], sys.argv[2] == "1", sys.argv[3:]
with open(cfg) as fh:
    text = fh.read()
data = json.loads(text)
projects = data.get("projects", {})
removed = [k for k in keys if k in projects]
if removed and not dry:
    backup = "%s.purge-bak.%d" % (cfg, int(time.time()))
    shutil.copy2(cfg, backup)
    print("backup " + backup)
    for key in removed:
        del projects[key]
    with open(cfg, "w") as fh:
        json.dump(data, fh, indent=2, ensure_ascii=False)
        if text.endswith("\n"):
            fh.write("\n")
for key in removed:
    print(key)
PY
}

# Purges the given rows: lists them, asks about memory, confirms, removes.
action_purge() {
  local i any_memory=false wipe_memory=false reply line
  local keys=()

  echo ""
  echo -e "${BOLD}── Marked for purge ───────────────────────${RESET}"
  for i in "$@"; do
    row_markers "$i"
    printf "  ${RED}✗${RESET} %s%s\n" "$(row_label "$i")" "$MARKERS"
    printf "    ${DIM}%s${RESET}  ${BOLD}%s${RESET} sessions\n" "${R_SLUG[$i]}" "${R_SESSIONS[$i]}"
    [[ "${R_MEMORY[$i]}" == "1" ]] && any_memory=true
    [[ -n "${R_PATH[$i]}" ]] && keys+=("${R_PATH[$i]}")
  done
  echo ""

  if $any_memory; then
    read -r -p "Also delete memory? [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]] && wipe_memory=true
  fi

  if ! $DRY_RUN; then
    read -r -p "Purge $# project(s)? [y/N] " reply
    if [[ ! "$reply" =~ ^[Yy]$ ]]; then
      info "Cancelled."
      pause
      return 0
    fi
  fi

  echo ""
  echo -e "${BOLD}── Purge log ──────────────────────────────${RESET}"
  PURGED_ENTRIES=0
  for i in "$@"; do
    printf "${CYAN}▸${RESET} ${BOLD}%s${RESET}\n" "$(row_label "$i")"
    purge_folder "$i" "$wipe_memory"
  done

  local config_removed=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if [[ "$line" == "backup "* ]]; then
      info "Config backup: ${line#backup }"
    elif $DRY_RUN; then
      printf "  ${YELLOW}[DRY-RUN]${RESET} would remove config entry: %s\n" "$line"
      config_removed=$((config_removed + 1))
    else
      printf "  ${RED}✗${RESET} config entry: %s\n" "$line"
      config_removed=$((config_removed + 1))
    fi
  done < <(remove_config_keys "${keys[@]+"${keys[@]}"}")

  echo ""
  echo -e "${BOLD}── Summary ────────────────────────────────${RESET}"
  if $DRY_RUN; then
    echo -e "  Entries that ${YELLOW}would be removed${RESET}: ${PURGED_ENTRIES}"
    echo -e "  Config entries that ${YELLOW}would be removed${RESET}: ${config_removed}"
  else
    echo -e "  Entries removed       : ${GREEN}${PURGED_ENTRIES}${RESET}"
    echo -e "  Config entries removed: ${GREEN}${config_removed}${RESET}"
  fi
  echo ""
  pause
}

# ── Main ──────────────────────────────────────────────────────────────────────
if [[ -n "$OLD_DIR" || -n "$NEW_DIR" ]]; then
  [[ -z "$OLD_DIR" ]] && error "--old <old_dir> is required with --new."
  [[ -z "$NEW_DIR" ]] && error "--new <new_dir> is required with --old."
  OLD_DIR="${OLD_DIR%/}"
  NEW_DIR="${NEW_DIR%/}"
  check_move "$OLD_DIR" "$NEW_DIR" || exit 1

  print_banner
  info "Old path  : ${OLD_DIR}"
  info "New path  : ${NEW_DIR}"
  info "Claude dir: ${CLAUDE_DIR}"
  info "Config    : ${CONFIG_FILE}"
  print_modes
  echo ""

  load_projects
  run_move "$OLD_DIR" "$NEW_DIR"
  $DRY_RUN && info "Re-run without --dry-run to apply changes."
  exit 0
fi

[[ -t 0 && -t 1 ]] || error "The project list needs a terminal. Pass --old and --new to move a project without it."

load_projects
if [[ ${#R_PATH[@]} -eq 0 ]]; then
  warn "No projects found in ${CLAUDE_DIR}."
  exit 0
fi

print_banner
info "Claude dir: ${CLAUDE_DIR}"
info "Config    : ${CONFIG_FILE}"
info "Projects  : ${#R_PATH[@]}"
print_modes
echo ""

# Restores the terminal on any exit, including Ctrl-C at a prompt or pause.
TUI_STTY_SAVE=$(stty -g)
trap 'tui_cleanup; exit 130' INT TERM
trap 'tui_cleanup' EXIT

while true; do
  tui_list
  case "$TUI_ACTION" in
    move)
      action_move "$TUI_CURSOR"
      ;;
    purge)
      if [[ ${#TUI_TICKED[@]} -gt 0 ]]; then
        action_purge "${TUI_TICKED[@]}"
      else
        action_purge "$TUI_CURSOR"
      fi
      ;;
    *)
      info "Bye."
      exit 0
      ;;
  esac

  load_projects
  if [[ ${#R_PATH[@]} -eq 0 ]]; then
    warn "No projects left in ${CLAUDE_DIR}."
    exit 0
  fi
done
