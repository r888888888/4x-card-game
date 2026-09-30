---
id: 091
title: Shared test helpers and one test per Famine behavior
type: feature
status: ready
branch: feat/091-shared-test-helpers
---

## Goal
Several helpers are copied between test files, although `docs/testing.md` says to move a helper into
`test_case.gd` once two files need it. And 083 turned the old starvation tests into Famine tests, so the same
Famine behavior is now asserted in two or three files. Move the helpers to the libraries and keep one test per
behavior, so the items that follow (092–096) add tests to one place. Tests only: no engine change.

## Acceptance criteria
- [ ] AC1: `press_key(main, keycode)` lives in `tests/lib/test_case.gd`; the copies in `test_board_labels`,
  `test_details_modal`, `test_menu`, `test_start_screen` and `test_tech_tree_modal` are gone, and those tests
  pass unedited otherwise.
- [ ] AC2: `load_with(extra_cards)` (parse `TEST_CARDS` plus extra cards, returning `{cards, errors, warnings}`)
  lives in `test_case.gd`; the copies in `test_trash`, `test_harmful_ops` and `test_gain_per_keyword` are gone
  (`test_gain_per_keyword` keeps a local wrapper only if it still needs its extra resource keyword).
- [ ] AC3: `research_engine()` (a `tech_engine(["pottery", "writing"])` with Research played) lives in
  `tests/lib/tech_case.gd`; the copies in `test_changed` and `test_ui_queries` are gone. `test_pending`'s variant
  (built on `pending_engine`) is renamed if it still differs.
- [ ] AC4: `config_errors_for(cards, overrides, deck := {"farm": 1}) -> Array[String]` in `test_case.gd` parses a
  config against a parsed card db and returns its errors; the seven `config_errors` helpers become one-line
  wrappers over it (or are removed where a direct call reads as well).
- [ ] AC5: Each of these Famine behaviors is asserted in one file only:
  - the first hungry upkeep kills 1 pop: `test_famine` (drop `test_food_upkeep::test_shortfall_starves_pop` and
    `test_a_deeper_shortfall_still_kills_1_pop_at_the_first_famine`, and
    `test_famine_guard::test_without_silo_the_famine_kills_1`);
  - deaths come from the territory with the most pop, ties to the first settled: `test_harmful_ops` for
    `lose_pop` and `test_famine::test_famine_deaths_use_the_most_pop_rule` for the Famine (drop
    `test_food_upkeep::test_starvation_hits_the_biggest_territory` and
    `test_starvation_tie_goes_to_the_territory_settled_first`);
  - the forecast's `starve` with no guard: `test_forecast` (drop
    `test_famine_guard::test_forecast_starve_without_guard`).
  Before deleting each, confirm (and note in the Test plan) which kept test asserts the same numbers.
- [ ] AC6: No file in `engine/`, `ui/`, `autoload/` or `sim/` changes; the suite is green; the test count drops by
  exactly the tests AC5 removes. `docs/testing.md` lists the new helpers.

## Out of scope
- Retyping `Object` engines to `GameEngine` across the suite (each item does it in the files it touches, per 090).
- Content tests (092).

## Design notes
- `test_food_upkeep.gd` keeps pop eating food, eating after production, 0 pop eating nothing and
  `food_upkeep` 0; update its header comment to point at `test_famine.gd` for shortfalls.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->

## Log
- 2026-09-30: Specced from the project review (duplicated helpers; triple Famine coverage since 083).
