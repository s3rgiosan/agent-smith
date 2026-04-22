#!/usr/bin/env bash
# Re-exec under real bash if invoked via sh/dash or bash-in-POSIX-mode
# (this script uses process substitution, which POSIX sh rejects at parse time).
if ! (eval ': < <(:)') 2>/dev/null; then
  exec bash "$0" "$@"
fi
# =============================================================================
# purge_claude_sessions.sh
# Interactive project wiper for Claude Code. Lists every project recorded
# inside a .claude instance and lets you pick one or more to nuke.
# By default the memory/ directory and MEMORY.md are preserved.
#
# Usage:
#   ./purge_claude_sessions.sh [--claude <claude_dir>] [--wipe-memory]
#                              [--dry-run] [--yes]
#
# Examples:
#   # Interactive purge against ~/.claude
#   ./purge_claude_sessions.sh
#
#   # Use a non-default .claude folder (e.g. a work/staging install)
#   ./purge_claude_sessions.sh --claude /Users/MrAnderson/.claude-work
#
#   # Also blow away memory/ and MEMORY.md for every picked project
#   ./purge_claude_sessions.sh --wipe-memory
#
#   # Preview what would be removed
#   ./purge_claude_sessions.sh --dry-run
#
# Flags:
#   --claude       Path to the .claude folder (default: $CLAUDE_HOME or ~/.claude).
#   --wipe-memory  Also delete memory/ and MEMORY.md in selected projects.
#   --dry-run      Preview deletions without removing files.
#   --yes          Skip the final confirmation prompt.
#   --help         Show this help message.
# =============================================================================

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
CLAUDE_DIR="${CLAUDE_HOME:-$HOME/.claude}"
WIPE_MEMORY=false
DRY_RUN=false
ASSUME_YES=false

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

slug_to_path() {
  # -Users-foo-bar → /Users/foo/bar (cosmetic — lossy for real '-' in names)
  printf '%s' "$1" | sed 's|^-|/|; s|-|/|g'
}

fmt_mtime_file() {
  if stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$1" 2>/dev/null; then return; fi
  stat -c '%y' "$1" 2>/dev/null | cut -d'.' -f1
}

epoch_mtime() {
  if stat -f '%m' "$1" 2>/dev/null; then return; fi
  stat -c '%Y' "$1" 2>/dev/null
}

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --claude)       CLAUDE_DIR="$2";    shift 2 ;;
    --wipe-memory)  WIPE_MEMORY=true;   shift ;;
    --dry-run)      DRY_RUN=true;       shift ;;
    --yes|-y)       ASSUME_YES=true;    shift ;;
    --help|-h)      usage ;;
    *) error "Unknown argument: $1. Run with --help for usage." ;;
  esac
done

# ── Resolve projects root ─────────────────────────────────────────────────────
CLAUDE_DIR="${CLAUDE_DIR%/}"
[[ -d "$CLAUDE_DIR" ]] || error "Claude directory not found: $CLAUDE_DIR"
PROJECTS_ROOT="$CLAUDE_DIR/projects"
[[ -d "$PROJECTS_ROOT" ]] || error "Projects root not found: $PROJECTS_ROOT"

# ── Gather projects ───────────────────────────────────────────────────────────
PROJECTS=()
while IFS= read -r dir; do
  [[ -n "$dir" ]] && PROJECTS+=("$dir")
done < <(find "$PROJECTS_ROOT" -mindepth 1 -maxdepth 1 -type d | LC_ALL=C sort)

