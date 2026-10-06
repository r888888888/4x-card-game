---
id: 333
title: Remove red-phase scaffolding from the tests, and check it stays gone
type: chore
status: in-progress
branch: feat/333-test-scaffolding
---

## Goal
Red-phase tricks that let a failing test parse (engines typed `Object`, untyped `load()`s, `has_method` and `== null`
guards) stay in the suite long after green. They hide renames: `test_day_mode.gd:102` falls back to a theme colour if
`figure()` disappears, and `test_eurekas.gd:146` skips its assertions if `tile()` does. CLAUDE.md already asks for
engines to be retyped once green; nothing checks it. Tests that only pin a removal ("X is gone") stay forever too.

## Acceptance criteria
- [ ] AC1: Given `tests/` (outside `tests/lib/`), when the suite runs, then a test fails naming file:line for each
  variable or cast typed `Object` that holds an engine, each script loaded into an untyped `Variant`
  (`: Variant = load(`), and each `has_method(` call, unless the line carries a `# scaffolding-ok: <reason>` comment.
  It passes on the cleaned suite.
- [ ] AC2: The current cases are cleaned: engines retyped `GameEngine` in `test_raids.gd` (390, 409),
  `test_revolution.gd` (93–134), `test_tech_tree.gd` (133–146) and `test_training.gd` (74–122); the bot preloaded
  typed (no `if BOT == null` guards) in `test_generic_bot.gd`, `test_generic_bot_cache.gd`, `test_generic_raids.gd`,
  `test_generic_rollouts.gd` and `test_sim_strategies.gd`; the `has_method` guards on hooks that exist removed
  (`test_counters`, `test_insight`, `test_unrest`, `test_event_modal`, `test_raid_modal`, `test_key_sounds`,
  `test_end_turn_key`, `test_focus_ring`, `test_legend_key`, `test_start_screen`, `test_eurekas`, `test_day_mode`,
  `test_settings`), each test now asserting unconditionally.
- [ ] AC3: The removal pins are deleted: `test_card_faces.gd:181–183`, `test_growth_cards.gd:363`,
  `test_research.gd:337`, `test_revolt_modal.gd:38`, `test_territory_cards.gd:173`; a test left with no other
  assertion is deleted whole, and the Log lists each deleted test.
- [ ] AC4: Every remaining test passes; no assertion is weakened (a guarded assertion becomes an unguarded one).
- [ ] AC5: CLAUDE.md's TDD rule "Type engines `Object` only in the red phase; retype them as `GameEngine` once green."
  reads: "Red-phase scaffolding (engines typed `Object`, untyped `load()`s, `has_method` and `== null` guards) is
  removed in the refactor step (the suite checks)." The `tdd` skill's refactor step says the same.

## Out of scope
- Shared UI test helpers (334).
- Other low-value tests not listed here.

## Design notes
- `test_resource_tokens.gd`'s `as Object` casts are counter figures, not engines: retype them to the figure's class.
- `test_engine_structure.gd:62` checks `GameEngine` has a list of methods: keep it with a `# scaffolding-ok` reason, or
  turn it into a reference that fails to parse when a method goes.
- AC1 replaces `scan.sh`'s "Test files holding an engine as Object" section.
- During a red phase the AC1 check fails along with the new tests, which is expected at the checkpoint.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_scaffolding::test_an_engine_typed_object_is_named`, `test_a_script_loaded_untyped_is_named`, `test_has_method_is_named`, `test_a_reasoned_ok_comment_and_comment_lines_are_allowed`, `test_problems_are_sorted_by_file_then_line` |
| AC1, AC2 | `test_scaffolding::test_no_test_file_holds_red_phase_scaffolding` (the cleaned suite) |
| AC3 | deletions; listed in the Log |
| AC4 | the full suite stays green |
| AC5 | doc wording (`test_docs` checks the paths) |

## Log
- 2026-10-06: specced from the project review.
