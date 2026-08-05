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

#### [`claude/commands/`](claude/commands/README.md)

Custom slash commands for Claude Code.

| Command | Description |
|---------|-------------|
| [`/orchestrate`](claude/commands/README.md#orchestrate) | Runs the turn on Fable as an orchestrator — Fable plans and verifies, while exploration and implementation are delegated to cheaper `sonnet`/`opus`/`haiku` subagents. |
| [`/cf-settings-report`](claude/commands/README.md#cf-settings-report) | Generates a per-category matrix report of Cloudflare zone settings across every zone on the account, flagging cross-domain deviations with fixes (via the `cloudflare-api` MCP). |

#### [`claude/scripts/`](claude/scripts/README.md)

Shell scripts for maintaining Claude Code installations.

| Script | Description |
|--------|-------------|
| [`install_claude_commands.sh`](claude/scripts/README.md#install_claude_commandssh) | Installs the slash commands from `claude/commands/` into a Claude home (symlink by default, `--copy` for a snapshot, `--uninstall` to remove). |
| [`update_claude_paths.sh`](claude/scripts/README.md#update_claude_pathssh) | Fixes up a `.claude` directory after moving a project folder — renames encoded project dirs, rewrites path references in file contents, and updates the project's `~/.claude.json` entry (trust/allowlist/MCP). |
| [`purge_claude_sessions.sh`](claude/scripts/README.md#purge_claude_sessionssh) | Interactively pick one or more projects in a `.claude` instance to wipe (sessions only by default; `--wipe-memory` also nukes `memory/` and `MEMORY.md`, `--wipe-config` strips the project's `~/.claude.json` entry). |
| [`add_caveman_badge.sh`](claude/scripts/README.md#add_caveman_badgesh) | Patches a `ccstatusline` config to add (or remove) the caveman Statusline badge widget. |

#### [`claude/spinner-verbs/`](claude/spinner-verbs/README.md)

Custom spinner verb themes for Claude Code — the action phrases shown while Claude is working.

## License

MIT
