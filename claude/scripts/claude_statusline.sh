#!/usr/bin/env bash
# Re-exec under real bash if invoked via sh/dash.
if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi
# =============================================================================
# claude_statusline.sh
# Status line command for Claude Code. Reads the session JSON Claude Code
# writes to stdin and prints three powerline rows:
#
#   1. account, model, thinking, speed (Fast or Normal), session cost
#   2. context used, 5-hour and 7-day rate limits with their reset times, prompt
#      cache expiry
#   3. tsk progress, project, git branch (* when the working tree has
#      changes), pull request, worktree
#
# A segment with no value is left out. Icons need a Nerd Font; colours need a
# truecolor terminal.
#
# Usage:
#   ./claude_statusline.sh [--account <name>] [--theme <name>] [--help]
#
# Example (settings.json of a Claude home):
#   "statusLine": {
#     "type": "command",
#     "command": "/path/to/claude_statusline.sh --account work --theme onedark"
#   }
#
# Flags:
#   --account   Account name for the first segment (default: the folder name
#               of $CLAUDE_CONFIG_DIR, or .claude)
#   --theme     Segment colours: catppuccin-mocha (default) or onedark
#   --help      Show this help message
#
# Requires jq.
# =============================================================================

set -uo pipefail

# Numbers, decimal points and weekday names read the same in every locale.
export LC_ALL=C
# git status skips the optional index lock, so it never blocks the person's own
# git commands.
export GIT_OPTIONAL_LOCKS=0

# ── Defaults ──────────────────────────────────────────────────────────────────
ACCOUNT=""
THEME="catppuccin-mocha"

usage() {
  sed -n '7,35p' "$0" | sed 's/^# \{0,1\}//'
}

# ── Arguments ─────────────────────────────────────────────────────────────────
while [ $# -gt 0 ]; do
  case "$1" in
    --account | --theme)
      if [ $# -lt 2 ]; then
        echo "Missing value for $1" >&2
        exit 1
      fi
      case "$1" in
        --account) ACCOUNT="$2" ;;
        *) THEME="$2" ;;
      esac
      shift 2
      ;;
    --help | -h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# ── Theme ─────────────────────────────────────────────────────────────────────
# Segment backgrounds, cycled in order across every row. The text on them is
# the theme's darkest shade.
case "$THEME" in
  onedark)
    FG="282c34"
    BGS=(e5c07b c678dd 61afef 98c379 d19a66 56b6c2 e06c75 abb2bf)
    ;;
  *)
    FG="1e1e2e"
    BGS=(f9e2af cba6f7 89dceb a6e3a1 fab387 74c7ec f38ba8 b4befe)
    ;;
esac

# ── Glyphs (Nerd Font) ────────────────────────────────────────────────────────
SEPARATOR=$'\xee\x82\xb0'
ICON_ACCOUNT=$'\xef\x80\x87'
ICON_MODEL=$'\xef\x8b\x9b'
ICON_THINKING=$'\xef\x83\xab'
ICON_FAST=$'\xef\x83\xa7'
ICON_CONTEXT=$'\xef\x87\x80'
ICON_FIVE_HOUR=$'\xef\x80\x97'
ICON_SEVEN_DAY=$'\xef\x81\xb3'
ICON_CACHE=$'\xef\x89\x92'
ICON_COST=$'\xef\x85\x95'
ICON_PROJECT=$'\xef\x81\xbb'
ICON_BRANCH=$'\xee\x9c\xa5'
ICON_PR=$'\xef\x90\x87'
ICON_WORKTREE=$'\xef\x86\xbb'
ICON_TASKS=$'\xef\x81\x86'

# ── Helpers ───────────────────────────────────────────────────────────────────
# "1e1e2e" -> "30;30;46"
rgb() {
  printf '%d;%d;%d' "0x${1:0:2}" "0x${1:2:2}" "0x${1:4:2}"
}

# Product name of a model id: claude-opus-5-5[1m] -> "Opus 5.5 (1M)". An id of
# another shape prints the fallback, or the id itself.
model_label() {
  local id="$1" fallback="$2"
  local pattern='^(claude-)?([a-z]+)((-[0-9]{1,2})*)(-[0-9]{8})?(\[1m\])?$'
  if [[ "$id" =~ $pattern ]]; then
    local family="${BASH_REMATCH[2]}" version="${BASH_REMATCH[3]}" wide="${BASH_REMATCH[6]}"
    local first
    first="$(printf '%s' "${family:0:1}" | tr '[:lower:]' '[:upper:]')"
    local label="${first}${family:1}"
    version="${version#-}"
    [ -n "$version" ] && label="${label} ${version//-/.}"
    [ -n "$wide" ] && label="${label} (1M)"
    printf '%s' "$label"
  elif [ -n "$fallback" ]; then
    printf '%s' "$fallback"
  else
    printf '%s' "$id"
  fi
}

