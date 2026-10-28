# Claude Scripts

Part of [Agent Smith](../../README.md): tools, scripts and skills for agent-driven development.

Shell scripts that keep Claude Code installations running smoothly: a status line worth looking at, installers for this repo's commands and skills, and a manager for the projects a Claude home collects.

Each script runs in place from a clone of the repo and prints its flags with `--help`. Every script also has an extensionless symlink (`claude_statusline`, `install_claude_commands`, `install_claude_skills`, `manage_claude_projects`) that runs it.

```bash
git clone https://github.com/s3rgiosan/agent-smith.git
cd agent-smith/claude/scripts
```

---

## `claude_statusline.sh`

Everything you'd otherwise go looking for, right under the prompt: which account you're on, how much context is left, how close you are to the rate limits, and whether the prompt cache is still warm. Claude Code runs the script with the session's JSON on stdin and draws its output as three powerline rows:

```
 Personal   Opus 5.5 (1M)   Extra high   Normal   $12.50
 8%   5h 24% (14:30)   7d 41% (Fri 09:00)   cache 14:42
 0/3   agent-smith   main*   #42 changes requested   my-feature
```

### Row 1: who and what

| Segment | Example | Why it's there |
|---------|---------|----------------|
| Account | `Personal` | Two Claude homes look the same; this one tells you which you're in. |
| Model | `Opus 5.5 (1M)` | The model, by its product name. `(1M)` marks the 1M-token context window. |
| Thinking | `Extra high` | Effort level (`Low` to `Max`), or `Off`. It changes with `/effort`. |
| Speed | `Fast` / `Normal` | Whether fast mode is on. |
| Cost | `$12.50` | Session cost at list price. On a claude.ai plan it's an estimate, not a bill. |

### Row 2: how much is left

| Segment | Example | Why it's there |
|---------|---------|----------------|
| Context | `8%` | Context window used: your cue to `/compact` or start fresh. |
| 5-hour limit | `5h 24% (14:30)` | Usage of the 5-hour window and when it resets. |
| 7-day limit | `7d 41% (Fri 09:00)` | Usage of the weekly window and when it resets. |
| Prompt cache | `cache 14:42` / `cache cold` | When the cache expires. After a break, `cold` means the next prompt sends the whole context again. |

### Row 3: where you are

| Segment | Example | Why it's there |
|---------|---------|----------------|
| tsk | `0/3` | Done/total tasks of the folder's tsk project; `0/0` when it has none. |
| Project | `agent-smith` | The git repository, or the project folder outside one. |
| Branch | `main*` | Current branch; `*` when the working tree has changes. |
| Pull request | `#42 changes requested` | The open PR for the branch and its review state. |
| Worktree | `my-feature` | The worktree the session runs in. |

Segments with nothing to say stay out of the way: rate limits show only on claude.ai plans, the pull request only while one is open, the worktree only in a worktree session, and tsk progress only when `tsk` is installed. Colours run on across the rows, so no two neighbours match.

### Set it up

Point a Claude home's `settings.json` at the script:

```json
"statusLine": {
  "type": "command",
  "command": "/path/to/agent-smith/claude/scripts/claude_statusline.sh --account Work --theme onedark",
  "padding": 0
}
```

The line shows up on the next update (a reply, a mode change, `/compact`). Edits to the script apply on the next update too.

| Flag | Description |
|------|-------------|
| `--account` | Account name for the first segment (default: the folder name of `$CLAUDE_CONFIG_DIR`, or `.claude`) |
| `--theme` | Segment colours: `catppuccin-mocha` (default) or `onedark` |
| `--help` | Show usage |

