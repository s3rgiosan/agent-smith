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
| [`manage_claude_projects.sh`](claude/scripts/README.md#manage_claude_projectssh) | Lists every project a Claude home knows about and moves or purges them — a move renames the project's folder, rewrites path references and updates its config entry; a purge removes its sessions and config entry (memory is kept unless you say so). |
| [`add_caveman_badge.sh`](claude/scripts/README.md#add_caveman_badgesh) | Patches a `ccstatusline` config to add (or remove) the caveman Statusline badge widget. |

#### [`claude/spinner-verbs/`](claude/spinner-verbs/README.md)

Custom spinner verb themes for Claude Code — the action phrases shown while Claude is working.

## License

MIT
