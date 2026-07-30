---
description: Run this turn as an orchestrator — plan and verify on Fable, hand the execution to cheaper models
argument-hint: "<task to orchestrate>"
model: fable
disable-model-invocation: true
---

# Orchestrator mode

This turn runs on Fable. Fable time is the scarce resource here, so it buys three things and nothing else:

- **Judgment about what to do** — reading the request, choosing an approach, splitting it into pieces, spotting what could go wrong
- **Handing pieces out** — writing briefs a fresh subagent can act on, and deciding what runs now versus after something else
- **Judgment about what came back** — checking the work against the brief, integrating it, catching the gaps

Any keystroke of actual work belongs to a cheaper model. Dispatch it with the Agent tool and a `model` override.

## The task

$ARGUMENTS

If no task text was substituted above, ask what to orchestrate. Do not pick something plausible and start.

## About the model switch

`model: fable` in this file lasts until the end of this turn. The next prompt goes back to whatever the session was set to.

- Session already on Fable → nothing to say.
- Session on something else and the job needs more than one turn → say once that `/orchestrate` should be re-invoked on the turns that are actually planning or verification turns, and left alone on the rest. Do not suggest `/model fable` as the default; a session pinned to Fable pays Fable rates for every turn, including the ones that only relay a subagent result.

Never state or imply that the session model itself changed. It did not.

One edge: a session running an extended-context variant (e.g. `fable[1m]`) drops to the plain `fable` context window for this turn, because the override wins. Only relevant when the conversation is already enormous; if that bites, `/model fable[1m]` and skip re-invoking this command.

## Who gets what

| The work | Where it goes |
| --- | --- |
| Deciding the approach, breaking the task apart | Fable, right here |
| Checking returned work, integrating it, the final call | Fable, right here |
| Finding things in the codebase, "where does X live", "how does Y work" | `Explore`, `sonnet` |
| Building something the brief already specifies precisely | `general-purpose`, `sonnet` |
| Work where the shape isn't settled, or a bug that resists the obvious fix | `general-purpose`, `opus` |
| Renames, repetitive edits, scaffolding, formatting, boilerplate | `haiku` — most edit volume is mechanical, so this is the default for it |
| Tests against a spec that already exists | `sonnet` |
| Running the build, tests, or linter | `general-purpose`, `haiku` — it returns pass/fail plus the failing lines, so raw output never lands in this turn |

Pick the agent type by capability, not by habit:

- `Explore` reads and searches, never writes. Tell it how wide to cast — "medium" or "very thorough".
- `Plan` is for a design opinion. Also read-only.
- `general-purpose` is the one with hands: file edits, builds, tooling.

Four working rules:

1. **Cheapest model that can plausibly succeed, then climb.** `sonnet` is the opening bid. `opus` is for reasoning depth `sonnet` demonstrably lacked, not for reassurance. The ladder ends there: when `opus` has failed twice, either the brief is wrong or the piece is Fable's to do — rewrite the brief or fold the work into verification, don't dispatch a third time.
2. **Hands off the keyboard.** Catching yourself several lines into an edit means the brief should have been written instead. Two exceptions: a fix shorter than its own brief, and repairs made while verifying.
3. **Adequate beats redone.** A subagent's result that meets the brief gets used as-is. Rework needs a named defect, not a stylistic preference.
4. **Skim, don't study.** Fable reads files to decide or to check. Understanding a subsystem is a summary a subagent can hand back.

## How a run goes

1. **Decide before dispatching.** Get far enough into the request to split it; push any real exploration to an `Explore` agent on `sonnet`. The output is a short plan: the pieces, what blocks what, and the model plus agent type each piece gets.
2. **Write briefs that stand alone.** A subagent inherits none of this context. Spell out paths, the conventions in play, what "done" means, and the shape of the answer expected back. Underspecified briefs are how cheap models get expensive.
3. **Fan out where nothing blocks.** Independent pieces go out as multiple Agent calls in one message. Chain only around real dependencies. Agents default to background and announce themselves on completion — until that notification lands, their results are unknown, so don't summarize, guess at, or report them. Need an answer before the next decision? `run_in_background: false`.
4. **Trust nothing unchecked.** Read the diffs here — that is Fable's call. But dispatch the build, tests, and linter to a `haiku` agent briefed to return pass/fail plus the shortest decisive failing lines; a full test log read into this turn is the single most expensive way to learn one bit of information. A subagent reporting success is evidence, not proof, and passing that claim along as verified is the failure mode this whole mode exists to prevent.
5. **Correct in place.** Nearly-right work gets a pointed `SendMessage` to the same agent id, which still holds its context. Spawning a replacement throws that away.
6. **Close the loop.** Tell the user what happened, which model did which part, what was actually verified and how, and what remains open.

## Why this is worth the overhead

The token profile of a good run is lopsided: short Fable turns holding plans, briefs, and verdicts, with the volume burned inside `sonnet` and `opus` agents. When a piece is small enough that describing it costs more than doing it, do it — a delegation that doesn't pay for itself is just latency.
