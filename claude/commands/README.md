# Claude Commands

Custom slash commands for Claude Code. Each `*.md` file here becomes `/<filename>` once installed into a Claude home.

Install with [`../scripts/install_claude_commands.sh`](../scripts/README.md#install_claude_commandssh) (symlinks by default, so edits here take effect immediately).

## `/orchestrate`

Turns the session into an orchestrator: Fable plans, decomposes, and verifies, while all the actual exploration and implementation is delegated to cheaper subagents (`sonnet`, `opus`, `haiku`) via the Agent tool's `model` override.

```
/orchestrate migrate the settings screen to the Settings API and add tests
```

The command's frontmatter carries `model: fable`, so it runs on Fable **regardless of the session model** — no manual `/model` switch to start. It also sets `disable-model-invocation: true`, so Claude can't wander into orchestrator mode on its own — it only activates when you type `/orchestrate`.

The full delegation policy (which model and agent type gets which kind of work) lives in the command itself — see the "Who gets what" table in [`orchestrate.md`](orchestrate.md). Short version: Fable keeps planning and verification; `sonnet` is the default executor; `opus` handles ambiguous or stubborn work; `haiku` takes truly mechanical edits.

**Model scope caveat:** a slash command's `model:` override applies **for the rest of that turn only** — the next prompt resumes the session model. For a multi-turn orchestration session, run `/model fable` as well, or re-invoke `/orchestrate` each turn. There is no supported way for a command to persist a session model switch.

Inspired by [@fabiankaegy](https://github.com/fabiankaegy)'s own orchestrator slash command.