TOTAL=${#PROJECTS[@]}
if [[ $TOTAL -eq 0 ]]; then
  warn "No projects found in $PROJECTS_ROOT."
  exit 0
fi

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║   Claude Project Purge                   ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${RESET}"
echo ""
info "Claude dir: ${CLAUDE_DIR}"
info "Projects  : ${TOTAL}"
$WIPE_MEMORY && warn "WIPE-MEMORY mode — memory/ and MEMORY.md will also be deleted."
$DRY_RUN     && warn "DRY-RUN mode — no files will be removed."
echo ""

# ── Build listing (compute only — TUI renders later) ──────────────────────────
SESSION_COUNT=()
HAS_MEMORY=()
LATEST_FMT=()
DECODED=()
SLUGS=()

for i in "${!PROJECTS[@]}"; do
  dir="${PROJECTS[$i]}"
  slug=$(basename "$dir")
  SLUGS+=("$slug")
  DECODED+=("$(slug_to_path "$slug")")

  # Sessions = unique UUID-named items at top level (file or dir). Different Claude
  # builds store conversations as either <uuid>.jsonl, <uuid>/ sidecar, or a nested
  # <uuid>/subagents/*.jsonl layout. Dedupe by UUID.
  count=0
  newest=""
  newest_epoch=0
  seen_uuids=""
  while IFS= read -r -d '' entry; do
    base=$(basename "$entry")
    uuid="${base%.jsonl}"
    [[ "$uuid" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]] || continue
    case ":$seen_uuids:" in
      *":$uuid:"*) ;;
      *) seen_uuids="$seen_uuids:$uuid"; count=$((count + 1)) ;;
    esac
    e=$(epoch_mtime "$entry" 2>/dev/null || echo 0)
    [[ -z "$e" ]] && e=0
    if (( e > newest_epoch )); then
      newest_epoch=$e
      newest=$entry
    fi
  done < <(find "$dir" -mindepth 1 -maxdepth 1 \( -type f -o -type d \) -print0 2>/dev/null)

  # Also consider nested *.jsonl mtimes (subagents layout).
  while IFS= read -r -d '' f; do
    e=$(epoch_mtime "$f" 2>/dev/null || echo 0)
    [[ -z "$e" ]] && e=0
    if (( e > newest_epoch )); then
      newest_epoch=$e
      newest=$f
    fi
  done < <(find "$dir" -mindepth 2 -type f -name '*.jsonl' -print0 2>/dev/null)

  if [[ -n "$newest" ]]; then
    fmt=$(fmt_mtime_file "$newest")
  else
    fmt=$(fmt_mtime_file "$dir")
  fi
  [[ -z "$fmt" ]] && fmt="-               "
  LATEST_FMT+=("$fmt")

  if [[ -d "$dir/memory" || -f "$dir/MEMORY.md" ]]; then
    HAS_MEMORY+=("1")
  else
    HAS_MEMORY+=("0")
  fi

  SESSION_COUNT+=("$count")
done

# ── TUI picker ────────────────────────────────────────────────────────────────
if [[ ! -t 0 || ! -t 1 ]]; then
  error "Interactive picker requires a terminal (stdin/stdout must be a TTY)."
fi

SELECTED_INDEXES=()

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

