#!/usr/bin/env bash
# Re-exec under real bash if invoked via sh/dash.
if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi
# =============================================================================
# install_claude_commands.sh
# Installs the slash commands from this repo's claude/commands/ into a Claude
# Code home, so they show up as /<name> in every session.
#
# Symlinks by default (edits in the repo take effect immediately). Use --copy
# for a detached snapshot.
#
# Pass one or more command names to install just those; with no names, all
# shipped commands are installed.
#
# Usage:
#   ./install_claude_commands.sh [NAME...] [--claude <claude_home>] [--copy]
#                                [--backup] [--uninstall]
#                                [--dry-run] [--yes] [--help]
#
# Example:
#   ./install_claude_commands.sh
#   ./install_claude_commands.sh orchestrate cf-settings-report
#   ./install_claude_commands.sh --claude /Users/MrAnderson/.claude-work --copy
#   ./install_claude_commands.sh orchestrate --uninstall --dry-run
#
# Flags:
#   --claude    Path to the Claude home directory (default: $CLAUDE_CONFIG_DIR
#               or ~/.claude)
#   --copy      Copy the files instead of symlinking them
#   --backup    Save a timestamped .bak of any file being overwritten
#   --uninstall Remove the commands this repo installs, then exit
#   --dry-run   Print planned actions, write nothing
#   --yes       Skip the confirmation prompt
#   --help      Show this help message
# =============================================================================

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
CLAUDE_HOME="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}"
COPY=false
BACKUP=false
UNINSTALL=false
DRY_RUN=false
ASSUME_YES=false
REQUESTED=()

