# Claude Skills

Custom skills for Claude Code. Each subdirectory here is one skill — a folder containing a `SKILL.md` (with `name`/`description` frontmatter) that Claude loads when the description matches the task.

Install with [`../scripts/install_claude_skills.sh`](../scripts/README.md#install_claude_skillssh) (symlinks by default, so edits here take effect immediately).

## `grill-me`

A relentless interview that stress-tests a plan, decision, or design until you and Claude reach a shared understanding — every branch of the decision walked, nothing silently assumed.

Maps the plan as a **design tree** and works it in **rounds**: each round asks the whole *frontier* (every decision whose prerequisites are already settled), numbered, each with a recommended answer. Your answers reshape the tree; the frontier is recomputed and the next round asked. Facts about the environment are Claude's job to gather (read-only checks or a dispatched sub-agent), never yours to supply; a running decision log keeps status, recommendation, and blocking dependencies between rounds. Triggers on any "grill" phrase — e.g. "grill me on this".