tui_pick() {
  local n=${#PROJECTS[@]}
  local sel=() cursor=0 offset=0 i
  for ((i=0; i<n; i++)); do sel+=(0); done

  TUI_STTY_SAVE=$(stty -g)
  trap 'tui_cleanup; exit 130' INT TERM
  trap 'tui_cleanup' EXIT

  tput civis 2>/dev/null || true
  stty -echo -icanon min 1 time 0

  local key key2 count_sel
  while true; do
    local lines cols rows
    lines=$(tput lines 2>/dev/null || echo 24)
    cols=$(tput cols 2>/dev/null || echo 80)
    rows=$((lines - 5))
    (( rows < 3 )) && rows=3

    (( cursor < offset ))            && offset=$cursor
    (( cursor >= offset + rows ))    && offset=$((cursor - rows + 1))
    (( offset < 0 ))                 && offset=0

    count_sel=0
    for ((i=0; i<n; i++)); do (( sel[i] == 1 )) && count_sel=$((count_sel + 1)); done

    tput clear
    printf "${BOLD}Claude Project Purge${RESET}  ${DIM}(%s)${RESET}  ${CYAN}%d/%d selected${RESET}\n" \
      "$CLAUDE_DIR" "$count_sel" "$n"
    printf "${DIM}%s${RESET}\n" "────────────────────────────────────────────────────────────"

    local end=$((offset + rows))
    (( end > n )) && end=$n
    for ((i=offset; i<end; i++)); do
      local mark="[ ]" pointer="  " row_color=""
      (( sel[i] == 1 )) && mark="${GREEN}[✓]${RESET}"
      if (( i == cursor )); then
        pointer="${BOLD}▶ ${RESET}"
        row_color="$BOLD"
      fi
      local mem=""
      (( HAS_MEMORY[i] == 1 )) && mem=" ${YELLOW}[memory]${RESET}"
      printf "%b%s ${CYAN}%s${RESET}  %b%3d sessions${RESET}  %s%s\n" \
        "$pointer" "$mark" "${LATEST_FMT[$i]}" "$row_color" "${SESSION_COUNT[$i]}" "${DECODED[$i]}" "$mem"
    done

    local remaining=$((rows - (end - offset)))
    for ((i=0; i<remaining; i++)); do echo ""; done

    printf "${DIM}%s${RESET}\n" "────────────────────────────────────────────────────────────"
    printf "${BOLD}↑/↓${RESET} or ${BOLD}j/k${RESET} move  ${BOLD}g/G${RESET} top/bot  ${BOLD}space${RESET} toggle  ${BOLD}a${RESET} all  ${BOLD}enter${RESET} confirm  ${BOLD}q${RESET} abort"

    IFS= read -rsn1 key
    if [[ "$key" == $'\e' ]]; then
      # Bash 3.2 timeout must be integer; arrow seqs arrive instantly so 1s is fine.
      IFS= read -rsn2 -t 1 key2 2>/dev/null || key2=""
      # Page Up/Down deliver 4 chars total (\e[5~ or \e[6~) — try to slurp the tilde.
      if [[ "$key2" == "[5" || "$key2" == "[6" ]]; then
        local key3=""
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
      $'\n'|$'\r'|"") break ;;
      q|Q|$'\e')
        tui_cleanup
        trap - INT TERM EXIT
        info "Aborted."
        exit 0
        ;;
    esac
  done

  tui_cleanup
  trap - INT TERM EXIT

  for ((i=0; i<n; i++)); do
    (( sel[i] == 1 )) && SELECTED_INDEXES+=("$i")
  done
  return 0
}

tui_pick

echo ""
info "TUI returned with ${#SELECTED_INDEXES[@]} project(s) selected."

