---
id: 170
title: Shared test fixtures, and engines typed GameEngine in tests
type: feature
status: ready
branch: feat/170-shared-test-fixtures
---

## Goal
Tests build their card sets and engines through a few shared helpers with one meaning each, so later items (171 on,
and the military items) add tests without copying a loader or an engine builder. From the 2026-10-01 project review.

## Acceptance criteria
- [ ] AC1: `tests/lib/test_case.gd` has `fixture_db(extra := [], sets := [])`: `TEST_CARDS` plus the fixture sets
  given (`TEST_GOVS`, `TEST_CIVS`, …) plus `extra`, parsed, failing the test on a load error. The nine per-file
  `load_cards` helpers (test_actions, test_card_text, test_discounts, test_hand_size, test_gain_actions,
  test_housing_modifier, test_modifiers, test_unrest, test_territory_resources) are gone or call it; the review scan's
  duplicate-helper list no longer shows `load_cards`.
- [ ] AC2: No helper name means two things. The per-file `config_errors` (taking a raw config in `anarchy_case.gd`,
  overrides in test_research, a population block in test_famine, …) are renamed after what they take or replaced by
  `config_errors_for`; at most one `config_errors` remains.
- [ ] AC3: Engine builders that build the same game in several files (`explore_engine` ×4, `era_engine` ×3, `game_as`
  ×3, …) move to the lib; same-named builders that build different games get different names.
- [ ] AC4: `tech_case.tech_engine` and the `test_case.gd` helpers take and return `GameEngine`, not `Object`; outside a
  red phase no test holds an engine as `Object` (the scan's count from 169 is 0).
- [ ] AC5: Behavior is pinned: the suite has the same tests, each with the same assertions (the diff changes only
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

## Log
- 2026-10-01: Specced from the project review.
