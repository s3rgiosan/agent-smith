#!/usr/bin/env bash
# =============================================================================
# update_claude_paths.sh
# Updates all path references inside a .claude directory after moving folders.
#
# Usage:
#   ./update_claude_paths.sh --old <old_dir> --new <new_dir> --claude <claude_dir>
#
# Example:
#   ./update_claude_paths.sh \
#     --old /Users/MrAnderson/projects \
#     --new /Users/MrAnderson/work/projects \
#     --claude /Users/MrAnderson/.claude
#
# Flags:
#   --old      The original (source) directory path that was moved
#   --new      The destination directory path it was moved to
#   --claude   Path to the .claude folder to update (default: ~/.claude)
#   --backup   Keep .bak copy of each modified file (optional)
#   --dry-run  Preview changes without modifying any files (optional)
#   --no-tilde Skip the extra tilde pass (~/foo refs) (optional)
#   --help     Show this help message
# =============================================================================

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
OLD_DIR=""
NEW_DIR=""
CLAUDE_DIR="${HOME}/.claude"
DRY_RUN=false
BACKUP=false
NO_TILDE=false
CHANGED_FILES=0
RENAMED_DIRS=0

# Claude subdirs that use encoded project paths as entry names
CLAUDE_ENCODED_SUBDIRS=(projects file-history todos shell-snapshots debug)

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

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

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --old)     OLD_DIR="$2";    shift 2 ;;
    --new)     NEW_DIR="$2";    shift 2 ;;
    --claude)  CLAUDE_DIR="$2"; shift 2 ;;
    --backup)   BACKUP=true;   shift ;;
    --dry-run)  DRY_RUN=true;  shift ;;
    --no-tilde) NO_TILDE=true; shift ;;
    --help|-h) usage ;;
    *) error "Unknown argument: $1. Run with --help for usage." ;;
  esac
done

# ── Validation ────────────────────────────────────────────────────────────────
[[ -z "$OLD_DIR"    ]] && error "--old <old_dir> is required."
[[ -z "$NEW_DIR"    ]] && error "--new <new_dir> is required."

# Normalize: strip trailing slashes
OLD_DIR="${OLD_DIR%/}"
NEW_DIR="${NEW_DIR%/}"
CLAUDE_DIR="${CLAUDE_DIR%/}"

[[ -d "$CLAUDE_DIR" ]] || error "Claude directory not found: $CLAUDE_DIR"
[[ "$OLD_DIR" == "$NEW_DIR" ]] && error "--old and --new paths are identical. Nothing to do."
[[ "$CLAUDE_DIR" == "$OLD_DIR"* ]] && error "--old path cannot be a parent of --claude dir (would corrupt replacements)."

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║      Claude Path Updater                 ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${RESET}"
echo ""
info "Old path  : ${OLD_DIR}"
info "New path  : ${NEW_DIR}"
info "Claude dir: ${CLAUDE_DIR}"
$DRY_RUN && warn "DRY-RUN mode — no files will be modified."
$BACKUP  && info  "Backup mode — .bak copies will be kept."
echo ""

# ── Detect sed in-place flag (BSD vs GNU) ─────────────────────────────────────
if sed --version 2>/dev/null | grep -q 'GNU'; then
  if $BACKUP; then
    SED_INPLACE=(-i.bak)
  else
    SED_INPLACE=(-i)
  fi
else
  # macOS / BSD sed requires explicit suffix (empty string = no backup)
  if $BACKUP; then
    SED_INPLACE=(-i .bak)
  else
    SED_INPLACE=(-i '')
  fi
fi

# ── Escape paths for sed ──────────────────────────────────────────────────────
# Pattern side: escape \ / . * [ ] ^ $
escape_pattern() {
  printf '%s' "$1" | sed 's/[][\\/.*^$]/\\&/g'
}
# Replacement side: escape \ / &
escape_replacement() {
  printf '%s' "$1" | sed 's/[\\/&]/\\&/g'
}

# ── File sweep (usable for abs + tilde passes) ────────────────────────────────
run_sweep() {
  local old="$1" new="$2" label="$3"
  local old_esc new_esc
  old_esc=$(escape_pattern "$old")
  new_esc=$(escape_replacement "$new")

  info "Scanning files (${label}): ${old} → ${new}"

  local matched=()
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ -L "$file" ]] && continue
    matched+=("$file")
  done < <(grep -rlIF \
    --exclude-dir=.git \
    --exclude-dir=node_modules \
    -- "$old" "$CLAUDE_DIR" 2>/dev/null || true)

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
      | xargs -0 sed "${SED_INPLACE[@]}" "s/${old_esc}/${new_esc}/g"
    success "Updated ${count} file(s)."
  fi

  CHANGED_FILES=$((CHANGED_FILES + count))
}

