#!/usr/bin/env bash
# Re-exec under real bash if invoked via sh/dash or bash-in-POSIX-mode
# (this script uses process substitution, which POSIX sh rejects at parse time).
if ! (eval ': < <(:)') 2>/dev/null; then
  exec bash "$0" "$@"
fi
# =============================================================================
# update_wiki_paths.sh
# Rewrites path references inside an Obsidian wiki vault after moving folders.
# Sweeps markdown bodies, YAML frontmatter, and any other text files.
# Skips .git, .obsidian, .trash, wiki-export, and node_modules.
#
# Usage:
#   ./update_wiki_paths.sh --old <old_dir> --new <new_dir> --vault <vault_dir>
#
# Example:
#   ./update_wiki_paths.sh \
#     --old "/Users/MrAnderson/Local Sites" \
#     --new /Users/MrAnderson/www \
#     --vault ~/Obsidian/my-vault
#
# Flags:
#   --old      The original (source) directory path that was moved
#   --new      The destination directory path it was moved to
#   --vault    Path to the Obsidian vault root (default: $OBSIDIAN_VAULT)
#   --backup   Keep .bak copy of each modified file (optional)
#   --dry-run  Preview changes without modifying any files (optional)
#   --no-tilde Skip the extra tilde pass (~/foo refs) (optional)
#   --help     Show this help message
# =============================================================================

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
OLD_DIR=""
NEW_DIR=""
VAULT_DIR="${OBSIDIAN_VAULT:-}"
DRY_RUN=false
BACKUP=false
NO_TILDE=false
CHANGED_FILES=0

# ── Colors ────────────────────────────────────────────────────────────────────
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
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

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --old)     OLD_DIR="$2";   shift 2 ;;
    --new)     NEW_DIR="$2";   shift 2 ;;
    --vault)   VAULT_DIR="$2"; shift 2 ;;
    --backup)   BACKUP=true;   shift ;;
    --dry-run)  DRY_RUN=true;  shift ;;
    --no-tilde) NO_TILDE=true; shift ;;
    --help|-h) usage ;;
    *) error "Unknown argument: $1. Run with --help for usage." ;;
  esac
done

# ── Validation ────────────────────────────────────────────────────────────────
[[ -z "$OLD_DIR"   ]] && error "--old <old_dir> is required."
[[ -z "$NEW_DIR"   ]] && error "--new <new_dir> is required."
[[ -z "$VAULT_DIR" ]] && error "--vault <vault_dir> is required (or set \$OBSIDIAN_VAULT)."

OLD_DIR="${OLD_DIR%/}"
NEW_DIR="${NEW_DIR%/}"
VAULT_DIR="${VAULT_DIR%/}"

[[ -d "$VAULT_DIR" ]] || error "Vault directory not found: $VAULT_DIR"
[[ "$OLD_DIR" == "$NEW_DIR" ]] && error "--old and --new paths are identical. Nothing to do."
[[ "$VAULT_DIR" == "$OLD_DIR"* ]] && error "--old path cannot be a parent of --vault dir (would corrupt replacements)."

# Sanity check: looks like an Obsidian vault?
if [[ ! -d "$VAULT_DIR/.obsidian" ]]; then
  warn "No .obsidian/ found in $VAULT_DIR — are you sure this is a vault?"
fi

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║      Wiki Path Updater                   ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${RESET}"
echo ""
info "Old path : ${OLD_DIR}"
info "New path : ${NEW_DIR}"
info "Vault    : ${VAULT_DIR}"
$DRY_RUN && warn "DRY-RUN mode — no files will be modified."
$BACKUP  && info  "Backup mode — .bak copies will be kept."
echo ""

# ── Detect sed in-place flag (BSD vs GNU) ─────────────────────────────────────
if sed --version 2>/dev/null | grep -q 'GNU'; then
  if $BACKUP; then SED_INPLACE=(-i.bak); else SED_INPLACE=(-i); fi
else
  if $BACKUP; then SED_INPLACE=(-i .bak); else SED_INPLACE=(-i ''); fi
fi

# ── Escape paths for sed ──────────────────────────────────────────────────────
escape_pattern()     { printf '%s' "$1" | sed 's/[][\\/.*^$]/\\&/g'; }
escape_replacement() { printf '%s' "$1" | sed 's/[\\/&]/\\&/g'; }

# ── File sweep (usable for abs + tilde passes) ────────────────────────────────
run_sweep() {
  local old="$1" new="$2" label="$3"
  local old_esc new_esc
  old_esc=$(escape_pattern "$old")
  new_esc=$(escape_replacement "$new")

  info "Scanning vault (${label}): ${old} → ${new}"

  local matched=()
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ -L "$file" ]] && continue
    matched+=("$file")
  done < <(grep -rlIF \
    --exclude-dir=.git \
    --exclude-dir=.obsidian \
    --exclude-dir=.trash \
    --exclude-dir=wiki-export \
    --exclude-dir=node_modules \
    -- "$old" "$VAULT_DIR" 2>/dev/null || true)

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
else
  echo -e "  Files updated  : ${GREEN}${CHANGED_FILES}${RESET}"
fi
echo ""

if [[ $CHANGED_FILES -eq 0 ]]; then
  warn "No files contained the old path. Check that --old is correct."
elif $DRY_RUN; then
  info "Re-run without --dry-run to apply changes."
else
  success "All done! Paths updated in ${VAULT_DIR}."
fi
