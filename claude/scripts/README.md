# Claude Scripts

Shell scripts for maintaining Claude Code installations.

## `install_claude_commands.sh`

Installs the slash commands from [`../commands/`](../commands/README.md) into a Claude home, so they show up as `/<name>` in every session.

Symlinks by default — edits in the repo take effect immediately, no reinstall. Pass `--copy` for a detached snapshot. Existing files are replaced (use `--backup` to keep a timestamped `.bak`; symlinks are replaced without one). Idempotent.

Pass one or more command names to install (or uninstall) just those; with no names, every shipped command is processed.

```bash
# Install all commands into ~/.claude (or $CLAUDE_CONFIG_DIR)
./install_claude_commands.sh

# Install only specific commands
./install_claude_commands.sh orchestrate cf-settings-report

# Snapshot copies into a non-default Claude home
./install_claude_commands.sh --claude /Users/MrAnderson/.claude-work --copy

# Preview, then remove
./install_claude_commands.sh --uninstall --dry-run
./install_claude_commands.sh orchestrate --uninstall
```

Flags:

| Flag | Description |
|------|-------------|
| `--claude` | Path to the Claude home directory (default: `$CLAUDE_CONFIG_DIR` or `~/.claude`) |
| `--copy` | Copy the files instead of symlinking them |
| `--backup` | Save a timestamped `.bak` of any regular file being overwritten |
| `--uninstall` | Remove the commands this repo installs, then exit |
| `--dry-run` | Print planned actions, write nothing |
| `--yes` | Skip the confirmation prompt |
| `--help` | Show usage |

`README.md` in the commands directory is skipped. A new session (or restart) is needed before Claude Code picks up newly installed commands.

## `install_claude_skills.sh`

Installs the skills from [`../skills/`](../skills/README.md) into a Claude home. A skill is a directory containing a `SKILL.md`; each such directory is installed as `<claude_home>/skills/<name>`.

Symlinks by default — edits in the repo take effect immediately, no reinstall. Pass `--copy` for a detached snapshot. Existing skill directories are replaced (use `--backup` to keep a timestamped `.bak`; symlinks are replaced without one). Idempotent.

Pass one or more skill names to install (or uninstall) just those; with no names, every shipped skill is processed.

```bash
# Install all skills into ~/.claude (or $CLAUDE_CONFIG_DIR)
./install_claude_skills.sh

# Install only a specific skill
./install_claude_skills.sh grill-me

# Snapshot copies into a non-default Claude home
./install_claude_skills.sh --claude /Users/MrAnderson/.claude-work --copy

# Preview, then remove
./install_claude_skills.sh --uninstall --dry-run
./install_claude_skills.sh grill-me --uninstall
```

Flags:

| Flag | Description |
|------|-------------|
| `--claude` | Path to the Claude home directory (default: `$CLAUDE_CONFIG_DIR` or `~/.claude`) |
| `--copy` | Copy the directories instead of symlinking them |
| `--backup` | Save a timestamped `.bak` of any skill directory being overwritten |
| `--uninstall` | Remove the skills this repo installs, then exit |
| `--dry-run` | Print planned actions, write nothing |
| `--yes` | Skip the confirmation prompt |
| `--help` | Show usage |

Only subdirectories with a `SKILL.md` are installed. A new session (or restart) is needed before Claude Code picks up newly installed skills.

## `manage_claude_projects.sh`

Lists every project a Claude home knows about and lets you move or purge them. A project is any folder under `projects/` plus any entry in the Claude config file that has no folder.

Each row shows last activity, session count, and the project's real path, with markers:

| Marker | Meaning |
|--------|---------|
| `[missing]` | The path no longer exists on disk (moved or deleted) |
| `[memory]` | The project has `memory/` or `MEMORY.md` |
| `[config only]` | Only a config entry is left; there is no folder under `projects/` |

Folder names encode the path lossily (every non-alphanumeric character becomes `-`), so the real path comes from the matching config key or from the `cwd` recorded in the project's sessions. A project with neither shows its raw folder name, dimmed. Rows are sorted by path, so sub-projects sit under their parent.

Keys:

| Key | Action |
|-----|--------|
| `↑` / `↓` or `k` / `j` | Move cursor |
| `PgUp` / `PgDn` | Jump by page |
| `g` / `G` | Top / bottom |
| `space` | Tick / untick the current row |
| `a` | Tick / untick all |
| `m` | Move the project under the cursor |
| `d` | Purge the ticked projects (the cursor row when none is ticked) |
| `q` | Quit |

**Move** asks for the new path (tab-completion works; `~` and relative paths are expanded), shows a dry-run preview and asks for confirmation. For a row whose path is unknown it first asks for the old path and only accepts one that encodes to the folder name. Leaving a path prompt empty goes back to the list. A move:

1. Renames the project's folder under `projects/` and the folders of its sub-projects. Folders are matched by their real path, so moving `/x/proj` leaves a sibling `/x/proj-v2` alone. When the target folder already exists, only what it lacks is moved in; anything left over stays in the old folder with a warning.
2. Rewrites path references in the text files inside those folders (sessions, subagents, memory), anchored to a path-segment boundary. A second pass rewrites `~/…` forms when the old path is under `$HOME`. Other projects' folders and the rest of the Claude home, such as `backups/`, are left as they are.
3. Rewrites the config file as JSON. When the new path already has an entry, the two are merged: the existing entry's values win and the moved entry fills in what it lacks.
4. Rewrites the `project` field of the matching entries in `history.jsonl`, so prompt history follows the project. Prompt text is left as it is.

**Purge** lists the picked projects, asks whether to delete memory too (only when one has memory), and asks for confirmation. It removes each project's sessions and their `file-history/<session>/` backups, its `sessions-index.json`, its folder once empty, and its config entry. A timestamped `<config>.purge-bak.<epoch>` backup is written before the config is edited.

After each action the list is rebuilt.

```bash
# Open the project list for ~/.claude
./manage_claude_projects.sh

# Use another Claude home (one set through CLAUDE_CONFIG_DIR)
./manage_claude_projects.sh --claude /Users/MrAnderson/.claude-work

# Preview every action without writing anything
./manage_claude_projects.sh --dry-run

# Move without the list (no confirmation)
./manage_claude_projects.sh \
  --old /Users/MrAnderson/projects \
  --new /Users/MrAnderson/work/projects
```

Flags:

| Flag | Description |
|------|-------------|
| `--claude` | Path to the Claude home (default: `~/.claude`) |
| `--old` | Original project path; with `--new`, moves without the list |
| `--new` | New project path |
| `--dry-run` | Preview every action without writing anything |
| `--backup` | Keep `.bak` copies of files a move rewrites |
| `--no-tilde` | Skip the extra `~/foo` pass on a move |
| `--help` | Show usage |

Behavior notes:

- The config file is `~/.claude.json` for the default home `~/.claude`, and `<home>/.claude.json` for any other home (where Claude Code writes it when `CLAUDE_CONFIG_DIR` is set).
- Sessions are UUID-named top-level entries of a project folder: `<uuid>.jsonl` files and `<uuid>/` dirs.
- Requires `python3`. Works with bash 3.2 (macOS) and BSD or GNU `sed`.
- The list renders inline (no alternate screen). Terminal state is restored on normal exit, `Ctrl-C`, or `SIGTERM`.

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
