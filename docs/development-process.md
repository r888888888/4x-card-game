# Development process

How features and bugs go from an idea to `main`, with Claude Code doing most of the
implementation, test-first. Claude's own rules are in [CLAUDE.md](../CLAUDE.md); the step-by-step
procedures are the skills in `.claude/skills/`.

## Overview

```
 you: idea / bug report
        │
        ▼
 ┌──────────────┐   /spec        docs/backlog/NNN-slug.md
 │ 1. Spec      │ ─────────────► status: ready (no approval step)
 └──────────────┘
        │  /tdd NNN
        ▼
 ┌──────────────┐   branch feat/NNN-slug or fix/NNN-slug
 │ 2. Red       │   Claude writes failing tests, one per acceptance criterion,
 └──────────────┘   and confirms each fails for the right reason
        │
        ▼
 ╔══════════════╗   status: red-review. Claude stops and shows you
 ║ CHECKPOINT   ║   AC → test mapping + failure output.
                    This is where you review the criteria too.
 ╚══════════════╝   You: approve / ask for changes
        │
        ▼
 ┌──────────────┐   minimum code to pass → refactor with the suite green
 │ 3. Green +   │   commit on the branch at each green point
 │    refactor  │
 └──────────────┘
        │
        ▼
 ┌──────────────┐   full suite, real data loads, docs updated,
 │ 4. Verify    │   manual UI checklist (if any); status: review
 └──────────────┘
        │  you: accept → Claude merges to main (asks first); status: done
        ▼
```

## Your role vs Claude's

| Step | You | Claude |
|---|---|---|
| Spec | Describe the goal; answer questions | Asks clarifying questions, writes the item and its criteria as `ready` |
| Red | Review the criteria and tests: do they capture what you meant? | Writes tests, runs them, explains each failure |
| Green/refactor | Nothing (unless Claude hits a design question) | Implements, refactors, commits on the branch |
| Verify | Run the manual checklist for UI changes; accept | Runs the suite, updates PLAN.md / README / item, reports |
| Merge | Say "merge" | Merges to `main`, marks the item `done` |

## Starting work

Ask in plain language:

- *"New feature: a market row you can buy cards from."* → Claude uses the `spec` skill.
- *"Bug: with seed 42, playing Caravan on turn 3 gives 0 food."* → the `spec` skill, bug template.
- *"Implement 004"* or `/tdd 004` → the `tdd` skill.
- *"Spec and build it; I'll review at the red checkpoint."* → both, in sequence.

## Guardrails

- **Stop hook** ([scripts/test-hook.sh](../scripts/test-hook.sh)): when Claude finishes a turn after
  changing code, tests, or data, the suite runs. Failures go back to Claude, which must fix them
  before it stops. The hook is skipped when nothing relevant changed, and it is paused while
  `.claude/tdd-red` exists (the red checkpoint, where failures are expected). It blocks at most
  once per turn, so it can't loop.
- **The runner fails loudly**: parse errors, runtime errors inside a test, tests with no assertions,
  and filters that match nothing all count as failures.
- **Approved tests are a contract**: Claude may not weaken them to get green; it has to stop and ask.

## What needs a test

| Change | Test first? |
|---|---|
| Engine rules, effects, turn loop, scoring | Yes |
| Loader validation (new fields, new error messages) | Yes |
| New effect op | Yes (see the `add-effect` skill) |
| Card/config balance numbers in `data/` | No new test; the suite must stay green. Balance is judged later, in a dedicated balance item (the `balance` skill), not per change |
| UI layout / visuals | No test for the look; `test_ui_smoke` must stay green (catches script errors); logic moves to the engine (tested) + manual checklist |
| Docs, comments, pure renames | No |

## Spikes

When the right design is unclear, Claude may prototype on a `spike/<topic>` branch without tests to
learn. Spike code never merges: the findings go into the backlog item's Design notes, and the real
change is rebuilt test-first.

## Files

| Path | Purpose |
|---|---|
| `CLAUDE.md` | Rules Claude always follows in this repo |
| `.claude/skills/spec/` | Procedure: request → backlog item |
| `.claude/skills/tdd/` | Procedure: backlog item → merged change |
| `.claude/skills/add-effect/` | Recipe for a new card effect op |
| `.claude/skills/balance/` | Procedure: compare balance (sim) between `main` and the checkout |
| `.claude/skills/project-review/` | Procedure: whole-project architecture and test review → backlog items; `scan.sh` for the mechanical checks |
| `.claude/settings.json` | Stop hook + permission to run tests without prompting |
| `docs/backlog/` | Items, templates, status flow |
| `docs/testing.md` | How tests are written and run |
| `scripts/test.sh` | Test entry point (re-imports new classes, filters) |
| `scripts/test-hook.sh` | Stop hook |
| `tests/lib/test_case.gd` | Assertions, fixtures, helpers |
