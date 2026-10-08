---
id: 333
title: Remove red-phase scaffolding from the tests, and check it stays gone
type: chore
status: done
branch: feat/333-test-scaffolding
---

## Goal
Red-phase tricks that let a failing test parse (engines typed `Object`, untyped `load()`s, `has_method` and `== null`
guards) stay in the suite long after green. They hide renames: `test_day_mode.gd:102` falls back to a theme colour if
`figure()` disappears, and `test_eurekas.gd:146` skips its assertions if `tile()` does. CLAUDE.md already asks for
engines to be retyped once green; nothing checks it. Tests that only pin a removal ("X is gone") stay forever too.

## Acceptance criteria
- [x] AC1: Given `tests/` (outside `tests/lib/`), when the suite runs, then a test fails naming file:line for each
  variable or cast typed `Object` that holds an engine, each script loaded into an untyped `Variant`
  (`: Variant = load(`), and each `has_method(` call, unless the line carries a `# scaffolding-ok: <reason>` comment.
  It passes on the cleaned suite.
- [x] AC2: The current cases are cleaned: engines retyped `GameEngine` in `test_raids.gd` (390, 409),
  `test_revolution.gd` (93–134), `test_tech_tree.gd` (133–146) and `test_training.gd` (74–122); the bot preloaded
  typed (no `if BOT == null` guards) in `test_generic_bot.gd`, `test_generic_bot_cache.gd`, `test_generic_raids.gd`,
  `test_generic_rollouts.gd` and `test_sim_strategies.gd`; the `has_method` guards on hooks that exist removed
  (`test_counters`, `test_insight`, `test_unrest`, `test_event_modal`, `test_raid_modal`, `test_key_sounds`,
  `test_end_turn_key`, `test_focus_ring`, `test_legend_key`, `test_start_screen`, `test_eurekas`, `test_day_mode`,
  `test_settings`), each test now asserting unconditionally.
- [x] AC3: The removal pins are deleted: `test_card_faces.gd:181–183`, `test_growth_cards.gd:363`,
  `test_research.gd:337`, `test_revolt_modal.gd:38`, `test_territory_cards.gd:173`; a test left with no other
  assertion is deleted whole, and the Log lists each deleted test.
- [x] AC4: Every remaining test passes; no assertion is weakened (a guarded assertion becomes an unguarded one).
- [x] AC5: CLAUDE.md's TDD rule "Type engines `Object` only in the red phase; retype them as `GameEngine` once green."
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
- 2026-10-06: built. The check (`tests/lib/scaffolding_checks.gd`) flags an engine typed Object (an `Object` var or
  cast from a call whose name ends in `engine`, an `e`/`engine` parameter typed Object, and, added at green with its
  own failing test, an `*engine()` helper returning Object), `: Variant = load(` and `has_method(`; comment lines and
  lines with `# scaffolding-ok: <reason>` are skipped. It replaces scan.sh's "engine as Object" section.
- Cleaned beyond AC2's list because the check found them: `test_territory_names.gd` (11 engines and `names_engine`),
  `test_tech_tree.gd`'s `links_engine`, `test_generic_raids.gd`'s `e == null` guards, `test_launch_options.gd` (now
  `LaunchOptions`), `test_sfx.gd` (its `load` of a sound file typed `Resource`: not scaffolding), `test_sunrise_art.gd`
  (`SunriseArt` and `Palette` directly, its null guards gone), `test_legend_key.gd` (`LegendKey`), the raid modal's
  `hooks` flag. `test_resource_tokens.gd`'s figure casts are `Odometer`. `test_engine_structure.gd` keeps its
  `has_method` with a `# scaffolding-ok` reason.
- AC3: no test was left without an assertion, so none was deleted whole; the has_method pins were removed from
  `test_the_squash_is_gone` (Anim's constants stay), `test_manual_growth_is_gone` (the Grow button check stays),
  `test_the_engine_has_no_reveal_passes_or_lost_techs`, `test_the_board_has_no_revolt_button` and
  `test_the_realm_has_no_collapse_toggles_or_grow`. Those remaining "X is gone" checks could go too (not listed here).
- Follow-up: scaffolding the check can't see stays: scripts loaded by path and held as Object/Script, constants read
  by name (`Script.get`, `get_script_constant_map`) "so this file parses before it exists": test_theme,
  test_type_tokens, test_spacing_tokens, test_navigator, test_script_size, test_select_list, test_toasts,
  test_title_screen, test_notification_flags, test_end_turn_key (`key()`), test_odometer, test_research (`gconst`).
  The three identical `forecast(main, key)` helpers (test_counters, test_insight, test_unrest) belong with 334.
