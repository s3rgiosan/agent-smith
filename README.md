# Agent Smith

![Agent Smith](agent-smith.gif)

Collection of tools, scripts, skills, and agents for agent-driven development.

## What's here

### [`scripts/`](scripts/README.md)

Standalone shell scripts for day-to-day agent and tool maintenance.

| Script | Description |
|--------|-------------|
| [`update_wiki_paths.sh`](scripts/README.md#update_wiki_pathssh) | Rewrites path references inside an Obsidian vault after moving a project folder. |

### [`claude/`](claude/README.md)

Claude Code assets, scripts, and customizations.

#### [`claude/scripts/`](claude/scripts/README.md)

Shell scripts for maintaining Claude Code installations.

| Script | Description |
|--------|-------------|
| [`update_claude_paths.sh`](claude/scripts/README.md#update_claude_pathssh) | Fixes up a `.claude` directory after moving a project folder — renames encoded project dirs and rewrites path references in file contents. |
| [`purge_claude_sessions.sh`](claude/scripts/README.md#purge_claude_sessionssh) | Interactively pick one or more projects in a `.claude` instance to wipe (sessions only by default; `--wipe-memory` also nukes `memory/` and `MEMORY.md`). |
| [`add_caveman_badge.sh`](claude/scripts/README.md#add_caveman_badgesh) | Patches a `ccstatusline` config to add (or remove) the caveman Statusline badge widget. |

#### [`claude/spinner-verbs/`](claude/spinner-verbs/README.md)

Custom spinner verb themes for Claude Code — the action phrases shown while Claude is working.

## License

MIT
