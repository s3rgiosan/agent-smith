# grill-me

Part of [Agent Smith](../../../README.md): tools, scripts and skills for agent-driven development.

A Claude Code skill that interviews you relentlessly about a plan, decision or design until you and Claude reach a shared understanding: every branch of the decision walked, nothing silently assumed.

---

## Installation

```bash
git clone https://github.com/s3rgiosan/agent-smith.git
cd agent-smith/claude/scripts

# Default → ~/.claude (or $CLAUDE_CONFIG_DIR)
./install_claude_skills.sh grill-me

# Another Claude home
./install_claude_skills.sh grill-me --claude ~/.claude-work
```

Uninstall:

```bash
./install_claude_skills.sh grill-me --uninstall
```

Start a new session after installing so Claude Code picks up the skill. See the [Claude scripts README](../../scripts/README.md#install_claude_skillssh) for every installer flag.

---

## Usage

Describe the plan and ask to be grilled:

```
"Grill me on this migration plan."
"Stress-test this design before I build it."
"Grill me: should we split the settings screen into tabs?"
```

Claude maps the plan as a **design tree** and works it in **rounds**. Each round asks the whole *frontier*, every decision whose prerequisites are already settled, as numbered questions:

```
❓ **Q1** — **<question title>**: <question body>

➡️ <recommended answer + short rationale>
```

Your answers reshape the tree, and Claude recomputes the frontier for the next round. Facts about the environment are Claude's job: it checks the codebase or dispatches a sub-agent instead of asking you. A running decision log keeps each decision's status, recommendation and blocking dependencies. The session ends only when the frontier is empty, and Claude does not act on the plan until you confirm you share an understanding.

---

## What's Inside

```
grill-me/
├── README.md     ← you are here
└── SKILL.md      ← design tree, rounds, facts, decision log, stop condition
```

---

## License

[MIT](../../../LICENSE)
