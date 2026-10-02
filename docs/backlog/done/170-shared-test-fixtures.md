---
id: 170
title: Shared test fixtures, and engines typed GameEngine in tests
type: feature
status: done
branch: feat/170-shared-test-fixtures
---

## Goal
Tests build their card sets and engines through a few shared helpers with one meaning each, so later items (171 on,
and the military items) add tests without copying a loader or an engine builder. From the 2026-10-01 project review.

## Acceptance criteria
- [x] AC1: `tests/lib/test_case.gd` has `fixture_db(extra := [], sets := [])`: `TEST_CARDS` plus the fixture sets
  given (`TEST_GOVS`, `TEST_CIVS`, …) plus `extra`, parsed, failing the test on a load error. The nine per-file
  `load_cards` helpers (test_actions, test_card_text, test_discounts, test_hand_size, test_gain_actions,
  test_housing_modifier, test_modifiers, test_unrest, test_territory_resources) are gone or call it; the review scan's
  duplicate-helper list no longer shows `load_cards`.
- [x] AC2: No helper name means two things. The per-file `config_errors` (taking a raw config in `anarchy_case.gd`,
  overrides in test_research, a population block in test_famine, …) are renamed after what they take or replaced by
  `config_errors_for`; at most one `config_errors` remains.
- [x] AC3: Engine builders that build the same game in several files (`explore_engine` ×4, `era_engine` ×3, `game_as`
  ×3, …) move to the lib; same-named builders that build different games get different names.
- [x] AC4: `tech_case.tech_engine` and the `test_case.gd` helpers take and return `GameEngine`, not `Object`; outside a
  red phase no test holds an engine as `Object` (the scan's count from 169 is 0).
- [x] AC5: Behavior is pinned: the suite has the same tests, each with the same assertions (the diff changes only
  helper calls, helper names and types), it is green, and `docs/testing.md`'s helper table lists the new helpers.

## Out of scope
- Merging test files (the modifier tests stay per item: test_modifiers, test_hand_size, test_housing_modifier,
  test_gain_actions).

## Design notes
- Test-only refactor: no engine change. The suite is about 1075 tests in 40 s, so this is about upkeep, not speed.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| all | None new: a test-only refactor. Pinned by the suite (1075 tests, same names, same assertion count per test, green) and the review scan (no `load_cards` or engine builder in the duplicate list, 0 files holding an engine as `Object`) |

## Log
- 2026-10-01: Specced from the project review.
- 2026-10-01: Built on top of 169's branch. New in `test_case.gd`: `fixture_load` (loader result, for validation
  tests; `load_with` folded into it), `fixture_db`, `cards_of`, `config_errors(overrides, sets, deck)`,
  `explore_engine`, `over_engine`, `card_with`, `set_home_pop`, `capital_land`, `with_game`, `with_territories_main`.
  `civ_db`, `gov_db`, `event_db`, `tech_db` and `anarchy_db` go through `fixture_load`. Renamed where the same name
  built different games: `game_as` → `discount_game` / `housing_game` / `hand_size_game`, `era_engine` (tech eras)
  vs `event_era_engine` / `era_unlocks_engine`, `explore_engine` (test_explore's unplayed one) → `explorer_engine`,
  test_pending's → `pending_explore_engine` / `pending_discard_engine`, test_action_errors' → `action_explore_engine`,
  `insight_engine` (test_insight) → `civ_insight_engine`, `home_engine` (famine guard) → `guard_engine`,
  `frontier_engine` (population) → `pioneer_engine`, `pop_engine` (harmful ops) → `lose_pop_engine`, `engine_with`
  (gain_per_keyword) → `gold_engine`, `with_fixture_main` → `with_farm_main` / `with_token_main`. test_card_text's
  `load_cards` loads a different set (a City and more keywords, no TEST_CARDS) and is now `text_db`. The per-file
  `config_errors` became `home_config_errors`, `population_errors`, `relief_errors`, `gold_config_errors` and
  anarchy_case's `raw_config_errors`.
- Small helpers still share names across files with different meanings (`load_x` ×5, `card_messages`, `card_errors`,
  `load_config`, `play_x`): loader and play helpers, not engine builders, so left for now.