effort_label() {
  case "$1" in
    low) printf 'Low' ;;
    medium) printf 'Medium' ;;
    high) printf 'High' ;;
    xhigh) printf 'Extra high' ;;
    max) printf 'Max' ;;
    *) printf '%s' "$1" ;;
  esac
}

percent() {
  printf '%.0f%%' "$1"
}

# Local time of an epoch in seconds, in a date(1) format; nothing for a value
# that is not an epoch. BSD date first, then GNU date.
clock() {
  case "$1" in
    '' | *[!0-9]*) return 0 ;;
  esac
  date -r "$1" "+$2" 2>/dev/null || date -d "@$1" "+$2" 2>/dev/null
}

# Runs a command with a time limit in seconds, so a slow git or tsk cannot hold
# the status line up.
limited() {
  local seconds="$1"
  shift
  if command -v perl >/dev/null 2>&1; then
    perl -e 'alarm shift; exec @ARGV or exit 127' "$seconds" "$@"
  else
    "$@"
  fi
}

# "5h 24% (14:30)": a rate-limit window's usage and when it resets.
limit_text() {
  local label="$1" used="$2" resets="$3" format="$4"
  [ -z "$used" ] && return 0
  local text="${label} $(percent "$used")" at
  at="$(clock "${resets%.*}" "$format")"
  [ -n "$at" ] && text="${text} (${at})"
  printf '%s' "$text"
}

# Counts the tasks of the tsk project the directory belongs to: live tasks plus
# done ones. Desk tasks (no project) are not counted. Prints "done/total", or
# nothing when the directory cannot be entered.
tsk_progress() {
  command -v tsk >/dev/null 2>&1 || return 0
  cd "$1" 2>/dev/null || return 0
  local count='[.[] | select(.project != null)] | length'
  local live finished
  live="$(limited 1 tsk list --json 2>/dev/null | jq "$count" 2>/dev/null)"
  finished="$(limited 1 tsk list --done --json 2>/dev/null | jq "$count" 2>/dev/null)"
  live="${live:-0}"
  finished="${finished:-0}"
  printf '%d/%d' "$finished" $((live + finished))
}

# Index of the next background in BGS; runs on across rows.
COLOR=0

