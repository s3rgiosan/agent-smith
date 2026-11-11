#!/usr/bin/env bash
# Re-exec under real bash if invoked via sh/dash or bash-in-POSIX-mode
# (this script uses process substitution, which POSIX sh rejects at parse time).
if ! (eval ': < <(:)') 2>/dev/null; then
  exec bash "$0" "$@"
fi
# =============================================================================
# manage_claude_spinner_verbs.sh
# Sets the spinner verbs in a Claude Code settings file from the themes in
# this repo's claude/spinner-verbs/. You do not edit JSON by hand.
#
# Use a theme, stack more themes, remove a theme, add your own phrases,
# switch the mode, or remove the spinner verbs. A SessionStart hook can also
# rotate the theme once a day. All other keys in the settings file stay as
# they are. With no action flags, a menu opens.
#
# Usage:
#   ./manage_claude_spinner_verbs.sh [--scope <scope>] [--claude <claude_home>]
#                                    [--project <dir>] [--backup] [--dry-run]
#   ./manage_claude_spinner_verbs.sh [--use THEME]... [--add THEME]...
#                                    [--remove THEME]... [--verb TEXT]...
#                                    [--mode replace|append] [--scope <scope>]
#                                    [--claude <claude_home>] [--project <dir>]
#                                    [--backup] [--dry-run] [--yes]
#   ./manage_claude_spinner_verbs.sh --reset [--scope <scope>] [--yes] ...
#   ./manage_claude_spinner_verbs.sh --show [--scope <scope>]
#   ./manage_claude_spinner_verbs.sh --list
#   ./manage_claude_spinner_verbs.sh --install-rotation [--themes LIST]
#                                    [--claude <claude_home>] [--yes] ...
#   ./manage_claude_spinner_verbs.sh --remove-rotation [--claude <claude_home>]
#   ./manage_claude_spinner_verbs.sh --rotate [--themes LIST]
#                                    [--claude <claude_home>]
#
# Examples:
#   # Open the menu
#   ./manage_claude_spinner_verbs.sh
#
#   # Use one theme in ~/.claude/settings.json (or $CLAUDE_CONFIG_DIR)
#   ./manage_claude_spinner_verbs.sh --use pirate
#
#   # Stack a second theme and add a phrase of your own
#   ./manage_claude_spinner_verbs.sh --add portuguese-football --verb "Brewing a bica"
#
#   # Add a theme to the built-in verbs, for you in this project only
#   ./manage_claude_spinner_verbs.sh --use monty-python --mode append --scope local
#
#   # Remove the spinner verbs from ~/.claude/settings.json
#   ./manage_claude_spinner_verbs.sh --reset
#
#   # Rotate all themes, one each day
#   ./manage_claude_spinner_verbs.sh --install-rotation
#
#   # Rotate only two themes
#   ./manage_claude_spinner_verbs.sh --install-rotation --themes portuguese,portuguese-football
#
# Flags:
#   --use      Replace the current verbs with the verbs of a theme
#              (repeat to combine themes)
#   --add      Add the verbs of a theme to the current verbs (repeatable)
#   --remove   Remove the verbs of a theme from the current verbs (repeatable)
#   --verb     Add one phrase of your own (repeatable)
#   --mode     replace: Claude Code shows only these verbs
#              append: Claude Code adds these verbs to its built-in verbs
#              (default: the current mode, else replace)
#   --reset    Remove spinnerVerbs from the settings file
#   --show     Print the current verbs, then exit
#   --list     Print the available themes, then exit
#   --install-rotation
#              Add a SessionStart hook that runs --rotate, then set the theme
#              of the day (user scope only)
#   --remove-rotation
#              Remove that hook. The current verbs stay.
#   --rotate   Set the theme of the day, then exit. This is the command that
#              the hook runs. It prints nothing unless an error occurs.
#   --themes   Comma-separated themes for the rotation (default: all themes)
#   --scope    user (default): <claude_home>/settings.json, for all projects
#              project: <dir>/.claude/settings.json, shared with the team
#              local: <dir>/.claude/settings.local.json, for you in one project
#   --claude   Path to the Claude home directory for the user scope
#              (default: $CLAUDE_CONFIG_DIR or ~/.claude)
#   --project  Project directory for the project and local scopes
#              (default: the current directory)
#   --backup   Save a timestamped copy of the settings file before a change,
#              under <claude_home>/backups/spinner-verbs/
#   --dry-run  Print the planned change, write nothing
#   --yes      Skip the confirmation prompt
#   --help     Show this help message
#
# THEME is a file name from claude/spinner-verbs/ without ".json", or the
# path to a JSON file with the same format. Duplicate verbs are skipped.
#
# The rotation goes through the themes in alphabetical order (or in the
# --themes order) and shows each theme for one UTC day. It keeps the current
# mode. A new theme file joins the rotation when --themes is not set, and
# then the order changes.
#
# Requires python3.
# =============================================================================

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
CLAUDE_HOME="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}"
PROJECT_DIR="$PWD"
SCOPE=""
MODE=""
RESET=false
SHOW=false
LIST=false
BACKUP=false
DRY_RUN=false
ASSUME_YES=false
ROTATE=false
INSTALL_ROTATION=false
REMOVE_ROTATION=false
ROTATION_THEMES=""
SKIP_ROTATION_WARNING=false
USE=()
ADD=()
REMOVE=()
VERBS=()

