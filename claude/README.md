# Claude

Part of [Agent Smith](../README.md): tools, scripts and skills for agent-driven development.

Everything here customizes Claude Code: what it can do, how it looks, and how its homes are kept tidy. Each folder has its own README with the details.

---

## [`commands/`](./commands/README.md)

Slash commands you type to start a workflow: `/orchestrate` runs a turn as an orchestrator, and `/cf-settings-report` reports on Cloudflare zone settings.

## [`skills/`](./skills/README.md)

Skills Claude picks up when a task matches: `grill-me` stress-tests a plan, and `mac-app-ui` holds a Mac app's UI to the macOS HIG.

## [`scripts/`](./scripts/README.md)

Shell scripts that run Claude Code installations: a status line, installers for the commands and skills, and a manager for moving and purging projects.

## [`spinner-verbs/`](./spinner-verbs/README.md)

Themes for the phrases shown while Claude works.

---

## What's Inside

```
claude/
├── commands/
│   ├── orchestrate.md
│   └── cf-settings-report.md
├── skills/
│   ├── grill-me/
│   └── mac-app-ui/
├── scripts/
│   ├── claude_statusline.sh
│   ├── install_claude_commands.sh
│   ├── install_claude_skills.sh
│   └── manage_claude_projects.sh
└── spinner-verbs/
    └── *.json                ← one file per theme
```

---

## License

[MIT](../LICENSE)
