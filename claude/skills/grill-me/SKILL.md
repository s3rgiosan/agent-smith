---
name: grill-me
description: Use when user wants to stress-test a plan, decision, or design, get grilled on their thinking, or uses any "grill" trigger phrase.
---

# Grill Me

## Purpose

Interview the user relentlessly about a plan, decision, or design until both sides reach a shared understanding — every branch of the decision walked, nothing silently assumed. For each question, provide your recommended answer with a short rationale.

## The Design Tree

Map the plan as a **design tree**: every decision branches into the decisions that hang off it. Your job is to visit every branch, not to march through a flat list.

## Working in Rounds

Work the tree in **rounds**, driven by the **frontier** — every decision whose prerequisites are already settled, i.e. the questions you can ask *now* without guessing at answers you haven't heard yet.

1. Ask the **whole frontier** in one round. Number each question; give each a recommended answer.
2. Wait for the user's answers before the next round.
3. Each answer reshapes the tree — settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier and ask the next round.
4. A question whose answer depends on another question still open **in this round** belongs to a *later* round, not this one.

Format each question like so:

```
❓ **Q1** — **<question title>**: <question body; may be multiple paragraphs, may include options>

➡️ <your recommended answer + short rationale>
```

## Facts Are Your Job, Never the User's

When a frontier question needs a fact from the environment (filesystem, codebase, tools), **find it yourself** — don't ask the user for anything you could look up.

1. If a question can be answered objectively from the codebase with quick read-only checks, inspect first.
2. When the lookup is non-trivial, dispatch a sub-agent to find it. Don't block the whole frontier on it: a running exploration is an unsettled prerequisite, so only the questions *downstream* of it wait — ask the rest of the frontier now.
3. If evidence and the user's statement conflict, surface the conflict and ask for resolution.

The *decisions* are the user's — put each to them and wait. The *facts* are yours to gather.

## Decision Log

Maintain a running decision log so nothing is lost between rounds:

- **Decision**
- **Status** — resolved or open
- **Recommendation**
- **Blocking dependencies**

## Stop Condition

The session is done only when the frontier is empty — every branch of the design tree visited, or explicitly accepted as an open risk by the user. Do not act on the plan until the user confirms you have reached a shared understanding.