# The first day of the rotation: 2026-11-11, as days since 1970-01-01 (UTC).
ROTATION_EPOCH_DAY=20768

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

# Repo-relative theme dir, resolved through any symlink used to run this script.
SCRIPT_DIR="$(dirname "$(resolve_path "$0")")"
THEMES_DIR="$(cd -P "${SCRIPT_DIR}/../spinner-verbs" 2>/dev/null && pwd -P)" || THEMES_DIR=""

# ── Colors ────────────────────────────────────────────────────────────────────
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
DIM=$'\033[2m'
BOLD=$'\033[1m'
RESET_COLOR=$'\033[0m'

# ── Helpers ───────────────────────────────────────────────────────────────────
usage() {
  sed -n '/^# =\{3,\}$/,/^# =\{3,\}$/p' "$0" \
    | grep -v '^# =\{3,\}' \
    | sed 's/^# \{0,2\}//;s/^#$//'
  exit 0
}

info()    { echo -e "${CYAN}[INFO]${RESET_COLOR}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET_COLOR}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET_COLOR}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET_COLOR} $*" >&2; exit 1; }

# Print $1 with the home directory written as ~.
tilde() {
  case "$1" in
    "$HOME"/*) echo "~${1#"$HOME"}" ;;
    *)         echo "$1" ;;
  esac
}

# The Python helper reads and writes the JSON. Commands:
#   themes FILE...    one "name<TAB>count" line per theme ("?" when invalid)
#   show FILE         "unset", "invalid", or "mode<TAB>count" and then one
#                     verb per line
#   plan FILE OP...   print the change that the operations make
#   apply FILE OP...  make the change and write the file
#   hook-status FILE  print the command of the rotation hook, or nothing
#   hook FILE install|remove plan|apply [ARG...]
#                     add or remove the rotation hook; ARG is the command
#                     that the hook runs, one word per argument
# An OP is "reset:", "clear:", "add:<theme>", "remove:<theme>", "verb:<text>"
# or "mode:<mode>". Exit codes: 0 changed, 10 no change, 11 refused, 2 error.
PY_HELPER="$(cat <<'PY'
import json
import os
import re
import shlex
import shutil
import sys
import tempfile


def fail(message, code=2):
    print(message, file=sys.stderr)
    sys.exit(code)


def read_settings(path):
    """Return the settings object and the raw text. A missing file is empty."""
    if not os.path.exists(path):
        return {}, ''
    try:
        with open(path, encoding='utf-8') as handle:
            text = handle.read()
    except (OSError, UnicodeDecodeError) as exc:
        fail(f'Cannot read {path}: {exc}')
    if not text.strip():
        return {}, text
    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        fail(f'{path} is not valid JSON: {exc}')
    if not isinstance(data, dict):
        fail(f'{path} does not hold a JSON object.')
    return data, text


def is_verb_list(value):
    return isinstance(value, list) and all(isinstance(v, str) for v in value)


def current(data, path):
    """Return the spinnerVerbs object, or None when it is not set."""
    sv = data.get('spinnerVerbs')
    if sv is None:
        return None
    if not isinstance(sv, dict) or not is_verb_list(sv.get('verbs', [])):
        fail(f'spinnerVerbs in {path} has an unexpected shape. '
             'Fix it by hand, or run with --reset.')
    return sv


def theme_verbs(path):
    """Return the verbs of a theme file. Raise ValueError when it is not valid."""
    try:
        with open(path, encoding='utf-8') as handle:
            data = json.load(handle)
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ValueError(f'Cannot read theme {path}: {exc}')
    sv = data.get('spinnerVerbs') if isinstance(data, dict) else None
    verbs = sv.get('verbs') if isinstance(sv, dict) else None
    if not is_verb_list(verbs):
        raise ValueError(f'{path} has no spinnerVerbs.verbs list of strings.')
    return verbs


def plan(path, ops):
    """Return (new settings or None, exit code, summary lines)."""
    data, _ = read_settings(path)
    old_sv = data.get('spinnerVerbs')
    resetting = any(op == 'reset' for op, _ in ops)
    sv = None if resetting else current(data, path)

    verbs = list(sv.get('verbs', [])) if sv else []
    old_mode = sv.get('mode') if sv else None
    mode = old_mode
    mode_given = False
    before = len(verbs)
    added = skipped = removed = 0

    def add(verb):
        nonlocal added, skipped
        if verb in verbs:
            skipped += 1
        else:
            verbs.append(verb)
            added += 1

    for op, value in ops:
        if op in ('reset', 'clear'):
            removed += len(verbs)
            verbs = []
        elif op == 'add':
            try:
                for verb in theme_verbs(value):
                    add(verb)
            except ValueError as exc:
                fail(str(exc))
        elif op == 'remove':
            try:
                drop = set(theme_verbs(value))
            except ValueError as exc:
                fail(str(exc))
            kept = [v for v in verbs if v not in drop]
            removed += len(verbs) - len(kept)
            verbs = kept
        elif op == 'verb':
            verb = value.strip()
            if verb:
                add(verb)
        elif op == 'mode':
            mode = value
            mode_given = True
        else:
            fail(f'Unknown operation: {op}')

    if resetting or not verbs:
        if old_sv is None:
            if mode_given and not resetting:
                return None, 11, ['No spinner verbs are set. '
                                  'Use a theme or add a phrase first.']
            return None, 10, ['spinnerVerbs is not set in this file.']
        new = dict(data)
        del new['spinnerVerbs']
        if resetting:
            lines = ['Remove spinnerVerbs from this file.']
        else:
            lines = ['The verb list is now empty, so spinnerVerbs is removed '
                     'from this file.']
        return new, 0, lines

    new_mode = mode or 'replace'
    new_sv = dict(old_sv) if isinstance(old_sv, dict) else {}
    new_sv['mode'] = new_mode
    new_sv['verbs'] = verbs

    if old_sv == new_sv:
        return None, 10, [f'No change: {len(verbs)} verbs, mode {new_mode}.']

    if old_mode and old_mode != new_mode:
        mode_text = f'{old_mode} -> {new_mode}'
    else:
        mode_text = new_mode
    lines = [f'Verbs: {before} -> {len(verbs)}, mode: {mode_text}']
    counts = []
    if added:
        counts.append(f'add {added}')
    if skipped:
        counts.append(f'skip {skipped} duplicate(s)')
    if removed:
        counts.append(f'remove {removed}')
    if counts:
        lines.append('Changes: ' + ', '.join(counts))

    new = dict(data)
    new['spinnerVerbs'] = new_sv
    return new, 0, lines


def write(path, data):
    """Write the settings in one step and keep the indent and file mode."""
    _, text = read_settings(path)
    real = os.path.realpath(path)
    folder = os.path.dirname(real)
    os.makedirs(folder, exist_ok=True)

    indent = 2
    match = re.search(r'^([ \t]+)"', text, re.M)
    if match:
        whitespace = match.group(1)
        indent = '\t' if '\t' in whitespace else len(whitespace)
    output = json.dumps(data, indent=indent, ensure_ascii=False) + '\n'

    fd, tmp = tempfile.mkstemp(dir=folder, prefix='.' + os.path.basename(real) + '.',
                               suffix='.tmp')
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as handle:
            handle.write(output)
        if os.path.exists(real):
            shutil.copymode(real, tmp)
        else:
            umask = os.umask(0)
            os.umask(umask)
            os.chmod(tmp, 0o666 & ~umask)
        os.replace(tmp, real)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


HOOK_MARKER = 'manage_claude_spinner_verbs'


def is_rotation_hook(handler):
    return (isinstance(handler, dict) and handler.get('type') == 'command'
            and isinstance(handler.get('command'), str)
            and HOOK_MARKER in handler['command']
            and '--rotate' in handler['command'])


def session_start_groups(data, path):
    """Return the hooks object and its SessionStart list."""
    hooks = data.get('hooks', {})
    if not isinstance(hooks, dict):
        fail(f'hooks in {path} is not a JSON object.')
    groups = hooks.get('SessionStart', [])
    if not isinstance(groups, list):
        fail(f'hooks.SessionStart in {path} is not a list.')
    return hooks, groups


def rotation_commands(groups):
    return [handler['command']
            for group in groups if isinstance(group, dict)
            and isinstance(group.get('hooks'), list)
            for handler in group['hooks'] if is_rotation_hook(handler)]


def hook_plan(path, action, argv):
    """Return (new settings or None, exit code, summary lines)."""
    data, _ = read_settings(path)
    hooks, groups = session_start_groups(data, path)
    found = rotation_commands(groups)
    command = shlex.join(argv)

    if action == 'install' and found == [command]:
        return None, 10, ['The rotation hook is already in this file.']
    if action == 'remove' and not found:
        return None, 10, ['There is no rotation hook in this file.']

    new_groups = []
    placed = False
    for group in groups:
        if not isinstance(group, dict) or not isinstance(group.get('hooks'), list):
            new_groups.append(group)
            continue
        handlers = []
        for handler in group['hooks']:
            if not is_rotation_hook(handler):
                handlers.append(handler)
            elif action == 'install' and not placed:
                handler = dict(handler)
                handler['command'] = command
                handlers.append(handler)
                placed = True
        if handlers:
            group = dict(group)
            group['hooks'] = handlers
            new_groups.append(group)

    if action == 'install':
        if not placed:
            new_groups.append({'hooks': [{'type': 'command', 'command': command}]})
        verb = 'Update' if found else 'Add'
        lines = [f'{verb} the SessionStart hook: {command}']
    else:
        lines = ['Remove the SessionStart hook that rotates the theme.']

    new_hooks = dict(hooks)
    if new_groups:
        new_hooks['SessionStart'] = new_groups
    else:
        new_hooks.pop('SessionStart', None)
    new = dict(data)
    if new_hooks:
        new['hooks'] = new_hooks
    else:
        new.pop('hooks', None)
    return new, 0, lines


def parse_ops(args):
    ops = []
    for arg in args:
        op, _, value = arg.partition(':')
        ops.append((op, value))
    return ops


def main():
    command, args = sys.argv[1], sys.argv[2:]

    if command == 'themes':
        for path in args:
            try:
                count = len(theme_verbs(path))
            except ValueError:
                count = '?'
            name = os.path.basename(path)
            if name.endswith('.json'):
                name = name[:-5]
            print(f'{name}\t{count}')
        return 0

    if command == 'show':
        data, _ = read_settings(args[0])
        sv = data.get('spinnerVerbs')
        if sv is None:
            print('unset')
            return 0
        if not isinstance(sv, dict) or not is_verb_list(sv.get('verbs', [])):
            print('invalid')
            return 0
        verbs = sv.get('verbs', [])
        print(f"{sv.get('mode', '')}\t{len(verbs)}")
        for verb in verbs:
            print(verb)
        return 0

    if command == 'hook-status':
        data, _ = read_settings(args[0])
        hooks = data.get('hooks')
        groups = hooks.get('SessionStart') if isinstance(hooks, dict) else None
        if isinstance(groups, list):
            for found in rotation_commands(groups):
                print(found)
        return 0

    if command == 'hook':
        path, action, step = args[0], args[1], args[2]
        new, code, lines = hook_plan(path, action, args[3:])
        if step == 'plan':
            for line in lines:
                print(line)
        elif code == 0:
            write(path, new)
        return code

    if command in ('plan', 'apply'):
        new, code, lines = plan(args[0], parse_ops(args[1:]))
        if command == 'plan':
            for line in lines:
                print(line)
        elif code == 0:
            write(args[0], new)
        return code

    fail(f'Unknown command: {command}')


sys.exit(main())
PY
)"

py() {
  python3 -I -c "$PY_HELPER" "$@"
}

# Print the settings file of scope $1.
settings_file_for() {
  case "$1" in
    user)    echo "${CLAUDE_HOME}/settings.json" ;;
    project) echo "${PROJECT_DIR}/.claude/settings.json" ;;
    local)   echo "${PROJECT_DIR}/.claude/settings.local.json" ;;
  esac
}

# Print the file of theme $1: a name from the theme dir, or a path to a file.
theme_path() {
  local name="$1"
  if [[ -f "${THEMES_DIR}/${name}.json" ]]; then
    echo "${THEMES_DIR}/${name}.json"
  elif [[ ( "$name" == */* || "$name" == *.json ) && -f "$name" ]]; then
    resolve_path "$name"
  else
    error "No such theme: ${name}. Run with --list to see the themes."
  fi
}

