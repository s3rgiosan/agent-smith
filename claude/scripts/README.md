# Claude Scripts

Shell scripts for maintaining Claude Code installations.

## `update_claude_paths.sh`

Fixes up a `.claude` directory after you move a project folder. Does two things:

1. **Renames Claude's encoded project dirs** under `projects/`, `file-history/`, `todos/`, `shell-snapshots/`, `debug/`. Prefix-match cascades to every subproject — one run handles a whole parent-dir move. Merges into existing entries if the target already exists.
2. **Rewrites path references in file contents** across every text file in `.claude`. Skips binaries and symlinks, ignores `.git/` and `node_modules/`.

Works with BSD and GNU `sed`, and any `.claude` location (not just `~/.claude`).

```bash
./update_claude_paths.sh \
  --old /Users/MrAnderson/projects \
  --new /Users/MrAnderson/work/projects \
  --claude /Users/MrAnderson/.claude
```

Flags:

| Flag | Description |
|------|-------------|
| `--old` | Original directory path (required) |
| `--new` | New directory path (required) |
| `--claude` | Path to `.claude` folder (default: `~/.claude`) |
| `--backup` | Keep `.bak` copy of each modified file |
| `--dry-run` | Preview changes, no writes |
| `--no-tilde` | Skip the extra `~/foo` pass (on by default when `--old` is under `$HOME`) |
| `--help` | Show usage |

## `purge_claude_sessions.sh`

Interactive TUI project wiper. Lists every project recorded inside a `.claude` instance (with session count, last activity, and a `[memory]` marker when applicable) and lets you pick one or more to nuke. By default the `memory/` directory and `MEMORY.md` inside each picked project are preserved — pass `--wipe-memory` to blow those away too.

Keys:

| Key | Action |
|-----|--------|
| `↑` / `↓` or `k` / `j` | Move cursor |
| `PgUp` / `PgDn` | Jump by page |
| `g` / `G` | Top / bottom |
| `space` | Toggle current row |
| `a` | Toggle all |
| `enter` | Confirm selection |
| `q` | Abort |

```bash
# Interactive purge against ~/.claude
./purge_claude_sessions.sh

# Use a non-default .claude folder
./purge_claude_sessions.sh --claude /Users/MrAnderson/.claude-work

# Also blow away memory/ and MEMORY.md for every picked project
./purge_claude_sessions.sh --wipe-memory

# Preview what would be removed
./purge_claude_sessions.sh --dry-run
```

Flags:

| Flag | Description |
|------|-------------|
| `--claude` | Path to the `.claude` folder (default: `$CLAUDE_HOME` or `~/.claude`) |
| `--wipe-memory` | Also delete `memory/` and `MEMORY.md` in selected projects |
| `--dry-run` | Preview deletions without removing files |
| `--yes` | Skip the final confirmation prompt |
| `--help` | Show usage |

Behavior notes:

- Sessions are detected by UUID-named top-level entries, covering both layouts: flat `<uuid>.jsonl` (+ optional `<uuid>/` sidecar) and nested `<uuid>/subagents/*.jsonl`.
- Per-project deletion log prints every removed entry; summary reports project count + total entries.
- Project directory is `rmdir`-ed after a successful wipe (macOS `.DS_Store` is stripped first). When `memory/` or `MEMORY.md` is preserved the directory stays; the script reports what's left.
- TUI renders inline (no alternate screen). Terminal state is restored on normal exit, `Ctrl-C`, or `SIGTERM`.

## `add_caveman_badge.sh`

Patches a [ccstatusline](https://github.com/sirmalloc/ccstatusline) `settings.json` to add (or remove) a `custom-command` widget that renders the [caveman](https://github.com/JuliusBrussee/caveman) Statusline badge.

The badge script is resolved from the given Claude home at `<claude>/plugins/marketplaces/caveman/hooks/caveman-statusline.sh`, so multiple Claude installs can each get their own statusline config pointing at their own caveman install.

```bash
./add_caveman_badge.sh --claude /Users/MrAnderson/.claude

./add_caveman_badge.sh \
  --claude /Users/MrAnderson/.claude-work \
  --config /Users/MrAnderson/.config/ccstatusline/settings-work.json
```

Idempotent: re-running replaces any existing widget with id `caveman-badge`. A timestamped `.bak` is written next to the config by default.

Flags:

| Flag | Description |
|------|-------------|
| `--claude` | Path to the Claude home directory (default: `~/.claude`) |
| `--config` | Path to ccstatusline `settings.json` (default: `~/.config/ccstatusline/settings.json`) |
| `--line` | Zero-based index of the status line to patch (default: `0`) |
| `--position` | `prepend` or `append` within the line (default: `prepend`) |
| `--remove` | Remove the caveman badge instead of adding it |
| `--dry-run` | Print resulting JSON to stdout, no writes |
| `--no-backup` | Skip writing a `.bak` copy |
| `--help` | Show usage |