# ── Claude path encoding ──────────────────────────────────────────────────────
# Claude stores per-project context under subdirs named by encoding the
# absolute path: non-alphanumeric chars → '-'. E.g.
#   /Users/MrAnderson/my project → -Users-MrAnderson-my-project
encode_path() {
  printf '%s' "$1" | sed 's/[^A-Za-z0-9]/-/g'
}

OLD_ENCODED=$(encode_path "$OLD_DIR")
NEW_ENCODED=$(encode_path "$NEW_DIR")

info "Old encoded: ${OLD_ENCODED}"
info "New encoded: ${NEW_ENCODED}"
echo ""

# ── Rename encoded project dirs ───────────────────────────────────────────────
# Prefix match so batch moves (e.g. parent dir rename) cascade to every
# project underneath.
for subdir in "${CLAUDE_ENCODED_SUBDIRS[@]}"; do
  base="$CLAUDE_DIR/$subdir"
  [[ -d "$base" ]] || continue

  while IFS= read -r -d '' entry; do
    name=$(basename "$entry")
    [[ "$name" == "$OLD_ENCODED"* ]] || continue

    new_name="${NEW_ENCODED}${name#$OLD_ENCODED}"
    new_path="$base/$new_name"

    if [[ "$entry" == "$new_path" ]]; then
      continue
    fi

    if [[ -e "$new_path" ]]; then
      if $DRY_RUN; then
        echo -e "  ${YELLOW}[DRY-RUN]${RESET} Would merge: ${subdir}/${name} → ${subdir}/${new_name}"
      else
        if [[ -d "$entry" && -d "$new_path" ]]; then
          mv "$entry"/* "$new_path/" 2>/dev/null || true
          rmdir "$entry" 2>/dev/null || rm -rf "$entry"
          success "Merged: ${subdir}/${name} → ${subdir}/${new_name}"
        else
          warn "Conflict at ${new_path}, keeping existing. Old entry left at ${entry}"
          continue
        fi
      fi
    else
      if $DRY_RUN; then
        echo -e "  ${YELLOW}[DRY-RUN]${RESET} Would rename: ${subdir}/${name} → ${subdir}/${new_name}"
      else
        mv "$entry" "$new_path"
        success "Renamed: ${subdir}/${name} → ${subdir}/${new_name}"
      fi
    fi
    ((RENAMED_DIRS+=1))
  done < <(find "$base" -mindepth 1 -maxdepth 1 -print0)
done

echo ""

# ── Process files ─────────────────────────────────────────────────────────────
run_sweep "$OLD_DIR" "$NEW_DIR" "absolute"

# Tilde pass: rewrite ~/... forms when --old is under $HOME.
if ! $NO_TILDE && [[ -n "${HOME:-}" && ( "$OLD_DIR" == "$HOME" || "$OLD_DIR" == "$HOME"/* ) ]]; then
  OLD_TILDE="~${OLD_DIR#$HOME}"
  if [[ "$NEW_DIR" == "$HOME" || "$NEW_DIR" == "$HOME"/* ]]; then
    NEW_TILDE="~${NEW_DIR#$HOME}"
  else
    NEW_TILDE="$NEW_DIR"
  fi
  echo ""
  run_sweep "$OLD_TILDE" "$NEW_TILDE" "tilde"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Summary ────────────────────────────────${RESET}"
if $DRY_RUN; then
  echo -e "  Files that ${YELLOW}would be updated${RESET}: ${CHANGED_FILES}"
  echo -e "  Dirs that ${YELLOW}would be renamed${RESET} : ${RENAMED_DIRS}"
else
  echo -e "  Files updated   : ${GREEN}${CHANGED_FILES}${RESET}"
  echo -e "  Dirs renamed    : ${GREEN}${RENAMED_DIRS}${RESET}"
fi
echo ""

if [[ $CHANGED_FILES -eq 0 && $RENAMED_DIRS -eq 0 ]]; then
  warn "Nothing matched. Check that --old is correct."
elif $DRY_RUN; then
  info "Re-run without --dry-run to apply changes."
else
  success "All done! Paths updated in ${CLAUDE_DIR}."
fi
