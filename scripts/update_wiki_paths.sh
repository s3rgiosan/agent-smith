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
#   --yes      Skip the confirmation prompt shown when editing without --backup;
#              required when stdin is not a terminal (optional)
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
ASSUME_YES=false

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
    --yes)      ASSUME_YES=true; shift ;;
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
[[ "$VAULT_DIR" == "$OLD_DIR" || "$VAULT_DIR" == "$OLD_DIR"/* ]] && error "--old path cannot be a parent of --vault dir (would corrupt replacements)."

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

# ── Escape paths for sed / grep (extended regex) ──────────────────────────────
escape_ere()         { printf '%s' "$1" | sed 's/[][\\.*^$(){}+?|]/\\&/g'; }
escape_pattern()     { escape_ere "$1" | sed 's/\//\\\//g'; }
escape_replacement() { printf '%s' "$1" | sed 's/[\\/&]/\\&/g'; }

# ── Build patterns ────────────────────────────────────────────────────────────
# A path matches only when the next character cannot continue a path segment
# name (or the line ends), so /a/www does not match inside /a/www-notes.
BOUNDARY='[^A-Za-z0-9._-]|$'
SENT_ABS=$'\001A\001'
SENT_TILDE=$'\001T\001'

OLD_TILDE=""
NEW_TILDE=""
USE_TILDE=false
# Tilde pass: rewrite ~/... forms when --old is strictly under $HOME.
if ! $NO_TILDE && [[ -n "${HOME:-}" && "$OLD_DIR" == "$HOME"/* ]]; then
  USE_TILDE=true
  OLD_TILDE="~${OLD_DIR#"$HOME"}"
  if [[ "$NEW_DIR" == "$HOME" || "$NEW_DIR" == "$HOME"/* ]]; then
    NEW_TILDE="~${NEW_DIR#"$HOME"}"
  else
    NEW_TILDE="$NEW_DIR"
  fi
fi

GREP_ALT="$(escape_ere "$OLD_DIR")"
# Each occurrence is first swapped for a sentinel (one per loop turn, so
# adjacent matches are all found), then the sentinel becomes the new path.
SED_ARGS=(-E
  -e ':abs' -e "s/$(escape_pattern "$OLD_DIR")(${BOUNDARY})/${SENT_ABS}\\1/" -e 'tabs')
if $USE_TILDE; then
  GREP_ALT="${GREP_ALT}|$(escape_ere "$OLD_TILDE")"
  SED_ARGS+=(-e ':tilde' -e "s/$(escape_pattern "$OLD_TILDE")(${BOUNDARY})/${SENT_TILDE}\\1/" -e 'ttilde')
fi
SED_ARGS+=(-e "s/${SENT_ABS}/$(escape_replacement "$NEW_DIR")/g")
if $USE_TILDE; then
  SED_ARGS+=(-e "s/${SENT_TILDE}/$(escape_replacement "$NEW_TILDE")/g")
fi

# ── Find files that contain a bounded match ───────────────────────────────────
info "Scanning vault: ${OLD_DIR} → ${NEW_DIR}"
$USE_TILDE && info "Tilde pass: ${OLD_TILDE} → ${NEW_TILDE}"

matched=()
while IFS= read -r file; do
  [[ -z "$file" ]] && continue
  [[ -L "$file" ]] && continue
  matched+=("$file")
done < <(grep -rlIE \
  --exclude-dir=.git \
  --exclude-dir=.obsidian \
  --exclude-dir=.trash \
  --exclude-dir=wiki-export \
  --exclude-dir=node_modules \
  -e "(${GREP_ALT})(${BOUNDARY})" -- "$VAULT_DIR" 2>/dev/null || true)

CHANGED_FILES=${#matched[@]}

if [[ $CHANGED_FILES -gt 0 ]]; then
  if $DRY_RUN; then
    cap=20 shown=0
    for f in "${matched[@]}"; do
      echo -e "  ${YELLOW}[DRY-RUN]${RESET} Would update: ${f}"
      ((shown+=1))
      if [[ $shown -ge $cap && $CHANGED_FILES -gt $cap ]]; then
        echo -e "  ${YELLOW}... and $((CHANGED_FILES - cap)) more${RESET}"
        break
      fi
    done
  else
    if ! $BACKUP && ! $ASSUME_YES; then
      [[ -t 0 ]] || error "No backup requested and stdin is not a terminal. Re-run with --backup or --yes."
      warn "${CHANGED_FILES} file(s) will be edited in place without a backup."
      read -r -p "Proceed? [y/N] " answer
      case "$answer" in
        y|Y|yes|YES) ;;
        *) error "Aborted. No files were modified." ;;
      esac
    fi
    info "Applying sed to ${CHANGED_FILES} file(s)..."
    printf '%s\0' "${matched[@]}" \
      | xargs -0 sed "${SED_INPLACE[@]}" "${SED_ARGS[@]}"
    success "Updated ${CHANGED_FILES} file(s)."
  fi
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
