---
id: 046
title: Table-driven loader validation tests
type: feature
status: done
branch: feat/046-table-driven-loader-tests
---

## Goal
About 90 loader validation tests, spread over 12 files, each check one bad field with the same few lines.
Grouping them into case tables per config block or card field makes the loader refactor (047) cheaper to guard,
and adding a field means adding a row, not a test.

## Acceptance criteria
- [x] AC1: For each of `supply`, `era_unlocks`, `population`, `territory_resources`, `research_deck`,
  `territory_deck`, `hand_limit`, territory card fields, tech card fields and `prereq`, the validation cases are
  one test that loops over rows `[label, input, expected message fragment]` and asserts each row with its label in
  the failure message.
- [x] AC2: Every error and warning fragment asserted before this item is still asserted; the Log lists the
  fragment count before and after (they must be equal).
- [x] AC3: The tests stay in their feature files (no single giant loader test file). Tests of valid input
  loading and normalizing stay as separate named tests.
- [x] AC4: The loader validation test count drops from about 90 to 35 or fewer, and the suite is green.

## Out of scope
- Changing any loader message or rule.

## Design notes
- Uses the `config_errors` / `card_errors` helpers from 041.
- A table row that fails reports `file::test: <label>: …` so a failure is still easy to find.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_supply_validation`, `test_era_unlocks_validation`, `test_population_block_validation` (+ `test_housing_validation`), `test_resource_config_validation`, `test_research_deck_validation`, `test_territory_deck_and_starting_territory_validation`, `test_hand_limit_validation`, `test_territory_card_validation`, `test_tech_card_validation` (+ `test_era_and_research_field_validation`), `test_prereq_validation`; also `test_card_validation` (data_loader), `test_grow_validation`, `test_keyword_validation` |
| AC2 | runtime fragment record (Log) |
| AC3 | tables live in their feature files; valid-input tests unchanged |
| AC4 | count in Log; suite green |

## Log

- 2026-09-29: Approved by the user ("do 046"). Test-only change, so no red checkpoint; proof is the fragment record.
- New helper `check_cases(cases, load)` in `tests/lib/test_case.gd`: rows `[label, input, fragment(s), kind]`,
  kind `errors` (default), `one_error` (kept the "exactly one error" checks of the territory tests), `warnings`,
  `warning_only` (kept the "and no errors" checks of the warning tests). Failures read `file::test: <label>: …`.
- AC2: every fragment passed to `has_message` was recorded while the suite ran (temporary instrumentation, not
  committed): before 112 checks / 83 distinct fragments, after 112 / 83, identical sets.
- AC4: tests that assert loader messages (has_msg / has_message / check_cases, excluding settings and sim):
  80 on main → 22. Suite 381 → 325 tests, green. Extra: data_loader, grow and keyword cases were tabled too.
- Kept as separate tests: valid loading and normalizing, `test_prereq_on_a_card_that_is_not_a_tech_is_ignored`
  (was an extra assertion inside a warning test), `test_population_start_equal_to_starting_housing_loads` (same),
  JSON syntax, config unknown deck card, territory printing a resource keyword (different loaders).
- One check got stricter: "research amount" must now be a *warning* (it was `errors + warnings`); it is one.
- Mutation check: a wrong fragment in one supply row failed with the row labels "price 0" and "no price".
