---
id: 041
title: Share test helpers and replace exact-number content tests with invariants
type: feature
status: review
branch: feat/041-test-helpers-and-content-invariants
---

## Goal
Test files stop re-defining the same helpers (sometimes with different behavior), tests stop reaching into
private engine members, and the real-data tests stop copying numbers out of `data/*.json`, so a balance
edit no longer means editing a test. Developer-facing only: no game rule changes.

## Acceptance criteria
- [x] AC1: `tests/lib/test_case.gd` provides `uid_of(zone, id)`, `sorted(array)`, `settle(engine, ids)` (moves the
  listed territory copies from `territory_deck` to the tableau), `to_frontier(engine, ids)` and
  `put_in_hand(engine, id) -> uid`. Given the whole `tests/` tree, then no file outside `tests/lib/` defines
  `uid_of`, `sorted`, `arrange`, or its own engine builder that only wraps these.
- [x] AC2: `tests/test_research.gd` extends `tests/lib/tech_case.gd` and uses its `TECHS`, `tech_engine` and
  `arrange` (which keeps unlisted cards below the listed ones). Every test in the file still passes; where a
  test depended on the old 10-wealth start, it passes the wealth explicitly (the assertion itself is unchanged).
- [x] AC3: Given a card id and `null` as the source, when `create_card(id, "hand", null)` is called, then a new copy
  is in the hand and no error is logged. `put_in_hand` uses it, and no test calls an engine member starting with
  `_` (`grep -n '\._[a-z]' tests/` finds nothing).
- [x] AC4: `tests/test_content.gd` no longer asserts exact values from the data. Removed: 
  `test_capital_adds_4_building_slots`, `test_real_research_card_starts_in_the_deck_and_is_sold` (deck size 23,
  supply price), `test_real_supply_sells_scouts`, `test_real_hills_roll_gold_and_iron_is_gone`,
  `test_real_resource_keywords_are_gold_tin_copper`, `test_real_hills_and_highlands_roll_metals`,
  `test_real_forge_scores_on_copper_and_tin`, `test_real_territory_slots_and_housing_follow_the_land`,
  `test_real_floodplain_delta_has_fresh_water_and_others_keep_keywords`, `test_real_config_turns_population_on`,
  `test_real_config_sets_an_era_2_threshold`; and `test_real_config_sets_hand_limit_7` from
  `tests/test_hand_limit.gd`. The invariant tests stay (every keyword used, resource keywords rolled and used,
  supply cards in the deck, prereqs in the research deck, moved cards unlocked by a tech, Library).
- [x] AC5: "Real data has no warnings" is asserted in exactly one test (`test_real_data_loads_without_warnings`),
  and `test_every_wealth_cost_has_a_wealth_source` asserts `eq(unfunded_card_ids, [])` instead of `check(true, …)`.
- [x] AC6: The `grow`, `settle` and `explore` loader tests move from `tests/test_data_loader.gd` to
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
| AC1 | helpers in `tests/lib/test_case.gd`; copies removed from test_explore, test_keywords, test_slots, test_settle, test_research, test_growth_cards (`settled_uid`); builders use `settle` / `to_frontier` / `arrange` |
| AC2 | all of `tests/test_research.gd`, now on `tech_case.gd` (`open_engine` passes 10 wealth) |
| AC3 | `test_rules::test_create_card_without_a_source_puts_a_new_copy_in_the_zone` (+ grep for `._` in tests/) |
| AC4 | removals listed in the Log |
| AC5 | `test_content::test_real_data_loads_without_warnings`, `test_content::test_every_wealth_cost_has_a_wealth_source` |
| AC6 | `test_explore` / `test_settle` / `test_growth_cards` "Loader" sections |

## Log
- 2026-09-29: Approved by the user ("do 041"). Red: `test_create_card_without_a_source_puts_a_new_copy_in_the_zone`
  failed on the null `source` (`game_engine.gd:609`); approved; `create_card` now logs "Created X." without a source.
- Shared helpers: `uid_of`, `sorted`, `arrange` (moved from `tech_case.gd`), `settle`, `to_frontier`, `put_in_hand`.
  `play_research` and two "research deck is empty" tests use `put_in_hand` instead of `_make_card`.
- AC2: `tech_case.gd`'s Writing gained this file's `score 2` effect (the "resolves its play effects" test needs it;
  no other tech test depended on Writing having no effect). `open_engine` passes 10 wealth explicitly for the three
  tests that assert 10/8 wealth.
- Removed tests (AC4), all copying numbers out of `data/` so a balance edit would break them:
  - `test_capital_adds_4_building_slots`: Capital slot count.
  - `test_real_research_card_starts_in_the_deck_and_is_sold`: deck size 23, 1 Research, supply price 3 × 2.
  - `test_real_supply_sells_scouts`: which cards the supply sells.
  - `test_real_hills_roll_gold_and_iron_is_gone`: Hills count, printed keywords, Forge `requires` (036 one-off check).
  - `test_real_resource_keywords_are_gold_tin_copper`: the exact resource keyword list.
  - `test_real_hills_and_highlands_roll_metals`: exact roll tables and weights.
  - `test_real_forge_scores_on_copper_and_tin`: Forge cost, VP and effects.
  - `test_real_territory_slots_and_housing_follow_the_land`: slots/housing per territory (038 numbers).
  - `test_real_floodplain_delta_has_fresh_water_and_others_keep_keywords`: keywords per territory.
  - `test_real_config_turns_population_on`: config has a population block.
  - `test_real_config_sets_an_era_2_threshold`: config has an era 2 threshold.
  - `test_hand_limit::test_real_config_sets_hand_limit_7`: hand limit value.
  The invariant tests stay. `test_real_data_loads` no longer checks warnings (AC5).
- Suite 380 → 381 (red test) → 369 (12 removed); green.
- Follow-ups: `test_research_deck_has_6_techs_in_each_of_eras_1_and_2` still asserts an exact count from the data
  (not in AC4's list); consider an invariant ("every era has at least 2 techs"). `test_rules._uids(zone)` and
  `test_play_outcome.uids(cards)` could share a `uids` helper.