# Prints one powerline row from "icon text" segments; empty ones are left out.
row() {
  local segments=() segment
  for segment in "$@"; do
    [ -n "$segment" ] && segments+=("$segment")
  done
  [ "${#segments[@]}" -eq 0 ] && return 0

  local fg out="" i bg next
  fg="$(rgb "$FG")"
  for i in "${!segments[@]}"; do
    bg="$(rgb "${BGS[$(((COLOR + i) % ${#BGS[@]}))]}")"
    out+=$'\033'"[38;2;${fg};48;2;${bg}m ${segments[$i]} "
    if [ $((i + 1)) -lt "${#segments[@]}" ]; then
      next="$(rgb "${BGS[$(((COLOR + i + 1) % ${#BGS[@]}))]}")"
      out+=$'\033'"[38;2;${bg};48;2;${next}m${SEPARATOR}"
    else
      out+=$'\033'"[0m"$'\033'"[38;2;${bg}m${SEPARATOR}"$'\033'"[0m"
    fi
  done
  COLOR=$((COLOR + ${#segments[@]}))
  printf '%s\n' "$out"
}

# Prefixes a value with its icon; an empty value stays empty.
seg() {
  [ -n "$2" ] && printf '%s %s' "$1" "$2"
}

# ── Input ─────────────────────────────────────────────────────────────────────
INPUT="$(cat)"

# One jq pass; fields are split on the unit separator so empty ones survive. A
# field of an unexpected type reads as empty and leaves the others intact.
IFS=$'\x1f' read -r MODEL_ID MODEL_NAME EFFORT THINKING FAST CONTEXT \
  FIVE_HOUR FIVE_HOUR_RESETS SEVEN_DAY SEVEN_DAY_RESETS CACHE_WARM CACHE_EXPIRES COST \
  CWD PROJECT_DIR PR_NUMBER PR_STATE WORKTREE < <(
    jq -r '
      def v(f): [try f] | .[0] | if . == null then "" else tostring end;
      [
        v(.model.id),
        v(.model.display_name),
        v(.effort.level),
        v(.thinking.enabled),
        v(.fast_mode),
        v(.context_window.used_percentage),
        v(.rate_limits.five_hour.used_percentage),
        v(.rate_limits.five_hour.resets_at),
        v(.rate_limits.seven_day.used_percentage),
        v(.rate_limits.seven_day.resets_at),
        v(.prompt_cache.warm),
        v(.prompt_cache.expires_at),
        v(.cost.total_cost_usd),
        v((.workspace.current_dir // .cwd)),
        v(.workspace.project_dir),
        v(.pr.number),
        v(.pr.review_state),
        v(.worktree.name)
      ] | join("\u001f")
    ' <<<"$INPUT" 2>/dev/null
  )

# ── Row 1: account, model, thinking, speed, cost ──────────────────────────────
if [ -z "$ACCOUNT" ]; then
  home="${CLAUDE_CONFIG_DIR:-.claude}"
  home="${home%/}"
  ACCOUNT="${home##*/}"
fi

MODEL=""
[ -n "$MODEL_ID" ] && MODEL="$(model_label "$MODEL_ID" "$MODEL_NAME")"

if [ "$THINKING" = "false" ]; then
  THINKING_LABEL="Off"
elif [ -n "$EFFORT" ]; then
  THINKING_LABEL="$(effort_label "$EFFORT")"
elif [ "$THINKING" = "true" ]; then
  THINKING_LABEL="On"
else
  THINKING_LABEL=""
fi

# Fast mode reads as off when the input leaves it out.
FAST_TEXT="Normal"
[ "$FAST" = "true" ] && FAST_TEXT="Fast"

COST_TEXT=""
[ -n "$COST" ] && COST_TEXT="$(printf '$%.2f' "$COST")"

row \
  "$(seg "$ICON_ACCOUNT" "$ACCOUNT")" \
  "$(seg "$ICON_MODEL" "$MODEL")" \
  "$(seg "$ICON_THINKING" "$THINKING_LABEL")" \
  "$(seg "$ICON_FAST" "$FAST_TEXT")" \
  "$(seg "$ICON_COST" "$COST_TEXT")"

# ── Row 2: context, rate limits, prompt cache ─────────────────────────────────
CONTEXT_TEXT=""
[ -n "$CONTEXT" ] && CONTEXT_TEXT="$(percent "$CONTEXT")"

# The cache shows the time it expires at while warm: a countdown would go stale
# between redraws.
CACHE_TEXT=""
if [ "$CACHE_WARM" = "true" ] && [ -n "$CACHE_EXPIRES" ]; then
  CACHE_EXPIRES_AT="$(clock "${CACHE_EXPIRES%.*}" '%H:%M')"
  CACHE_TEXT="cache ${CACHE_EXPIRES_AT:-warm}"
elif [ "$CACHE_WARM" = "false" ]; then
  CACHE_TEXT="cache cold"
fi

row \
  "$(seg "$ICON_CONTEXT" "$CONTEXT_TEXT")" \
  "$(seg "$ICON_FIVE_HOUR" "$(limit_text 5h "$FIVE_HOUR" "$FIVE_HOUR_RESETS" '%H:%M')")" \
  "$(seg "$ICON_SEVEN_DAY" "$(limit_text 7d "$SEVEN_DAY" "$SEVEN_DAY_RESETS" '%a %H:%M')")" \
  "$(seg "$ICON_CACHE" "$CACHE_TEXT")"

# ── Row 3: tsk, project, branch, pull request, worktree ───────────────────────
DIR="${CWD:-$PWD}"
TOPLEVEL="$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null)"
PROJECT_ROOT="${TOPLEVEL:-${PROJECT_DIR:-$DIR}}"
PROJECT="${PROJECT_ROOT##*/}"

BRANCH=""
if [ -n "$TOPLEVEL" ]; then
  BRANCH="$(git -C "$DIR" branch --show-current 2>/dev/null)"
  # A detached HEAD has no branch name; its short hash stands in.
  [ -z "$BRANCH" ] && BRANCH="$(git -C "$DIR" rev-parse --short HEAD 2>/dev/null)"
  CHANGES="$(limited 1 git -C "$DIR" status --porcelain 2>/dev/null | head -n 1)"
  [ -n "$CHANGES" ] && BRANCH="${BRANCH}*"
fi

PR_TEXT=""
if [ -n "$PR_NUMBER" ]; then
  PR_TEXT="#${PR_NUMBER}"
  [ -n "$PR_STATE" ] && PR_TEXT="${PR_TEXT} ${PR_STATE//_/ }"
fi

row \
  "$(seg "$ICON_TASKS" "$(tsk_progress "$DIR")")" \
  "$(seg "$ICON_PROJECT" "$PROJECT")" \
  "$(seg "$ICON_BRANCH" "$BRANCH")" \
  "$(seg "$ICON_PR" "$PR_TEXT")" \
  "$(seg "$ICON_WORKTREE" "$WORKTREE")"
