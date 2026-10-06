---
id: 340
title: Loader tests as tables: the last one-off rejections and the "loads / defaults to" tests
type: chore
status: in-progress
branch: feat/340-loader-test-tables
---

## Goal
Most loader rejections already sit in `check_cases` tables (046) in ~55 feature files. What's left is one test per
case: 16 one-off rejection tests beside tables they could be rows of, and ~60 positive tests ("an event loads with its
discard turns", "the supply defaults to empty", "era defaults to 1") that each load a card or config and check a
value or two, often behind an `if r.cards.has("x"):` guard. A `check_loads` table does for accepted input what
`check_cases` does for rejected input, so a new field adds a row, not a test. Tests stay in their feature files.
This compacts the loader tests before 338 and 339 refactor the loaders.

## Acceptance criteria
- [ ] AC1: `tests/lib/test_case.gd` holds `check_loads(rows, load_input)`. Each row is `[label, input, expected]`:
  `load_input.call(input)` returns `{cards, config?, errors, warnings}`, and `expected` maps a dotted path
  (`"cards.x.era"`, `"config.supply"`, `"cards.x.is_permanent()"`) to the value it must equal. A row passes when
  there are no errors and no warnings and every path's value equals the expected one.
- [ ] AC2: Given a fresh test case and a row whose loaded `cards.x.era` is 2 where 1 is expected (or that loads with
  a warning), when `check_loads` runs it, then that test case records a failure naming the row's label and the path
  (or the warning); a missing path is a failure naming the path, not a script error.
- [ ] AC3: The one-off rejection tests become rows of their file's `check_cases` table (or a new table in that file):
  `test_settle_non_city_is_error`, `test_settle_unknown_card_is_error`, `test_explore_reveal_0_is_error`,
  `test_government_effect_needing_a_target_is_a_load_error`, `test_territory_printing_resource_keyword_is_error`,
  `test_unknown_resource_cost_is_still_an_error`, `test_administers_only_applies_to_governments`,
  `test_tolerates_only_applies_to_governments`, `test_an_events_revolt_field_is_unknown`,
  `test_growth_surplus_is_an_unknown_population_field`, `test_unrest_fallback_is_no_longer_read`,
  `test_unrest_relief_is_no_longer_read`, `test_population_start_must_fit_each_listed_home`. Each keeps the fragments
  it asserts today.
- [ ] AC4: Every test whose only job is to check that a card field or config block loads, or what it defaults to, is a
  row of a `check_loads` table in its own file, with the values it checks today. The Log lists each test folded and
  its new row label.
- [ ] AC5: A test file's loader wrapper that adds nothing to `fixture_load` or `config_errors` but fixed arguments
  goes: the table calls the shared helper (a bound `Callable`); a shared `config_load(overrides, sets := [])`
  returning `{cards, config, errors, warnings}` joins `config_errors` in `test_case.gd` for config rows.
- [ ] AC6: Nothing is lost: every folded case runs as a row (the suite's test count drops by the number of tests
  folded, listed in the Log), and every remaining test passes unedited.

## Out of scope
- Moving loader tests between feature files (they stay where their feature is).
- Loader tests that also play the loaded game (they stay tests).
- The int-field table 338 adds for every (field, type) pair (340 leaves those int-field rows to it).

## Design notes
- Count from the review's scan: 121 loader-touching tests outside `check_cases`; 16 one-off rejections (AC3 lists the
  13 that are pure loader checks; `test_sim_run_files_reports_loader_errors`, `test_the_famine_card_is_never_in_…` and
  `test_an_upgrade_is_never_in_the_deck_…` check more than a message and stay); ~60 "loads / defaults / normalized /
  optional / cleanly" tests, mostly in `test_events`, `test_research`, `test_population`, `test_tech_eras`,
  `test_supply`, `test_data_loader`, `test_civ_home`, `test_gain_actions`, `test_government`.
- 48 per-file loader wrappers in 44 files today (`load_x` ×2, `load_action` ×3, `card_errors` ×2, `unit_load`,
  `tier_load`, …). Wrappers that add fixtures (a set, a resource list, extra cards) may stay; AC5 removes only the
  ones that are a renamed call.
- Paths in `expected`: a segment ending in `()` calls a method with no arguments; anything else is a key or property.
- Before 338 (compact the tests that cover the loaders before refactoring them); after 334 (shared helpers).

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_shared_helpers::test_check_loads_passes_a_clean_row_whose_paths_match`, `test_check_loads_indexes_arrays_and_int_keys_and_calls_builtin_methods` |
| AC2 | `test_shared_helpers::test_check_loads_names_the_row_and_path_of_a_wrong_value`, `test_check_loads_fails_a_row_that_loads_with_a_warning_or_an_error`, `test_check_loads_a_missing_path_is_a_failure_naming_the_path` |
| AC3 | `test_shared_helpers::test_the_one_off_loader_rejections_are_table_rows` |
| AC4, AC6 | The folded tests' rows (listed in the Log); the suite's count |
| AC5 | `test_shared_helpers::test_config_load_returns_cards_config_errors_and_warnings` |

## Log
- 2026-10-06: specced from the project review; the user chose to keep tables in the feature files and to table the
  positive load tests too.