# Fill THEME_PATHS, THEME_NAMES and THEME_COUNTS from the theme dir.
load_themes() {
  THEME_PATHS=()
  THEME_NAMES=()
  THEME_COUNTS=()
  local f name count
  for f in "$THEMES_DIR"/*.json; do
    [[ -f "$f" ]] && THEME_PATHS+=("$f")
  done
  (( ${#THEME_PATHS[@]} > 0 )) || error "No themes found in ${THEMES_DIR}."
  while IFS=$'\t' read -r name count; do
    THEME_NAMES+=("$name")
    THEME_COUNTS+=("$count")
  done < <(py themes "${THEME_PATHS[@]}")
}

list_themes() {
  load_themes
  local i
  for (( i = 0; i < ${#THEME_NAMES[@]}; i++ )); do
    printf '  %-24s %s verbs\n' "${THEME_NAMES[$i]}" "${THEME_COUNTS[$i]}"
  done
}

# Set STATE_SET, STATE_INVALID, STATE_MODE and STATE_COUNT from the
# settings file.
read_state() {
  local out first
  out="$(py show "$SETTINGS_FILE")" || exit 1
  first="${out%%$'\n'*}"
  STATE_INVALID=false
  STATE_MODE=""
  STATE_COUNT=0
  if [[ "$first" == "unset" ]]; then
    STATE_SET=false
  elif [[ "$first" == "invalid" ]]; then
    STATE_SET=true
    STATE_INVALID=true
  else
    STATE_SET=true
    STATE_MODE="${first%%$'\t'*}"
    STATE_COUNT="${first#*$'\t'}"
  fi
}

print_state() {
  read_state
  info "Settings : $(tilde "$SETTINGS_FILE")"
  if $STATE_INVALID; then
    warn "spinnerVerbs has an unexpected shape. Fix it by hand, or remove it."
  elif $STATE_SET; then
    info "Verbs    : ${STATE_COUNT}, mode ${STATE_MODE:-(not set)}"
  else
    info "Verbs    : not set in this file"
  fi
  if [[ "$SCOPE" == "user" && -n "$(rotation_hook)" ]]; then
    info "Rotation : on (a SessionStart hook sets the theme of the day)"
  fi
  warn_other_scopes
}

# Warn when another scope also sets spinnerVerbs.
warn_other_scopes() {
  local s f out
  for s in user project local; do
    [[ "$s" == "$SCOPE" ]] && continue
    f="$(settings_file_for "$s")"
    [[ "$f" == "$SETTINGS_FILE" || ! -f "$f" ]] && continue
    out="$(py show "$f" 2>/dev/null)" || continue
    [[ "${out%%$'\n'*}" == "unset" ]] && continue
    warn "spinnerVerbs is also set in $(tilde "$f") (${s} scope)."
  done
  return 0
}

show_verbs() {
  local out verb
  print_state
  $STATE_SET || return 0
  $STATE_INVALID && return 0
  out="$(py show "$SETTINGS_FILE")" || exit 1
  echo ""
  while IFS= read -r verb; do
    echo "  ${DIM}-${RESET_COLOR} ${verb}"
  done < <(printf '%s\n' "$out" | tail -n +2)
}

# Back up the settings file when --backup is set and the file exists.
backup_settings() {
  $BACKUP || return 0
  [[ -f "$SETTINGS_FILE" ]] || return 0
  local dir="${CLAUDE_HOME}/backups/spinner-verbs" bak
  bak="$(unique_path "${dir}/${SCOPE}-$(basename "$SETTINGS_FILE").$(date +%Y%m%d%H%M%S)")"
  mkdir -p "$dir"
  cp -p "$SETTINGS_FILE" "$bak"
  info "Backup written: $(tilde "$bak")"
}

# Ask $1 as a yes/no question. Return 0 for yes, 1 for no, 2 for no input.
confirm() {
  $ASSUME_YES && return 0
  local reply
  read -r -p "${BOLD}$1${RESET_COLOR} [y/N] " reply || { echo ""; return 2; }
  [[ "$reply" =~ ^[Yy]$ ]] && return 0
  return 1
}

# Show the change that the operations make, ask, then write it.
# Return 1 when there was no input to answer the prompt, and 3 when the
# change cannot be made (the helper prints the reason).
run_change() {
  local out rc line
  out="$(py plan "$SETTINGS_FILE" "$@")" && rc=0 || rc=$?
  case "$rc" in
    0)  ;;
    10) info "$out"; return 0 ;;
    11) warn "$out"; return 0 ;;
    *)  return 3 ;;
  esac

  while IFS= read -r line; do
    info "$line"
  done <<< "$out"

  if ! $SKIP_ROTATION_WARNING && [[ "$SCOPE" == "user" && -n "$(rotation_hook)" ]]; then
    warn "The daily rotation is on. The next session start sets the theme of the day again."
  fi

  if $DRY_RUN; then
    $BACKUP && [[ -f "$SETTINGS_FILE" ]] && info "Would back up: $(tilde "$SETTINGS_FILE")"
    info "Dry run: nothing written."
    return 0
  fi

  confirm "Write this change to $(tilde "$SETTINGS_FILE")?" && rc=0 || rc=$?
  case "$rc" in
    0) ;;
    1) warn "Nothing written."; return 0 ;;
    *) warn "Aborted (no input). Pass --yes to run non-interactively."; return 1 ;;
  esac

  backup_settings
  py apply "$SETTINGS_FILE" "$@" && rc=0 || rc=$?
  (( rc == 0 )) || return 3
  success "Saved: $(tilde "$SETTINGS_FILE")"
  info "Start a new session if the spinner does not change."
}

# ── Rotation ──────────────────────────────────────────────────────────────────
# Print the command of the rotation hook in the user settings file, or nothing.
rotation_hook() {
  local f
  f="$(settings_file_for user)"
  [[ -f "$f" ]] || return 0
  py hook-status "$f" 2>/dev/null || true
}

# Fill ROTATION_PATHS from --themes, or with all themes.
load_rotation() {
  local name f
  local -a names=()
  ROTATION_PATHS=()
  if [[ -n "$ROTATION_THEMES" ]]; then
    IFS=',' read -r -a names <<< "$ROTATION_THEMES"
    for name in ${names[@]+"${names[@]}"}; do
      [[ -n "$name" ]] || continue
      [[ -f "${THEMES_DIR}/${name}.json" ]] \
        || error "No such theme: ${name}. Run with --list to see the themes."
      ROTATION_PATHS+=("${THEMES_DIR}/${name}.json")
    done
  else
    for f in "$THEMES_DIR"/*.json; do
      [[ -f "$f" ]] && ROTATION_PATHS+=("$f")
    done
  fi
  (( ${#ROTATION_PATHS[@]} > 0 )) || error "No themes to rotate."
}

# Print the file of the theme of the day.
theme_of_day() {
  local day count
  day=$(( $(date -u +%s) / 86400 ))
  count=${#ROTATION_PATHS[@]}
  echo "${ROTATION_PATHS[$(( ((day - ROTATION_EPOCH_DAY) % count + count) % count ))]}"
}

# Set the theme of the day without output. The SessionStart hook runs this,
# and Claude Code adds the stdout of that hook to the context of Claude.
rotate() {
  local rc
  load_rotation
  py apply "$SETTINGS_FILE" "clear:" "add:$(theme_of_day)" && rc=0 || rc=$?
  (( rc == 0 || rc == 10 )) || exit 1
  exit 0
}

# Show the hook change, ask, then write it. Return 0 when the hook is in the
# wanted state, 1 when there was no input, 3 on error, and 4 when declined.
hook_change() {
  local action="$1" out rc
  shift
  out="$(py hook "$SETTINGS_FILE" "$action" plan "$@")" && rc=0 || rc=$?
  case "$rc" in
    0)  ;;
    10) info "$out"; return 0 ;;
    *)  return 3 ;;
  esac
  info "$out"

  if $DRY_RUN; then
    info "Dry run: nothing written."
    return 0
  fi

  confirm "Write this change to $(tilde "$SETTINGS_FILE")?" && rc=0 || rc=$?
  case "$rc" in
    0) ;;
    1) warn "Nothing written."; return 4 ;;
    *) warn "Aborted (no input). Pass --yes to run non-interactively."; return 1 ;;
  esac

  backup_settings
  py hook "$SETTINGS_FILE" "$action" apply "$@" || return 3
  success "Saved: $(tilde "$SETTINGS_FILE")"
}

# Add the rotation hook, then set the theme of the day.
install_rotation() {
  local rc
  local -a argv
  load_rotation
  argv=("$(resolve_path "$0")" --rotate --claude "$CLAUDE_HOME")
  [[ -n "$ROTATION_THEMES" ]] && argv+=(--themes "$ROTATION_THEMES")
  hook_change install "${argv[@]}" && rc=0 || rc=$?
  (( rc == 0 )) || return "$rc"
  echo ""
  info "Theme of the day: $(basename "$(theme_of_day)" .json)"
  SKIP_ROTATION_WARNING=true
  run_change "clear:" "add:$(theme_of_day)" && rc=0 || rc=$?
  SKIP_ROTATION_WARNING=false
  return "$rc"
}

# Remove the rotation hook. The verbs stay.
remove_rotation() {
  local rc had
  had="$(rotation_hook)"
  hook_change remove && rc=0 || rc=$?
  (( rc == 0 )) || return "$rc"
  if [[ -n "$had" ]] && ! $DRY_RUN; then
    info "The current verbs stay. Run with --reset to remove them."
  fi
}

print_banner() {
  echo ""
  echo -e "${BOLD}╔══════════════════════════════════════════╗${RESET_COLOR}"
  echo -e "${BOLD}║   Claude Spinner Verbs                   ║${RESET_COLOR}"
  echo -e "${BOLD}╚══════════════════════════════════════════╝${RESET_COLOR}"
  echo ""
  $DRY_RUN && warn "DRY-RUN mode — no files will be modified."
  return 0
}

# ── Menu ──────────────────────────────────────────────────────────────────────
# Run a change from the menu. Exit when there is no input, and go back to the
# menu when the change cannot be made.
menu_change() {
  menu_run run_change "$@"
}

# Run command $1 with the other arguments from the menu. Exit when there is
# no input, and go back to the menu for all other results.
menu_run() {
  local rc
  "$@" && rc=0 || rc=$?
  (( rc == 1 )) && exit 1
  return 0
}

# Turn the daily rotation on or off from the menu.
menu_rotation() {
  local answer p names=""
  if [[ "$SCOPE" != "user" ]]; then
    warn "The rotation works with the user settings file only."
    return 0
  fi
  if [[ -n "$(rotation_hook)" ]]; then
    menu_run remove_rotation
    return 0
  fi
  read -r -p "Rotate all themes? [Y/n] " answer || { echo ""; exit 0; }
  if [[ "$answer" =~ ^[Nn]$ ]]; then
    pick_themes "Themes to rotate" || return 0
    for p in "${PICKED[@]}"; do
      names="${names:+${names},}$(basename "$p" .json)"
    done
  fi
  ROTATION_THEMES="$names"
  menu_run install_rotation
}

pick_scope() {
  local answer
  echo "Which settings file?"
  echo "  1) User     $(tilde "$(settings_file_for user)")  ${DIM}(all projects)${RESET_COLOR}"
  echo "  2) Project  $(tilde "$(settings_file_for project)")  ${DIM}(shared with the team)${RESET_COLOR}"
  echo "  3) Local    $(tilde "$(settings_file_for local)")  ${DIM}(you, this project)${RESET_COLOR}"
  while true; do
    read -r -p "Choose [1-3, default 1]: " answer || { echo ""; exit 0; }
    case "${answer:-1}" in
      1) SCOPE=user;    break ;;
      2) SCOPE=project; break ;;
      3) SCOPE=local;   break ;;
      *) warn "Type 1, 2 or 3." ;;
    esac
  done
  echo ""
}

# Ask for one or more theme numbers and fill PICKED with their files.
# Return 1 when the answer is empty.
pick_themes() {
  local answer n i
  local -a numbers
  load_themes
  echo ""
  for (( i = 0; i < ${#THEME_NAMES[@]}; i++ )); do
    printf '  %2d) %-24s %s verbs\n' "$(( i + 1 ))" "${THEME_NAMES[$i]}" "${THEME_COUNTS[$i]}"
  done
  while true; do
    read -r -a numbers -p "$1 (numbers separated by spaces, empty to go back): " \
      || { echo ""; exit 0; }
    (( ${#numbers[@]} > 0 )) || return 1
    PICKED=()
    for n in "${numbers[@]}"; do
      if [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#THEME_PATHS[@]} )); then
        PICKED+=("${THEME_PATHS[$(( n - 1 ))]}")
      else
        warn "No theme number ${n}."
        continue 2
      fi
    done
    return 0
  done
}

# Ask for phrases, one per line, and fill PHRASES. Return 1 when none.
read_phrases() {
  local line
  PHRASES=()
  echo ""
  echo "Type one phrase per line. Leave a line empty to finish."
  while read -r -p "> " line; do
    [[ -n "$line" ]] || break
    PHRASES+=("$line")
  done
  (( ${#PHRASES[@]} > 0 ))
}

run_menu() {
  local choice p other
  local -a ops
  [[ -n "$SCOPE" ]] || pick_scope
  SETTINGS_FILE="$(settings_file_for "$SCOPE")"

  while true; do
    print_state
    echo ""
    echo "  1) Use a theme (replaces the current verbs)"
    echo "  2) Add a theme to the current verbs"
    echo "  3) Remove a theme from the current verbs"
    echo "  4) Add your own phrases"
    echo "  5) Switch the mode (replace / append)"
    echo "  6) Show the current verbs"
    echo "  7) Remove the spinner verbs from this file"
    if [[ "$SCOPE" == "user" && -n "$(rotation_hook)" ]]; then
      echo "  8) Turn off the daily theme rotation"
    else
      echo "  8) Rotate the theme each day"
    fi
    echo "  q) Quit"
    read -r -p "Choose: " choice || { echo ""; exit 0; }
    echo ""

    case "$choice" in
      1|2|3)
        case "$choice" in
          1) pick_themes "Themes to use" || continue; ops=("clear:") ;;
          2) pick_themes "Themes to add" || continue; ops=() ;;
          *) pick_themes "Themes to remove" || continue; ops=() ;;
        esac
        for p in "${PICKED[@]}"; do
          [[ "$choice" == 3 ]] && ops+=("remove:${p}") || ops+=("add:${p}")
        done
        menu_change "${ops[@]}"
        ;;
      4)
        read_phrases || continue
        ops=()
        for p in "${PHRASES[@]}"; do
          ops+=("verb:${p}")
        done
        menu_change "${ops[@]}"
        ;;
      5)
        read_state
        if $STATE_INVALID; then
          warn "Fix spinnerVerbs by hand, or remove it first."
        elif ! $STATE_SET; then
          warn "No spinner verbs are set. Use a theme or add a phrase first."
        else
          [[ "$STATE_MODE" == "append" ]] && other=replace || other=append
          menu_change "mode:${other}"
        fi
        ;;
      6) show_verbs ;;
      7) menu_change "reset:" ;;
      8) menu_rotation ;;
      q|Q) exit 0 ;;
      *) warn "Unknown choice: ${choice}" ;;
    esac
    echo ""
  done
}

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --use|--add|--remove|--verb|--mode|--scope|--claude|--project|--themes)
      [[ $# -ge 2 ]] || error "Missing value for $1."
      case "$1" in
        --use)     USE+=("$2") ;;
        --add)     ADD+=("$2") ;;
        --remove)  REMOVE+=("$2") ;;
        --verb)    VERBS+=("$2") ;;
        --mode)    MODE="$2" ;;
        --scope)   SCOPE="$2" ;;
        --claude)  CLAUDE_HOME="$2" ;;
        --themes)  ROTATION_THEMES="$2" ;;
        *)         PROJECT_DIR="$2" ;;
      esac
      shift 2
      ;;
    --reset)   RESET=true;      shift ;;
    --show)    SHOW=true;       shift ;;
    --list)    LIST=true;       shift ;;
    --rotate)  ROTATE=true;     shift ;;
    --install-rotation) INSTALL_ROTATION=true; shift ;;
    --remove-rotation)  REMOVE_ROTATION=true;  shift ;;
    --backup)  BACKUP=true;     shift ;;
    --dry-run) DRY_RUN=true;    shift ;;
    --yes|-y)  ASSUME_YES=true; shift ;;
    --help|-h) usage ;;
    *) error "Unknown argument: $1. Run with --help for usage." ;;
  esac
done

# ── Validation ────────────────────────────────────────────────────────────────
command -v python3 >/dev/null 2>&1 || error "python3 is required."
[[ -n "$THEMES_DIR" ]] || error "Theme dir not found: ${SCRIPT_DIR}/../spinner-verbs"

case "$SCOPE" in
  ""|user|project|local) ;;
  *) error "--scope must be user, project or local." ;;
esac
case "$MODE" in
  ""|replace|append) ;;
  *) error "--mode must be replace or append." ;;
esac

EDITS=$(( ${#USE[@]} + ${#ADD[@]} + ${#REMOVE[@]} + ${#VERBS[@]} ))
[[ -n "$MODE" ]] && EDITS=$(( EDITS + 1 ))
if $RESET && (( EDITS > 0 )); then
  error "--reset runs on its own. Remove the other action flags."
fi
if { $SHOW || $LIST; } && { $RESET || (( EDITS > 0 )); }; then
  error "--show and --list run on their own. Remove the action flags."
fi

ROTATION_ACTIONS=0
$ROTATE           && ROTATION_ACTIONS=$(( ROTATION_ACTIONS + 1 ))
$INSTALL_ROTATION && ROTATION_ACTIONS=$(( ROTATION_ACTIONS + 1 ))
$REMOVE_ROTATION  && ROTATION_ACTIONS=$(( ROTATION_ACTIONS + 1 ))
if (( ROTATION_ACTIONS > 1 )) \
  || { (( ROTATION_ACTIONS > 0 )) && { $RESET || $SHOW || $LIST || (( EDITS > 0 )); }; }; then
  error "--rotate, --install-rotation and --remove-rotation run on their own."
fi
if [[ -n "$ROTATION_THEMES" ]] && ! $ROTATE && ! $INSTALL_ROTATION; then
  error "--themes works with --rotate and --install-rotation only."
fi
if (( ROTATION_ACTIONS > 0 )) && [[ "${SCOPE:-user}" != "user" ]]; then
  error "The rotation works with the user scope only."
fi

if $LIST; then
  list_themes
  exit 0
fi

# Expand ~ manually (argv is not shell-expanded).
CLAUDE_HOME="${CLAUDE_HOME/#\~/$HOME}"
CLAUDE_HOME="${CLAUDE_HOME%/}"
PROJECT_DIR="${PROJECT_DIR/#\~/$HOME}"
[[ -d "$PROJECT_DIR" ]] || error "Project directory not found: ${PROJECT_DIR}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

if [[ "${SCOPE:-user}" == "user" ]] || $BACKUP; then
  [[ -d "$CLAUDE_HOME" ]] || error "Claude home not found: ${CLAUDE_HOME}"
fi
# The rotation hook stores this path, so make it absolute.
if [[ -d "$CLAUDE_HOME" ]]; then
  CLAUDE_HOME="$(cd "$CLAUDE_HOME" && pwd)"
fi

# ── Run ───────────────────────────────────────────────────────────────────────
if (( ROTATION_ACTIONS > 0 )); then
  SCOPE=user
  SETTINGS_FILE="$(settings_file_for user)"
  $ROTATE && rotate

  print_banner
  print_state
  echo ""
  if $INSTALL_ROTATION; then
    install_rotation && rc=0 || rc=$?
  else
    remove_rotation && rc=0 || rc=$?
  fi
  echo ""
  case "$rc" in
    0|4) exit 0 ;;
    *)   exit 1 ;;
  esac
fi

if $SHOW; then
  SCOPE="${SCOPE:-user}"
  SETTINGS_FILE="$(settings_file_for "$SCOPE")"
  show_verbs
  exit 0
fi

if $RESET || (( EDITS > 0 )); then
  SCOPE="${SCOPE:-user}"
  SETTINGS_FILE="$(settings_file_for "$SCOPE")"

  OPS=()
  if $RESET; then
    OPS+=("reset:")
  fi
  if (( ${#USE[@]} > 0 )); then
    OPS+=("clear:")
    for t in "${USE[@]}"; do
      p="$(theme_path "$t")" || exit 1
      OPS+=("add:${p}")
    done
  fi
  if (( ${#REMOVE[@]} > 0 )); then
    for t in "${REMOVE[@]}"; do
      p="$(theme_path "$t")" || exit 1
      OPS+=("remove:${p}")
    done
  fi
  if (( ${#ADD[@]} > 0 )); then
    for t in "${ADD[@]}"; do
      p="$(theme_path "$t")" || exit 1
      OPS+=("add:${p}")
    done
  fi
  if (( ${#VERBS[@]} > 0 )); then
    for t in "${VERBS[@]}"; do
      OPS+=("verb:${t}")
    done
  fi
  [[ -n "$MODE" ]] && OPS+=("mode:${MODE}")

  print_banner
  print_state
  echo ""
  run_change "${OPS[@]}" || exit 1
  echo ""
  exit 0
fi

[[ -t 0 ]] || error "No action given and no terminal for the menu. Run with --help for usage."
print_banner
run_menu