if [[ ${#SELECTED_INDEXES[@]} -eq 0 ]]; then
  warn "Nothing selected. Use SPACE to toggle rows before pressing ENTER."
  exit 0
fi

# ── Confirm ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Marked for deletion ────────────────────${RESET}"
for idx in "${SELECTED_INDEXES[@]}"; do
  dir="${PROJECTS[$idx]}"
  slug=$(basename "$dir")
  mem_note=""
  if [[ "${HAS_MEMORY[$idx]}" == "1" ]]; then
    if $WIPE_MEMORY; then
      mem_note=" ${RED}(memory will be wiped)${RESET}"
    else
      mem_note=" ${GREEN}(memory preserved)${RESET}"
    fi
  fi
  printf "  ${RED}✗${RESET} %s%b\n" "$(slug_to_path "$slug")" "$mem_note"
  printf "    ${DIM}%s${RESET}  ${BOLD}%s${RESET} sessions\n" "$slug" "${SESSION_COUNT[$idx]}"
done
echo ""

if ! $DRY_RUN && ! $ASSUME_YES; then
  read -r -p "Nuke ${#SELECTED_INDEXES[@]} project(s)? [y/N] " CONFIRM
  [[ "$CONFIRM" =~ ^[Yy]$ ]] || { info "Aborted."; exit 0; }
fi

# ── Delete ────────────────────────────────────────────────────────────────────
echo -e "${BOLD}── Deletion log ───────────────────────────${RESET}"
NUKED=0
TOTAL_ENTRIES=0
for idx in "${SELECTED_INDEXES[@]}"; do
  dir="${PROJECTS[$idx]}"
  slug=$(basename "$dir")

  if $DRY_RUN; then
    printf "${CYAN}▸${RESET} ${BOLD}%s${RESET}\n" "$(slug_to_path "$slug")"
  else
    printf "${CYAN}▸${RESET} ${BOLD}%s${RESET}\n" "$(slug_to_path "$slug")"
  fi

  # Remove every top-level UUID-named entry (file OR dir) — covers both layouts.
  while IFS= read -r -d '' entry; do
    base=$(basename "$entry")
    uuid="${base%.jsonl}"
    [[ "$uuid" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]] || continue
    local_cmd="rm"
    [[ -d "$entry" ]] && local_cmd="rm -rf"
    if $DRY_RUN; then
      printf "  ${YELLOW}[DRY-RUN]${RESET} %s %s\n" "$local_cmd" "$entry"
    else
      rm -rf "$entry"
      printf "  ${RED}✗${RESET} %s\n" "$entry"
    fi
    TOTAL_ENTRIES=$((TOTAL_ENTRIES + 1))
  done < <(find "$dir" -mindepth 1 -maxdepth 1 \( -type f -o -type d \) -print0 2>/dev/null)

  if $WIPE_MEMORY; then
    if [[ -d "$dir/memory" ]]; then
      if $DRY_RUN; then
        printf "  ${YELLOW}[DRY-RUN]${RESET} rm -rf %s\n" "$dir/memory"
      else
        rm -rf "$dir/memory"
        printf "  ${RED}✗${RESET} %s\n" "$dir/memory"
      fi
      TOTAL_ENTRIES=$((TOTAL_ENTRIES + 1))
    fi
    if [[ -f "$dir/MEMORY.md" ]]; then
      if $DRY_RUN; then
        printf "  ${YELLOW}[DRY-RUN]${RESET} rm %s\n" "$dir/MEMORY.md"
      else
        rm -f "$dir/MEMORY.md"
        printf "  ${RED}✗${RESET} %s\n" "$dir/MEMORY.md"
      fi
      TOTAL_ENTRIES=$((TOTAL_ENTRIES + 1))
    fi
  fi

  if ! $DRY_RUN; then
    # Drop macOS cruft that would block rmdir on an otherwise-empty project.
    rm -f "$dir/.DS_Store" 2>/dev/null || true
    if rmdir "$dir" 2>/dev/null; then
      printf "  ${RED}✗${RESET} %s ${DIM}(project dir removed)${RESET}\n" "$dir"
    else
      leftover=$(ls -A "$dir" 2>/dev/null | head -3 | tr '\n' ',' | sed 's/,$//')
      printf "  ${DIM}↪ project dir kept (has: %s)${RESET}\n" "${leftover:-unknown}"
    fi
  fi

  NUKED=$((NUKED + 1))
done
echo ""

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Summary ────────────────────────────────${RESET}"
if $DRY_RUN; then
  echo -e "  Would nuke: ${YELLOW}${#SELECTED_INDEXES[@]}${RESET} project(s), ${YELLOW}${TOTAL_ENTRIES}${RESET} entrie(s)"
  info "Re-run without --dry-run to apply."
else
  echo -e "  Nuked: ${GREEN}${NUKED}${RESET} project(s), ${GREEN}${TOTAL_ENTRIES}${RESET} entrie(s)"
  if $WIPE_MEMORY; then
    success "Done. Memory wiped where present."
  else
    success "Done. Memory preserved (memory/ and MEMORY.md untouched)."
  fi
fi
echo ""