Needs `jq`, a [Nerd Font](https://www.nerdfonts.com/) for the icons and a truecolor terminal for the colours.

---

## `install_claude_commands.sh`

Installs the slash commands from `claude/commands/` into a Claude home, so they show up as `/<name>` in every session.

Symlinks by default — edits in the repo take effect immediately, no reinstall. Pass `--copy` for a detached snapshot. Existing files are replaced (use `--backup` to keep a timestamped `.bak`; symlinks are replaced without one). Idempotent.

The script refuses to run when the target `commands/` folder is the repo's own `claude/commands/`, or overlaps it through a symlink. Without `--yes` it asks for confirmation, so a run with no terminal needs `--yes`.

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
| `--backup` | Save a timestamped `.bak` of any regular file being overwritten (a numeric suffix is added when the name is taken) |
| `--uninstall` | Remove the symlinks that point into this repo, then exit. Real files with a matching name (including `--copy` copies) and symlinks to other places are skipped with a warning |
| `--dry-run` | Print planned actions, write nothing |
| `--yes` | Skip the confirmation prompt |
| `--help` | Show usage |

`README.md` in the commands directory is skipped. A new session (or restart) is needed before Claude Code picks up newly installed commands.

---

## `install_claude_skills.sh`

Installs the skills from `claude/skills/` into a Claude home. A skill is a directory containing a `SKILL.md`; each such directory is installed as `<claude_home>/skills/<name>`.

Symlinks by default — edits in the repo take effect immediately, no reinstall. Pass `--copy` for a detached snapshot. Existing skill directories are replaced (use `--backup` to keep a copy; symlinks are replaced without one). Idempotent.

The script refuses to run when the target `skills/` folder is the repo's own `claude/skills/`, or overlaps it through a symlink. Without `--yes` it asks for confirmation, so a run with no terminal needs `--yes`.

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
| `--backup` | Copy any skill directory being overwritten to `<claude_home>/backups/skills/<name>.<timestamp>`, outside the folder Claude Code loads skills from |
| `--uninstall` | Remove the symlinks that point into this repo, then exit. Real directories with a matching name (including `--copy` copies) and symlinks to other places are skipped with a warning |
| `--dry-run` | Print planned actions, write nothing |
| `--yes` | Skip the confirmation prompt |
| `--help` | Show usage |

Only subdirectories with a `SKILL.md` are installed. A new session (or restart) is needed before Claude Code picks up newly installed skills.

---

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

**Move** asks for the new path (tab-completion works; `~` and relative paths are expanded), shows a dry-run preview and asks for confirmation. For a row whose path is unknown it first asks for the old path and only accepts one that encodes to the folder name. Leaving a path prompt empty goes back to the list. A new path inside the old one, or the other way round (`/x/proj` and `/x/proj/sub`), is rejected. A move:

1. Renames the project's folder under `projects/` and the folders of its sub-projects. Folders are matched by their real path, so moving `/x/proj` leaves a sibling `/x/proj-v2` alone. When the target folder already exists, only what it lacks is moved in; anything left over stays in the old folder with a warning.
2. Rewrites path references in the text files inside those folders (sessions, subagents, memory), anchored to a path-segment boundary. A second pass rewrites `~/…` forms when the old path is inside `$HOME`. Other projects' folders and the rest of the Claude home, such as `backups/`, are left as they are.
3. Rewrites the `projects` map of the config file as JSON; the rest of the config is left as it is. When the new path already has an entry, the two are merged: the existing entry's values win and the moved entry fills in what it lacks.
4. Rewrites the `project` field of the matching entries in `history.jsonl`, so prompt history follows the project. Prompt text, and lines that are not valid JSON or UTF-8, are left as they are.

Before any write, a move checks that the config is valid JSON and that `history.jsonl` can be read. The config and `history.jsonl` are copied to `<file>.move-bak.<epoch>` before they are edited, then replaced in one step with their file mode kept. If a step fails partway, the output names the step, the steps already done, and the backups.

**Purge** lists the picked projects, asks whether to delete memory too (only when one has memory), and asks for confirmation. It removes each project's sessions and their `file-history/<session>/` backups, its `sessions-index.json`, its folder once empty, and its config entry. Purge first checks that the config is valid JSON and stops with a warning before deleting anything if it is not. A timestamped `<config>.purge-bak.<epoch>` backup is written before the config is edited. Prompt history in `history.jsonl` is kept.

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
| `--backup` | Keep `.bak` copies of the session and memory files a move rewrites (`.bak.<epoch>` when a `.bak` already exists) |
| `--no-tilde` | Skip the extra `~/foo` pass on a move |
| `--help` | Show usage |

Behavior notes:

- The config file is `~/.claude.json` for the default home `~/.claude`, and `<home>/.claude.json` for any other home (where Claude Code writes it when `CLAUDE_CONFIG_DIR` is set).
- Sessions are UUID-named top-level entries of a project folder: `<uuid>.jsonl` files and `<uuid>/` dirs.
- Requires `python3`. Works with bash 3.2 (macOS) and BSD or GNU `sed`.
- The list renders inline (no alternate screen). Terminal state is restored on normal exit, `Ctrl-C`, or `SIGTERM`.

---

## What's Inside

```
scripts/
├── README.md                     ← you are here
├── claude_statusline.sh          ← three-row powerline status line
├── install_claude_commands.sh    ← installs claude/commands/ into a Claude home
├── install_claude_skills.sh      ← installs claude/skills/ into a Claude home
├── manage_claude_projects.sh     ← moves and purges a Claude home's projects
└── <name>                        ← extensionless symlink to each <name>.sh
```

---

## License

[MIT](../../LICENSE)
