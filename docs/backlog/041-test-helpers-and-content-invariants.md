---
id: 041
title: Share test helpers and replace exact-number content tests with invariants
type: feature
status: red-review
branch: feat/041-test-helpers-and-content-invariants
---

## Goal
Test files stop re-defining the same helpers (sometimes with different behavior), tests stop reaching into
private engine members, and the real-data tests stop copying numbers out of `data/*.json`, so a balance
edit no longer means editing a test. Developer-facing only: no game rule changes.

## Acceptance criteria
- [ ] AC1: `tests/lib/test_case.gd` provides `uid_of(zone, id)`, `sorted(array)`, `settle(engine, ids)` (moves the
  listed territory copies from `territory_deck` to the tableau), `to_frontier(engine, ids)` and
  `put_in_hand(engine, id) -> uid`. Given the whole `tests/` tree, then no file outside `tests/lib/` defines
  `uid_of`, `sorted`, `arrange`, or its own engine builder that only wraps these.
- [ ] AC2: `tests/test_research.gd` extends `tests/lib/tech_case.gd` and uses its `TECHS`, `tech_engine` and
  `arrange` (which keeps unlisted cards below the listed ones). Every test in the file still passes; where a
  test depended on the old 10-wealth start, it passes the wealth explicitly (the assertion itself is unchanged).
- [ ] AC3: Given a card id and `null` as the source, when `create_card(id, "hand", null)` is called, then a new copy
  is in the hand and no error is logged. `put_in_hand` uses it, and no test calls an engine member starting with
  `_` (`grep -n '\._[a-z]' tests/` finds nothing).
- [ ] AC4: `tests/test_content.gd` no longer asserts exact values from the data. Removed: 
  `test_capital_adds_4_building_slots`, `test_real_research_card_starts_in_the_deck_and_is_sold` (deck size 23,
  supply price), `test_real_supply_sells_scouts`, `test_real_hills_roll_gold_and_iron_is_gone`,
  `test_real_resource_keywords_are_gold_tin_copper`, `test_real_hills_and_highlands_roll_metals`,
  `test_real_forge_scores_on_copper_and_tin`, `test_real_territory_slots_and_housing_follow_the_land`,
  `test_real_floodplain_delta_has_fresh_water_and_others_keep_keywords`, `test_real_config_turns_population_on`,
  `test_real_config_sets_an_era_2_threshold`; and `test_real_config_sets_hand_limit_7` from
  `tests/test_hand_limit.gd`. The invariant tests stay (every keyword used, resource keywords rolled and used,
  supply cards in the deck, prereqs in the research deck, moved cards unlocked by a tech, Library).
- [ ] AC5: "Real data has no warnings" is asserted in exactly one test (`test_real_data_loads_without_warnings`),
  and `test_every_wealth_cost_has_a_wealth_source` asserts `eq(unfunded_card_ids, [])` instead of `check(true, …)`.
- [ ] AC6: The `grow`, `settle` and `explore` loader tests move from `tests/test_data_loader.gd` to
  `tests/test_growth_cards.gd`, `tests/test_settle.gd` and `tests/test_explore.gd`, unchanged. The full suite is
  green, and the item's Log lists every removed test with the reason.

## Out of scope
- Converting loader validation tests to table-driven tests (a later item).
- Merging the scripted-game tests and moving the bot to `sim/` (042).
- Any rule or data change.

## Design notes
- Changing approved tests is the point of this item: moving, merging and deleting tests is allowed here, but
  no remaining assertion is weakened. Deleted tests are listed in the Log.
- Engine change: `GameEngine.create_card` accepts a `null` source (logs "Created X." without a source name).
  This is the only production change, and it gets a failing test first (AC3).
- Update `docs/testing.md` (helper table, file table) and CLAUDE.md: check `test_case.gd` / `tech_case.gd`
  before writing a helper; content tests assert invariants, never exact numbers from `data/`.
- Update the `spec` skill so content items put exact numbers under review, not in test criteria.

## Test plan
| AC | Test |
|---|---|
| AC1 | |
| AC2 | |
| AC3 | `test_rules::test_create_card_without_a_source_puts_a_new_copy_in_the_zone` (+ grep for `._` in tests/) |
| AC4 | |
| AC5 | |
| AC6 | |

## Log
