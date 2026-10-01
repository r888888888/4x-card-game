---
id: 029
title: Unlock tech eras by reaching a pop or wealth threshold
type: feature
status: done
branch: feat/029-era-thresholds
---

## Goal
Give players a second road to the next era besides researching an era tech (Philosophy) or emptying
the research deck. A growing or rich civilization advances on its own: when the player reaches a set
total pop **or** wealth on hand at the start of a turn, that era's techs join the research deck. The
wealth is only checked, not spent. Depends on 027.

## Acceptance criteria
Fixtures: the 027 era cards (era-2 techs Optics and Astronomy waiting in `future_techs`), population on
(`start: 2`), Capital ⟳ +2 food (no wealth), starting wealth set per test.

- [x] AC1 (config): `era_unlocks` is optional (default {}), shaped like
  `{"2": {"pop": 8, "wealth": 15}}`. Each key is an era as an integer string ≥ 2. Each value is an
  object with `pop` and/or `wealth`, integers ≥ 1. These are load errors that name config.json and
  `era_unlocks`:
  - a key like "1", "0" or "two"
  - a value that isn't an object, or an empty object
  - a threshold below 1 or not an integer

  An unknown field inside a value (e.g. `"food"`) is a warning.
- [x] AC2 (pop threshold): With `era_unlocks: {"2": {"pop": 4}}`, total pop 4 and enough food so no pop
  starves, ending the turn starts turn 2 with `era()` 2, and Optics and Astronomy in the research deck
  (`future_techs` empty). With total pop 3, `era()` stays 1.
- [x] AC3 (wealth threshold, not spent): With `era_unlocks: {"2": {"wealth": 15}}` and 15 wealth at the
  start of a turn, era 2 is added and wealth is still 15. With 14 wealth, `era()` stays 1.
- [x] AC4 (either is enough): With `era_unlocks: {"2": {"pop": 99, "wealth": 15}}` and 15 wealth, era 2
  is added.
- [x] AC5 (checked at the start of the turn only):
  - The check runs at the start of every turn, turn 1 included: a game starting with 20 wealth and
    `{"2": {"wealth": 15}}` begins turn 1 in era 2.
  - Reaching the threshold during a turn (for example wealth raised to 15 mid-turn) doesn't add the era
    until the next turn starts.
  - The check comes after upkeep and pop eating. Food and wealth gained at upkeep count; pop that
    starves doesn't.
- [x] AC6 (once per era): An era already added by `add_era` (e.g. Philosophy bought) or by an empty
  research deck isn't added again when its threshold is met: the research deck size is unchanged.
  Meeting the threshold on later turns changes nothing.
- [x] AC7 (real data): `data/config.json` sets `era_unlocks` for era 2 (first numbers: 8 pop or 15
  wealth, for playtesting). The real data still loads with no errors or warnings.

## Out of scope
- Paying wealth to advance an era.
- Conditions other than total pop and wealth held (cities, techs researched, turn number).
- Balancing the thresholds (playtesting).
- Checking right away, mid-turn.

## Design notes
- Config: `era_unlocks` {era string: {pop?, wealth?}}, normalized to {int: {pop?, wealth?}}.
- Engine: at the end of `_start_turn`'s upkeep (after `_feed_pop`, before the draw), each era in
  `era_unlocks` whose threshold is met calls `add_era(n)`. `add_era` already ignores an era added
  before. Eras are checked in ascending order.
- The pop threshold uses `total_pop()`. With population off, total pop is 0, so only `wealth` can
  trigger.
- An era with a threshold but no techs still counts as added (`era()` rises). This is harmless.
- Engine API: `era_unlocks() -> Dictionary` (the normalized config), so the UI can show the condition
  without its own rules.
- UI: the Research button's tooltip (or a line under it) shows "Era 2 at 8 pop or 15 wealth" while that
  era hasn't been added.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_tech_eras::test_era_unlocks_is_normalized`, `test_era_unlocks_defaults_to_empty`, `test_era_unlocks_bad_era_keys_are_errors`, `test_era_unlocks_bad_values_are_errors`, `test_era_unlocks_unknown_field_is_a_warning`, `test_era_unlocks_query_returns_the_config` |
| AC2 | `test_reaching_the_pop_threshold_adds_the_era`, `test_below_the_pop_threshold_nothing_happens` (passes now: guard) |
| AC3 | `test_reaching_the_wealth_threshold_adds_the_era_without_spending`, `test_below_the_wealth_threshold_nothing_happens` (guard) |
| AC4 | `test_either_threshold_is_enough` |
| AC5 | `test_the_threshold_is_checked_at_the_start_of_turn_1`, `test_reaching_the_threshold_mid_turn_waits_for_the_next_turn`, `test_upkeep_gains_count_toward_the_threshold`, `test_pop_that_starves_does_not_count` (guard) |
| AC6 | `test_an_era_added_by_a_tech_is_not_added_again`, `test_an_era_added_by_an_empty_deck_is_not_added_again` (both guards) |
| AC7 | `test_content::test_real_config_sets_an_era_2_threshold`, `test_real_data_loads_without_warnings` (existing) |

## Manual check
- [ ] The Research button tooltip shows the next era's condition, and it disappears once the era is added.
- [ ] Growing to 8 pop (or saving 15 wealth) adds era 2 at the start of the next turn; the log says so.

## Log
- Suite: 296 → 314 tests. Five tests were guards that passed before the change (below-threshold, starvation, once per era).
- UI: the Research button tooltip lists "Era 2 at 8 pop or 15 wealth (checked at the start of a turn)" until era 2 arrives.
- The first tooltip commit had a parse error in `main.gd` (`PackedStringArray.filter` doesn't exist); the test
  suite doesn't load UI scripts, so only the headless drive caught it. Fixed in the next commit.
- The 028 bot numbers already reached era 2 in 20/20 seeds via Philosophy, so the thresholds mostly matter for players who skip it.