# Print the physical path of $1, following symlinks (no GNU `readlink -f`).
# Prints nothing and returns 1 when the path or its parent does not exist.
resolve_path() {
  local p="$1" t d
  while [ -L "$p" ]; do
    t="$(readlink "$p")"
    case "$t" in
      /*) p="$t" ;;
      *)  p="$(dirname "$p")/$t" ;;
    esac
  done
  if [ -d "$p" ]; then
    (cd -P "$p" && pwd -P)
  else
    d="$(cd -P "$(dirname "$p")" 2>/dev/null && pwd -P)" || return 1
    echo "${d}/$(basename "$p")"
  fi
}

# Print $1, or $1-N for the first N that names nothing on disk yet.
unique_path() {
  local p="$1" n=0
  while [ -e "$p" ] || [ -L "$p" ]; do
    n=$(( n + 1 ))
    p="$1-${n}"
  done
  echo "$p"
}

# Repo-relative source dir, resolved through any symlink used to run this script.
SCRIPT_DIR="$(dirname "$(resolve_path "$0")")"
SOURCE_DIR="$(cd -P "${SCRIPT_DIR}/../commands" && pwd -P)"

# ── Colors ────────────────────────────────────────────────────────────────────
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
BOLD=$'\033[1m'
RESET=$'\033[0m'

# ── Helpers ───────────────────────────────────────────────────────────────────
usage() {
  sed -n '/^# =\{3,\}$/,/^# =\{3,\}$/p' "$0" \
    | grep -v '^# =\{3,\}' \
    | sed 's/^# \{0,2\}//;s/^#$//'
  exit 0
}

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --claude)    CLAUDE_HOME="$2"; shift 2 ;;
    --copy)      COPY=true;        shift ;;
    --backup)    BACKUP=true;      shift ;;
    --uninstall) UNINSTALL=true;   shift ;;
    --dry-run)   DRY_RUN=true;     shift ;;
    --yes|-y)    ASSUME_YES=true;  shift ;;
    --help|-h)   usage ;;
    -*) error "Unknown option: $1. Run with --help for usage." ;;
    *) REQUESTED+=("$1"); shift ;;
  esac
done

# ── Validation ────────────────────────────────────────────────────────────────
# Expand ~ manually (argv is not shell-expanded)
CLAUDE_HOME="${CLAUDE_HOME/#\~/$HOME}"
CLAUDE_HOME="${CLAUDE_HOME%/}"

[[ -d "$CLAUDE_HOME" ]] || error "Claude home not found: $CLAUDE_HOME"
[[ -d "$SOURCE_DIR" ]]  || error "Command source dir not found: $SOURCE_DIR"

# Resolve the target physically (it may be a symlink) and refuse any overlap
# with the source, since install and uninstall delete inside the target.
TARGET_DIR="$(cd -P "$CLAUDE_HOME" && pwd -P)/commands"
if [[ -d "$TARGET_DIR" ]]; then
  TARGET_DIR="$(cd -P "$TARGET_DIR" && pwd -P)"
fi
case "${TARGET_DIR}/" in
  "${SOURCE_DIR}/"*) error "Target ${TARGET_DIR} is the source dir or inside it (${SOURCE_DIR}). Choose a different --claude." ;;
esac
case "${SOURCE_DIR}/" in
  "${TARGET_DIR}/"*) error "Source ${SOURCE_DIR} is inside the target dir (${TARGET_DIR}). Choose a different --claude." ;;
esac

# Collect the command files this repo ships.
COMMANDS=()
while IFS= read -r file; do
  COMMANDS+=("$file")
done < <(find "$SOURCE_DIR" -maxdepth 1 -type f -name '*.md' ! -name 'README.md' | sort)

(( ${#COMMANDS[@]} > 0 )) || error "No command files found in ${SOURCE_DIR}."

# Narrow to the names requested on the command line (default: all).
if (( ${#REQUESTED[@]} > 0 )); then
  SELECTED=()
  for want in "${REQUESTED[@]}"; do
    want="${want%.md}"
    match=""
    for file in "${COMMANDS[@]}"; do
      if [[ "$(basename "$file" .md)" == "$want" ]]; then match="$file"; break; fi
    done
    [[ -n "$match" ]] || error "No such command: ${want}. Omit names to install all, or run with --help."
    SELECTED+=("$match")
  done
  COMMANDS=("${SELECTED[@]}")
fi

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║      Claude Command Installer            ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${RESET}"
echo ""
info "Source      : ${SOURCE_DIR}"
info "Target      : ${TARGET_DIR}"
if $UNINSTALL; then
  info "Mode        : UNINSTALL"
else
  $COPY && info "Mode        : INSTALL (copy)" || info "Mode        : INSTALL (symlink)"
fi
$DRY_RUN && warn "DRY-RUN mode — no files will be modified."
echo ""

for file in "${COMMANDS[@]}"; do
  info "  /$(basename "$file" .md)"
done
echo ""

# ── Confirmation ──────────────────────────────────────────────────────────────
if ! $DRY_RUN && ! $ASSUME_YES; then
  $UNINSTALL && prompt="Remove these commands from ${TARGET_DIR}?" \
             || prompt="Install these commands into ${TARGET_DIR}?"
  read -r -p "$(echo -e "${BOLD}${prompt}${RESET} [y/N] ")" reply \
    || { warn "Aborted (no input). Pass --yes to run non-interactively."; exit 1; }
  [[ "$reply" =~ ^[Yy]$ ]] || { warn "Aborted."; exit 0; }
  echo ""
fi

# ── Uninstall ─────────────────────────────────────────────────────────────────
if $UNINSTALL; then
  removed=0
  for file in "${COMMANDS[@]}"; do
    name="$(basename "$file")"
    dest="${TARGET_DIR}/${name}"
    if [[ -L "$dest" ]]; then
      resolved="$(resolve_path "$dest")" || resolved=""
      case "${resolved}/" in
        "${SOURCE_DIR}/"?*) owned=true ;;
        *)                  owned=false ;;
      esac
      if ! $owned; then
        warn "Not a symlink to this repo, skipped: ${dest}"
        continue
      fi
      if $DRY_RUN; then
        info "Would remove: ${dest}"
      else
        rm -f "$dest"
        success "Removed: ${dest}"
      fi
      removed=$(( removed + 1 ))
    elif [[ -e "$dest" ]]; then
      warn "Not a symlink to this repo, skipped — remove it by hand if it is a copy: ${dest}"
    else
      warn "Not installed: ${dest}"
    fi
  done
  echo ""
  $DRY_RUN && info "Dry run — ${removed} file(s) would be removed." \
           || success "Removed ${removed} command(s)."
  echo ""
  exit 0
fi

# ── Install ───────────────────────────────────────────────────────────────────
if [[ ! -d "$TARGET_DIR" ]]; then
  if $DRY_RUN; then
    info "Would create: ${TARGET_DIR}"
  else
    mkdir -p "$TARGET_DIR"
    info "Created: ${TARGET_DIR}"
  fi
fi

installed=0
for file in "${COMMANDS[@]}"; do
  name="$(basename "$file")"
  dest="${TARGET_DIR}/${name}"

  if [[ -e "$dest" || -L "$dest" ]]; then
    if $BACKUP && [[ ! -L "$dest" ]]; then
      bak="$(unique_path "${dest}.bak.$(date +%Y%m%d%H%M%S)")"
      if $DRY_RUN; then
        info "Would back up: ${dest} -> ${bak}"
      else
        cp "$dest" "$bak"
        info "Backup written: ${bak}"
      fi
    elif [[ ! -L "$dest" ]]; then
      warn "Overwriting existing file: ${dest} (use --backup to keep a copy)"
    fi
    $DRY_RUN || rm -f "$dest"
  fi

  if $DRY_RUN; then
    $COPY && info "Would copy:    ${file} -> ${dest}" \
          || info "Would symlink: ${dest} -> ${file}"
  else
    if $COPY; then
      cp "$file" "$dest"
    else
      ln -s "$file" "$dest"
    fi
    success "Installed: /$(basename "$name" .md)"
  fi
  installed=$(( installed + 1 ))
done

echo ""
if $DRY_RUN; then
  info "Dry run — ${installed} command(s) would be installed."
else
  success "Installed ${installed} command(s) into ${TARGET_DIR}"
  info "Restart Claude Code (or start a new session) to pick them up."
fi
echo ""
