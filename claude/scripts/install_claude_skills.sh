#!/usr/bin/env bash
# Re-exec under real bash if invoked via sh/dash.
if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi
# =============================================================================
# install_claude_skills.sh
# Installs the skills from this repo's claude/skills/ into a Claude Code home,
# so they show up as skills in every session.
#
# A skill is a directory containing a SKILL.md file. Each such directory is
# installed as $CLAUDE_HOME/skills/<name>.
#
# Symlinks by default (edits in the repo take effect immediately). Use --copy
# for a detached snapshot.
#
# Pass one or more skill names to install just those; with no names, all
# shipped skills are installed.
#
# Usage:
#   ./install_claude_skills.sh [NAME...] [--claude <claude_home>] [--copy]
#                              [--backup] [--uninstall]
#                              [--dry-run] [--yes] [--help]
#
# Example:
#   ./install_claude_skills.sh
#   ./install_claude_skills.sh grill-me
#   ./install_claude_skills.sh --claude /Users/MrAnderson/.claude-work --copy
#   ./install_claude_skills.sh grill-me --uninstall --dry-run
#
# Flags:
#   --claude    Path to the Claude home directory (default: $CLAUDE_CONFIG_DIR
#               or ~/.claude)
#   --copy      Copy the directories instead of symlinking them
#   --backup    Save a timestamped .bak of any directory being overwritten
#   --uninstall Remove the skills this repo installs, then exit
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

# Repo-relative source dir, resolved without GNU `readlink -f`.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_DIR="$(cd "${SCRIPT_DIR}/../skills" && pwd)"

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
[[ -d "$SOURCE_DIR" ]]  || error "Skill source dir not found: $SOURCE_DIR"

TARGET_DIR="${CLAUDE_HOME}/skills"

# Collect the skill directories this repo ships (any subdir with a SKILL.md).
SKILLS=()
while IFS= read -r skillfile; do
  SKILLS+=("$(dirname "$skillfile")")
done < <(find "$SOURCE_DIR" -mindepth 2 -maxdepth 2 -type f -name 'SKILL.md' | sort)

(( ${#SKILLS[@]} > 0 )) || error "No skills (dirs with SKILL.md) found in ${SOURCE_DIR}."

# Narrow to the names requested on the command line (default: all).
if (( ${#REQUESTED[@]} > 0 )); then
  SELECTED=()
  for want in "${REQUESTED[@]}"; do
    match=""
    for dir in "${SKILLS[@]}"; do
      if [[ "$(basename "$dir")" == "$want" ]]; then match="$dir"; break; fi
    done
    [[ -n "$match" ]] || error "No such skill: ${want}. Omit names to install all, or run with --help."
    SELECTED+=("$match")
  done
  SKILLS=("${SELECTED[@]}")
fi

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║        Claude Skill Installer            ║${RESET}"
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

for dir in "${SKILLS[@]}"; do
  info "  $(basename "$dir")"
done
echo ""

# ── Confirmation ──────────────────────────────────────────────────────────────
if ! $DRY_RUN && ! $ASSUME_YES; then
  $UNINSTALL && prompt="Remove these skills from ${TARGET_DIR}?" \
             || prompt="Install these skills into ${TARGET_DIR}?"
  read -r -p "$(echo -e "${BOLD}${prompt}${RESET} [y/N] ")" reply
  [[ "$reply" =~ ^[Yy]$ ]] || { warn "Aborted."; exit 0; }
  echo ""
fi

# ── Uninstall ─────────────────────────────────────────────────────────────────
if $UNINSTALL; then
  removed=0
  for dir in "${SKILLS[@]}"; do
    name="$(basename "$dir")"
    dest="${TARGET_DIR}/${name}"
    if [[ -e "$dest" || -L "$dest" ]]; then
      if $DRY_RUN; then
        info "Would remove: ${dest}"
      else
        rm -rf "$dest"
        success "Removed: ${dest}"
      fi
      removed=$(( removed + 1 ))
    else
      warn "Not installed: ${dest}"
    fi
  done
  echo ""
  $DRY_RUN && info "Dry run — ${removed} skill(s) would be removed." \
           || success "Removed ${removed} skill(s)."
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
for dir in "${SKILLS[@]}"; do
  name="$(basename "$dir")"
  dest="${TARGET_DIR}/${name}"

  if [[ -e "$dest" || -L "$dest" ]]; then
    if $BACKUP && [[ ! -L "$dest" ]]; then
      bak="${dest}.bak.$(date +%Y%m%d%H%M%S)"
      if $DRY_RUN; then
        info "Would back up: ${dest} -> ${bak}"
      else
        cp -R "$dest" "$bak"
        info "Backup written: ${bak}"
      fi
    elif [[ ! -L "$dest" ]]; then
      warn "Overwriting existing directory: ${dest} (use --backup to keep a copy)"
    fi
    $DRY_RUN || rm -rf "$dest"
  fi

  if $DRY_RUN; then
    $COPY && info "Would copy:    ${dir} -> ${dest}" \
          || info "Would symlink: ${dest} -> ${dir}"
  else
    if $COPY; then
      cp -R "$dir" "$dest"
    else
      ln -s "$dir" "$dest"
    fi
    success "Installed: ${name}"
  fi
  installed=$(( installed + 1 ))
done

echo ""
if $DRY_RUN; then
  info "Dry run — ${installed} skill(s) would be installed."
else
  success "Installed ${installed} skill(s) into ${TARGET_DIR}"
  info "Restart Claude Code (or start a new session) to pick them up."
fi
echo ""
