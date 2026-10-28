# Claude Commands

Part of [Agent Smith](../../README.md): tools, scripts and skills for agent-driven development.

Type a slash, start a workflow. Each `*.md` file here becomes `/<filename>` once installed into a Claude home.

---

## Installation

Install with [`install_claude_commands.sh`](../scripts/README.md#install_claude_commandssh). It symlinks by default, so edits here take effect immediately.

```bash
git clone https://github.com/s3rgiosan/agent-smith.git
cd agent-smith/claude/scripts

# All commands → ~/.claude (or $CLAUDE_CONFIG_DIR)
./install_claude_commands.sh

# One command, into another Claude home
./install_claude_commands.sh orchestrate --claude ~/.claude-work

# Remove
./install_claude_commands.sh --uninstall
```

Start a new session after installing so Claude Code picks up the commands.

---

## `/orchestrate`

Turns the session into an orchestrator: Fable plans, decomposes, and verifies, while all the actual exploration and implementation is delegated to cheaper subagents (`sonnet`, `opus`, `haiku`) via the Agent tool's `model` override.

```
/orchestrate migrate the settings screen to the Settings API and add tests
```

The command's frontmatter carries `model: fable`, so it runs on Fable **regardless of the session model** — no manual `/model` switch to start. It also sets `disable-model-invocation: true`, so Claude can't wander into orchestrator mode on its own — it only activates when you type `/orchestrate`.

The full delegation policy (which model and agent type gets which kind of work) lives in the command itself — see the "Who gets what" table in `orchestrate.md`. Short version: Fable keeps planning and verification; `sonnet` is the default executor; `opus` handles ambiguous or stubborn work; `haiku` takes truly mechanical edits.

**Model scope caveat:** a slash command's `model:` override applies **for the rest of that turn only** — the next prompt resumes the session model. For a multi-turn orchestration session, run `/model fable` as well, or re-invoke `/orchestrate` each turn. There is no supported way for a command to persist a session model switch.

---

## `/cf-settings-report`

Generates a markdown report comparing Cloudflare zone settings across **every zone on the account**, grouped by dashboard category (SSL/TLS, Security, Scrape Shield, Speed / Optimization, Caching, Network, DNS, Logging / Misc). Each category renders a matrix — rows are domains, columns are the settings that vary — with off-majority cells flagged and a **Deviations & fixes** list (severity + action point) per category.

```
/cf-settings-report             # writes YYYY-MM-DD-cloudflare-zones-matrix.md
/cf-settings-report cf-audit    # writes YYYY-MM-DD-cf-audit.md
```

The file is written to the current directory, named after today's date and the optional name argument (a trailing `.md` is dropped).

Reads all data through the **`cloudflare-api`** MCP server (from the `cloudflare` plugin), which must be connected and authenticated. The command embeds a fixed generator that is run **verbatim** through that server's `execute` tool, so every run produces the same report from the same data. Because `execute` truncates large results, the generator emits in two passes (toggled by three constants at the top) that the command concatenates into the output file. `disable-model-invocation: true` — it only runs when you type `/cf-settings-report`.

---

## What's Inside

```
commands/
├── README.md                  ← you are here
├── orchestrate.md             ← /orchestrate
└── cf-settings-report.md      ← /cf-settings-report
```

---

## License

[MIT](../../LICENSE)
