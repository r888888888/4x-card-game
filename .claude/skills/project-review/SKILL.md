---
name: project-review
description: Whole-project health review of this Godot card game - architecture critique, test-suite review (stale, low-value and duplicated tests, gaps), and CLAUDE.md / skill updates - then, if the user agrees, backlog items sequenced to minimize churn. Use when the user asks to review or critique the codebase or architecture, audit the tests, find low-value tests, "health check", or "what should we clean up". Not for reviewing a diff or PR (use code-review).
argument-hint: "[focus: architecture | tests | process; default all]"
---

# Project review

A read-only review of the whole project, reported in chat. Don't edit code, tests or docs during the review.
Backlog items come only afterwards, and only if the user asks (phase 5).

## 0. Gather

1. Check `git branch --show-current` and `git status`. Other sessions work in this checkout; note what's live
   and don't touch it.
2. Run `.claude/skills/project-review/scan.sh`. It prints candidates (sizes, duplicated helpers, private
   access, padding asserts, untested public functions, string literals, UI conditions). **Every hit is a lead,
   not a finding**: read the code before reporting it.
3. Read CLAUDE.md, PLAN.md, `docs/testing.md`, `docs/development-process.md`, `docs/backlog/README.md`
   (including **Planned order**), the skills in `.claude/skills/`, and `.claude/settings*.json`.
4. Read `engine/game_engine.gd` and the loader in full, the effect base class and a few effects, and outline
   the UI scripts (`grep -n '^func \|^var '`), reading the action and refresh paths.

## 1. Architecture

List strengths briefly (what to keep), then problems ranked by impact, each with a `file:line` link and a
concrete fix. Check:

- **Engine/UI boundary.** Any `ui/` code that decides legality, filters, groups or calculates from engine
  state is a CLAUDE.md violation. Every action needs a `*_error()` query, and the UI must call it rather than
  re-deriving the condition.
- **Cohesion and size.** Scripts near the 500/700-line limits; one class mixing several subsystems; state and
  rules in one object (can the state be copied for forecast, undo or bot lookahead?).
- **Consistency.** The same concept tracked several ways (e.g. modal "waiting for the player" states), the same
  check copied into several actions, actions that emit `changed` more or less than once.
- **Snapshot and forecast safety.** Code that runs real rules on a hand-made snapshot: does the snapshot cover
  everything those rules can touch? Are only `upkeep_ok()` ops allowed on upkeep?
- **Data model.** Card types and resources as constants (CLAUDE.md rule); per-type fields in
  `DataLoader.TYPE_FIELDS`; effect parameters validated against a whitelist (e.g. which zones `create` may
  target); dependency cycles between classes.
- **Drift.** PLAN.md layout and API text versus the tree; `docs/testing.md`'s helper table versus `tests/lib/` (`test_docs` checks the file index); tracked junk;
  local permissions that contradict CLAUDE.md.

## 2. Tests

Group findings as: **broken** (the test no longer checks what its name says), **low value**, **consolidation**,
**gaps**. Check:

- **Stale tests.** For tests named after a mechanism (reshuffle, discard, starvation…), confirm the mechanism
  still happens under the current rules. Asserts that still pass after a rule change are the usual trap: in
  039/040 a reshuffle test passed only because the draw it was meant to trigger had become 0 cards. Confirm
  with a scratch script (below), and turn a confirmed case into a bug item.
- **Content tests.** `tests/test_content.gd` may assert invariants only, never exact numbers from `data/`.
- **Low value.** `check(true…)` padding, the same assertion repeated across files, tests that only check a
  config block exists, several tests replaying the same scripted games separately.
- **Consolidation.** Helpers duplicated across files (and same-named helpers that behave differently),
  per-file engine builders that `test_case.gd` could provide, calls to private `_` members, tests filed
  outside their feature file, runs of one-line validation tests that could be one table-driven test.
- **Gaps.** Public engine functions no test mentions, behaviors covered only by a stale test, `ui/` without a
  smoke test, effect parameters that accept values nothing tests.
- Note the suite's size and run time: it tells you whether consolidation is about speed or only about upkeep.

Scratch reproduction (in the scratchpad, never in `tests/`):
```gdscript
extends SceneTree
func _initialize() -> void:
	var t = load("res://tests/lib/test_case.gd").new()
	var e: GameEngine = t.make_engine({"farm": 6})
	e.end_turn()
	print("hand=%d deck=%d discard=%d" % [e.zone("hand").size(), e.zone("deck").size(), e.zone("discard").size()])
	quit()
```
Run it with `godot --headless --path . --script <scratchpad>/repro.gd`.

## 3. Process

- **CLAUDE.md:** rules the review shows are missing, or that the code breaks. Propose exact wording, and keep it short.
- **Skills:** steps a skill is missing (e.g. `add-effect` not knowing about a newer hook), and recurring
  workflows without a skill (look at the last ~10 backlog items for a repeated shape).

## 4. Report

In chat, in this order: a one-paragraph verdict; architecture (strengths, then ranked problems); tests (broken,
low value, consolidation, gaps); CLAUDE.md changes; skills. Use `file:line` links and concrete fixes. End by
offering to spec the findings as backlog items, with a suggested first item. Don't publish it as an artifact
unless asked.

## 5. Backlog items (only when the user asks)

1. Ask the few questions that change the items (approach, scope splits), with a recommended answer each.
2. Use the `spec` skill for each item. Run `ls docs/backlog docs/backlog/done` right before picking each id: other sessions add
   items in parallel. Never edit or renumber another session's item; renumber your own if you collide.
3. Group small related fixes into one item and split large ones (at most ~6 criteria each). For refactors,
   add an acceptance criterion that pins behavior: existing tests pass unedited. If the refactor touches the
   rules or `sim/`, add a Manual check for the user: the sim output (`scripts/sim.sh 20`) is identical before and
   after (balance runs are manual; the item doesn't run it).
4. **Sequence to minimize churn**, and explain each position:
   - docs and housekeeping first (so later items have less to keep in sync);
   - bugs that restore lost coverage next;
   - test infrastructure (shared helpers) before any item that adds tests;
   - regression guards (simulator, UI smoke test) before the refactors they guard;
   - compact the tests that cover some code before refactoring that code;
   - constants and schemas before new code that would use them;
   - move logic out of the UI before restructuring engine state;
   - unify models before splitting the class that holds them;
   - split UI files last, after rules have left them;
   - place feature items that touch refactored areas after those refactors, show the trade-off (churn against
     waiting for gameplay), and let the user choose.
5. Record the order in the **Planned order** section of `docs/backlog/README.md`. Update the existing list
   (keep done items or mark them); don't add a second section.
6. Leave items as `draft` until the user approves their criteria.
