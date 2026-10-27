# Agent Smith

![Agent Smith](agent-smith.gif)

Tools, scripts, skills and agents for agent-driven development: the small things that make working with Claude Code faster, clearer and a little more fun.

## Scripts

Standalone shell scripts for day-to-day maintenance. Usage and flags live in `scripts/README.md`.

### `update_wiki_paths.sh`

Moved a project folder? Your Obsidian vault still points at the old path. This rewrites every reference in one sweep, across markdown, frontmatter and any other text file.

## Claude Code

Commands, skills, scripts and themes for Claude Code. Each folder under `claude/` has its own README.

### Commands

Slash commands, installed with `install_claude_commands.sh`. Details in `claude/commands/README.md`.

#### `/orchestrate`

Runs the turn on Fable as an orchestrator: Fable plans and verifies, and hands exploration and implementation to cheaper `sonnet`, `opus` and `haiku` subagents.

#### `/cf-settings-report`

One report for every Cloudflare zone on the account: a matrix per dashboard category, with the settings that drift from the majority flagged and a fix for each (via the `cloudflare-api` MCP).

### Skills

Skills Claude loads when the task matches, installed with `install_claude_skills.sh`. Details in `claude/skills/README.md`.

#### `grill-me`

A relentless interview that stress-tests a plan, decision or design, round after round, until every branch is walked and nothing is left assumed.

### Scripts

Shell scripts for running Claude Code installations. Usage and flags live in `claude/scripts/README.md`.

#### `claude_statusline.sh`

A three-row powerline status line under the prompt: account, model, effort, speed and cost; context, rate limits with their reset times and the prompt cache; tsk progress, project, branch, PR and worktree.

#### `install_claude_commands.sh`

Installs the slash commands into a Claude home. Symlinks by default, so edits in the repo apply at once; `--copy` for a snapshot, `--uninstall` to remove.

#### `install_claude_skills.sh`

The same for skills: symlinked by default, one skill or all of them, into any Claude home.

#### `manage_claude_projects.sh`

Every project a Claude home knows about, in one list. Move a project (its folder, path references, config entry and prompt history follow) or purge it (sessions and config entry go; memory stays unless you say so).

### Spinner verbs

Themes for the phrases Claude Code shows while it works ("Using the Force for 12s"): Movie Quotes, Monty Python, Pirate, Portuguese and Hugo. Details in `claude/spinner-verbs/README.md`.

## License

MIT
