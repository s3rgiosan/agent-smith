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
# Usage:
#   ./install_claude_commands.sh [--claude <claude_home>] [--copy]
#                                [--backup] [--uninstall]
#                                [--dry-run] [--yes] [--help]
#
# Example:
#   ./install_claude_commands.sh
#   ./install_claude_commands.sh --claude /Users/MrAnderson/.claude-work --copy
#   ./install_claude_commands.sh --uninstall --dry-run
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

# Repo-relative source dir, resolved without GNU `readlink -f`.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_DIR="$(cd "${SCRIPT_DIR}/../commands" && pwd)"

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
    *) error "Unknown argument: $1. Run with --help for usage." ;;
  esac
done

# ── Validation ────────────────────────────────────────────────────────────────
# Expand ~ manually (argv is not shell-expanded)
CLAUDE_HOME="${CLAUDE_HOME/#\~/$HOME}"
CLAUDE_HOME="${CLAUDE_HOME%/}"

[[ -d "$CLAUDE_HOME" ]] || error "Claude home not found: $CLAUDE_HOME"
[[ -d "$SOURCE_DIR" ]]  || error "Command source dir not found: $SOURCE_DIR"

TARGET_DIR="${CLAUDE_HOME}/commands"

# Collect the command files this repo ships.
COMMANDS=()
while IFS= read -r file; do
  COMMANDS+=("$file")
done < <(find "$SOURCE_DIR" -maxdepth 1 -type f -name '*.md' ! -name 'README.md' | sort)

(( ${#COMMANDS[@]} > 0 )) || error "No command files found in ${SOURCE_DIR}."

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
  read -r -p "$(echo -e "${BOLD}${prompt}${RESET} [y/N] ")" reply
  [[ "$reply" =~ ^[Yy]$ ]] || { warn "Aborted."; exit 0; }
  echo ""
fi

# ── Uninstall ─────────────────────────────────────────────────────────────────
if $UNINSTALL; then
  removed=0
  for file in "${COMMANDS[@]}"; do
    name="$(basename "$file")"
    dest="${TARGET_DIR}/${name}"
    if [[ -e "$dest" || -L "$dest" ]]; then
      if $DRY_RUN; then
        info "Would remove: ${dest}"
      else
        rm -f "$dest"
        success "Removed: ${dest}"
      fi
      removed=$(( removed + 1 ))
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
      bak="${dest}.bak.$(date +%Y%m%d%H%M%S)"
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
