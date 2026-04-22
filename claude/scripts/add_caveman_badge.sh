#!/usr/bin/env bash
# Re-exec under real bash if invoked via sh/dash.
if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi
# =============================================================================
# add_caveman_badge.sh
# Patches a ccstatusline settings.json to add (or remove) a custom-command
# widget that renders the caveman Statusline badge.
#
# The badge script lives inside the Claude home:
#   <claude>/plugins/marketplaces/caveman/hooks/caveman-statusline.sh
#
# Usage:
#   ./add_caveman_badge.sh --claude <claude_home> [--config <settings.json>]
#                          [--line N] [--position prepend|append]
#                          [--remove] [--dry-run] [--no-backup]
#
# Example:
#   ./add_caveman_badge.sh --claude /Users/MrAnderson/.claude
#   ./add_caveman_badge.sh \
#     --claude /Users/MrAnderson/.claude-work \
#     --config /Users/MrAnderson/.config/ccstatusline/settings-work.json
#
# Flags:
#   --claude    Path to the Claude home directory (default: ~/.claude)
#   --config    Path to ccstatusline settings.json
#               (default: ~/.config/ccstatusline/settings.json)
#   --line      Zero-based index of the line to patch (default: 0)
#   --position  Insert at start (prepend) or end (append) of the line
#               (default: prepend)
#   --remove    Remove the caveman badge instead of adding it
#   --dry-run   Print resulting JSON to stdout, do not write
#   --no-backup Skip writing a .bak copy of the settings file
#   --help      Show this help message
# =============================================================================

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
CLAUDE_HOME="${HOME}/.claude"
CONFIG_FILE="${HOME}/.config/ccstatusline/settings.json"
LINE_INDEX=0
POSITION="prepend"
REMOVE=false
DRY_RUN=false
BACKUP=true
BADGE_ID="caveman-badge"

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
    --config)    CONFIG_FILE="$2"; shift 2 ;;
    --line)      LINE_INDEX="$2";  shift 2 ;;
    --position)  POSITION="$2";    shift 2 ;;
    --remove)    REMOVE=true;      shift ;;
    --dry-run)   DRY_RUN=true;     shift ;;
    --no-backup) BACKUP=false;     shift ;;
    --help|-h)   usage ;;
    *) error "Unknown argument: $1. Run with --help for usage." ;;
  esac
done

# ── Validation ────────────────────────────────────────────────────────────────
command -v jq >/dev/null 2>&1 || error "jq is required but not installed."

# Expand ~ manually (argv is not shell-expanded)
CLAUDE_HOME="${CLAUDE_HOME/#\~/$HOME}"
CONFIG_FILE="${CONFIG_FILE/#\~/$HOME}"
CLAUDE_HOME="${CLAUDE_HOME%/}"

[[ -d "$CLAUDE_HOME" ]] || error "Claude home not found: $CLAUDE_HOME"
[[ -f "$CONFIG_FILE" ]] || error "ccstatusline config not found: $CONFIG_FILE"

BADGE_SCRIPT="${CLAUDE_HOME}/plugins/marketplaces/caveman/hooks/caveman-statusline.sh"
if ! $REMOVE; then
  [[ -x "$BADGE_SCRIPT" || -r "$BADGE_SCRIPT" ]] \
    || error "caveman-statusline.sh not found: $BADGE_SCRIPT
Is the caveman plugin installed under this Claude home?"
fi

case "$POSITION" in
  prepend|append) ;;
  *) error "--position must be 'prepend' or 'append' (got: $POSITION)" ;;
esac

[[ "$LINE_INDEX" =~ ^[0-9]+$ ]] || error "--line must be a non-negative integer."

# Sanity check: config looks like ccstatusline?
if ! jq -e '.lines | type == "array"' "$CONFIG_FILE" >/dev/null 2>&1; then
  warn "Config does not have a 'lines' array — are you sure this is a ccstatusline settings.json?"
fi

LINE_COUNT=$(jq '.lines | length' "$CONFIG_FILE")
if (( LINE_INDEX >= LINE_COUNT )); then
  error "--line $LINE_INDEX is out of range (config has $LINE_COUNT line(s))."
fi

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║      Caveman Badge Patcher               ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${RESET}"
echo ""
info "Claude home : ${CLAUDE_HOME}"
info "Config      : ${CONFIG_FILE}"
info "Line        : ${LINE_INDEX}"
$REMOVE  && info  "Mode        : REMOVE"  || info "Mode        : ADD (${POSITION})"
$DRY_RUN && warn  "DRY-RUN mode — no files will be modified."
$BACKUP  || warn  "Backup disabled."
echo ""

# ── Build or locate the widget ────────────────────────────────────────────────
TMP_OUT=$(mktemp)
trap 'rm -f "$TMP_OUT"' EXIT

if $REMOVE; then
  jq --arg id "$BADGE_ID" '
    .lines |= map(map(select(.id != $id)))
  ' "$CONFIG_FILE" > "$TMP_OUT"
else
  # Strip trailing ANSI reset so ccstatusline's background/padding isn't
  # cleared back to the terminal default after the badge's colored text.
  COMMAND_PATH="bash ${BADGE_SCRIPT} | perl -pe 's/\\e\\[0m\\z//'"

  WIDGET_JSON=$(jq -n \
    --arg id "$BADGE_ID" \
    --arg cmd "$COMMAND_PATH" \
    '{
       id: $id,
       type: "custom-command",
       commandPath: $cmd,
       preserveColors: true,
       timeout: 1000
     }')

  # Idempotent: if a widget with the same id already exists anywhere, drop it
  # first, then insert fresh at the requested position on the requested line.
  jq \
    --argjson idx "$LINE_INDEX" \
    --arg pos "$POSITION" \
    --arg id "$BADGE_ID" \
    --argjson widget "$WIDGET_JSON" '
    .lines |= map(map(select(.id != $id)))
    | .lines[$idx] |= (
        if $pos == "append" then . + [$widget] else [$widget] + . end
      )
  ' "$CONFIG_FILE" > "$TMP_OUT"
fi

# ── Write or preview ──────────────────────────────────────────────────────────
if $DRY_RUN; then
  info "Resulting JSON:"
  cat "$TMP_OUT"
  echo ""
  exit 0
fi

if $BACKUP; then
  BAK="${CONFIG_FILE}.bak.$(date +%Y%m%d%H%M%S)"
  cp "$CONFIG_FILE" "$BAK"
  info "Backup written: ${BAK}"
fi

mv "$TMP_OUT" "$CONFIG_FILE"
trap - EXIT

if $REMOVE; then
  success "Removed caveman badge from ${CONFIG_FILE}"
else
  success "Added caveman badge to ${CONFIG_FILE} (line ${LINE_INDEX}, ${POSITION})"
fi
echo ""
