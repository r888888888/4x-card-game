---
id: 169
title: Bring the docs, skills and review scan in line with the code
type: feature
status: ready
branch: feat/169-docs-and-housekeeping
---

## Goal
The docs Claude reads every session say what the code does, so later items have less to keep in sync and nobody
builds on a stale description. From the 2026-10-01 project review.

## Acceptance criteria
- [ ] AC1: CLAUDE.md: the UI design line no longer mentions "the side panel" (gone since 115); it names the
  government overlay's cards and the tech tree's techs as the buttons that may fill. Two rules are added: "When a rule
  change makes a path unreachable, remove its code and tests in the same item, or name the item that will." (How work
  flows) and "Other sessions work in this checkout: build items in a worktree." (Git).
- [ ] AC2: PLAN.md's layout block names every script in `engine/` (not `effects/`), `ui/`, `sim/` and `autoload/`
  once, and none that doesn't exist (`side_panel.gd` goes; `anarchy.gd`, `card_face.gd`, `card_motion.gd`, `toasts.gd`,
  `log_drawer.gd`, the three button scripts and the rest come in). The stale lines are fixed: the turn loop's "After
  turn 20" (100 turns), the pending decisions (explore, discard, renewal, government), "harmful ops and real events come
  later" (lines 16 and 355), the Supply button (now Buy Cards in the top bar) and the Events row (gone in 137).
- [ ] AC3: `docs/testing.md`'s table has one row per `tests/test_*.gd` and no row for a file that doesn't exist (the
  12 missing today: actions, civ_flavor, civ_home, civ_start_building, discounts, event_eras, famine_relief,
  gain_actions, government_deck, hand_size, housing_modifier, modifiers); the `test_pending` row no longer says
  "research".
- [ ] AC4: Tracked junk goes: `docs/TODO.md` (empty) and `ui/end_turn_button.gd.uid` (no script beside it).
- [ ] AC5: Skills: `add-effect` puts helpers in `engine/engine_core.gd` (since 125), lists the `needs_a_turn()` and
  `check_references()` hooks and the `start` trigger, and says to update PLAN.md's list of ops allowed on upkeep;
  `spec` re-lists `docs/backlog` and `docs/backlog/done` right before picking an id, and asks how `ScriptedBot` handles
  a new mechanic; `tdd` builds in a worktree when the checkout is shared, and adds a `docs/testing.md` row for each new
  test file.
- [ ] AC6: `.claude/skills/project-review/scan.sh` adds four checks, each run once against the state before AC3–AC4 to
  see it fire: orphan `.uid` files and empty tracked files (under "Tracked files that shouldn't be"); public
  `GameEngine` methods returning `bool` with no `<name>_error` partner, wherever they sit in the file (replacing the
  check that only reads under `# --- Actions ---`); test files missing from `docs/testing.md`; and the number of test
  files typing an engine `Object`.

## Out of scope
- Rules from the review that only hold once their item lands: the `GameState` copy rule (171) and the pending-decision
  rule and `add-decision` skill (172).
- Splitting `game_engine.gd` (583) and `config_loader.gd` (532), both past the 500-line warning: not yet needed.

## Design notes
- Docs and tooling only: no engine change and no new test. Verify with the greps behind each criterion and a green
  suite.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|

## Log
- 2026-10-01: Specced from the project review.
