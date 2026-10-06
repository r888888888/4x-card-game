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
- *"Spike: try a hex map."* → a `spike/` branch, no item (see [Spikes](#spikes)).

## Guardrails

- **Stop hook** ([scripts/test-hook.sh](../scripts/test-hook.sh)): when Claude finishes a turn after
  changing code, tests, or data, the suite runs. Failures go back to Claude, which must fix them
  before it stops. The hook is skipped when nothing relevant changed, and it is paused while
  `.claude/tdd-red` exists (the red checkpoint, where failures are expected). On a `spike/` branch
  it reports failures without blocking. It blocks at most once per turn, so it can't loop.
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

A spike is an exploratory branch for learning: trying a design, a library, a UI idea or a rule change
to see how it feels. Ask for one in plain language (*"Spike: what would a hex map look like?"*).

- **No spec, no tests.** A spike needs no backlog item and no acceptance criteria, and the TDD rules
  don't apply on it. Claude branches `spike/<topic>` from `main` (in a worktree if another session is
  live in the checkout) and commits on it freely.
- **The Stop hook doesn't block.** On a `spike/` branch it still runs the suite but only reports
  failures; it doesn't send Claude back to fix them.
- **Findings, not code, are the output.** Claude ends a spike with a short summary: what was tried,
  what was learned, and a recommendation. If the spike started from a backlog item, the summary goes
  in that item's Design notes; otherwise it goes in a new item (via the `spec` skill) when you want
  to pursue it, or nowhere if the idea is dropped.
- **Merging is the exception.** Spike branches stay unmerged by default. When the work should land,
  it's rebuilt on an item branch test-first (Claude may copy spike code across while doing so, but
  the tests come first). You may still ask to merge a spike as-is when it changes no rules, e.g.
  tooling, docs or a UI experiment you liked, provided the suite is green. Untested changes to
  `engine/`, `autoload/` or the loader never merge.
- **Cleanup.** Claude asks before deleting an unmerged spike branch, as with any branch. Keeping one around
  for reference is fine. Once a spike is merged, its branch and worktree are cleaned up like any merged branch.

## Files

| Path | Purpose |
|---|---|
| `CLAUDE.md` | Rules Claude always follows in this repo |
| `.claude/skills/spec/` | Procedure: request → backlog item |
| `.claude/skills/tdd/` | Procedure: backlog item → merged change |
| `.claude/skills/add-effect/` | Recipe for a new card effect op |
| `.claude/skills/add-decision/` | Recipe for a new kind of decision the player owes (a `pending()` kind) |
| `.claude/skills/add-card-field/` | Recipe for a new field on cards (`TYPE_FIELDS`, `INT_FIELDS`, `CardTypeFields`) |
| `.claude/skills/balance/` | Procedure: compare balance (sim) between `main` and the checkout |
| `.claude/skills/project-review/` | Procedure: whole-project architecture and test review → backlog items; `scan.sh` for the mechanical checks |
| `.claude/settings.json` | Stop hook + permission to run tests without prompting |
| `docs/backlog/` | Items, templates, status flow |
| `docs/testing.md` | How tests are run and written, the helpers, and a one-line index of the test files (each file's `##` header says what it covers) |
| `scripts/test.sh` | Test entry point (re-imports new classes, filters, runs the files in parallel shards) |
| `scripts/test-hook.sh` | Stop hook |
| `tests/lib/test_case.gd` | Assertions, fixtures, helpers |
