# Agent Smith

![Agent Smith](agent-smith.gif)

> Tools, scripts and skills for agent-driven development.

The small things that make working with Claude Code faster, clearer and a little more fun: slash commands, skills, a status line, installers, a project manager, spinner verb themes, and shell scripts for the chores that pile up around agent-driven work.

Each folder has its own README with the details.

---

## Commands

Slash commands you type to start a workflow. Both set `disable-model-invocation: true`, so they run only when you type them.

### [`/orchestrate`](./claude/commands/README.md#orchestrate)

Runs the turn as an orchestrator: Fable plans, decomposes and verifies, and delegates exploration and implementation to cheaper subagents (`sonnet`, `opus`, `haiku`).

**Run with:** `/orchestrate <task>`

### [`/cf-settings-report`](./claude/commands/README.md#cf-settings-report)

Writes a markdown report comparing Cloudflare zone settings across every zone on the account, grouped by dashboard category, with off-majority settings flagged and a fix for each. Needs the `cloudflare-api` MCP server.

**Run with:** `/cf-settings-report [name]`

**[→ Commands README](./claude/commands/README.md)**

---

## Skills

Skills Claude loads by itself when the task matches their description.

### [grill-me](./claude/skills/grill-me)

A relentless interview that stress-tests a plan, decision or design. Maps it as a design tree and asks every open decision in numbered rounds, each with a recommended answer, until nothing is silently assumed.

**Triggers on:** "grill me", or any request to stress-test a plan, decision or design.

### [mac-app-ui](./claude/skills/mac-app-ui)

A UI standard for Mac apps (Tauri, Electron, WKWebView, SwiftUI, AppKit), built on Apple's Human Interface Guidelines for macOS. Applies the macOS type scale, semantic system colours and the user's accent, and wires every menu item and permission. Handover is gated on a conformance table checked against WKWebView snapshots and real AppKit renders.

**Triggers on:** building, restyling or reviewing a Mac app's UI; a Mac app that feels non-native, looks like a web page or a terminal, or has text that is too small.

**[→ Skills README](./claude/skills/README.md)**

---

## Claude Code scripts

### [`claude_statusline.sh`](./claude/scripts/README.md#claude_statuslinesh)

A three-row powerline status line: account, model, effort, speed and cost; context used, rate limits and prompt cache expiry; tsk progress, project, branch, pull request and worktree.

### [`install_claude_commands.sh`](./claude/scripts/README.md#install_claude_commandssh) and [`install_claude_skills.sh`](./claude/scripts/README.md#install_claude_skillssh)

Install this repo's commands and skills into a Claude home. Symlinks by default, so edits in the repo take effect immediately.

### [`manage_claude_projects.sh`](./claude/scripts/README.md#manage_claude_projectssh)

An interactive list of every project a Claude home knows about, to move a project to a new path or purge it, with sessions, memory, config and prompt history kept in step.

**[→ Claude scripts README](./claude/scripts/README.md)**

---

## Spinner verbs

### [Themes](./claude/spinner-verbs)

Replacement phrases for the ones Claude Code shows while it works: movie quotes, Monty Python, pirate, Portuguese and Hugo.

**[→ Spinner verbs README](./claude/spinner-verbs/README.md)**

---

## Standalone scripts

### [`update_wiki_paths.sh`](./scripts/README.md#update_wiki_pathssh)

Rewrites path references inside an Obsidian vault after a project folder moves.

**[→ Scripts README](./scripts/README.md)**

---

## Installation

```bash
git clone https://github.com/s3rgiosan/agent-smith.git
cd agent-smith/claude/scripts

# Commands and skills → ~/.claude (or $CLAUDE_CONFIG_DIR)
./install_claude_commands.sh
./install_claude_skills.sh

# Another Claude home
./install_claude_skills.sh --claude ~/.claude-work
```

Start a new session after installing so Claude Code picks up the new commands and skills. The status line is set in a Claude home's `settings.json` (see the [Claude scripts README](./claude/scripts/README.md#set-it-up)), and spinner verbs are merged into it (see the [spinner verbs README](./claude/spinner-verbs/README.md#usage)).

---

## Requirements

- [Claude Code](https://claude.ai/code).
- Bash (macOS, Linux, or WSL on Windows) for the shell scripts.
- `jq`, a [Nerd Font](https://www.nerdfonts.com/) and a truecolor terminal for `claude_statusline.sh`.
- `python3` for `manage_claude_projects.sh`.
- macOS with the Xcode command line tools for the `mac-app-ui` verification scripts.

---

## Contributing

Ideas and fixes are welcome; open a PR. The repo is laid out like this:

```
agent-smith/
├── claude/
│   ├── commands/            ← slash commands, one *.md per command
│   ├── skills/
│   │   └── skill-name/
│   │       ├── README.md
│   │       ├── SKILL.md
│   │       ├── references/  ← optional
│   │       └── scripts/     ← optional
│   ├── scripts/             ← status line, installers, project manager
│   └── spinner-verbs/       ← spinner verb themes, one *.json per theme
└── scripts/                 ← standalone shell scripts
```

---

## License

[MIT](LICENSE)
