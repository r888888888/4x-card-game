---
id: 336
title: The engine says what a forecast reads, so the bot's forecast cache can't go stale
type: feature
status: done
branch: feat/336-forecast-reads
---

## Goal
The generic bot caches `turn_forecast` by a key of everything the forecast reads (315), but that list is kept by hand
in `sim/generic_bot.gd`: `forecast_key` names `GameState` and `CardInstance` fields one by one, `FORECAST_ZONES` lists
the zones, and `_forecast_zones` hard-codes `effect.op == "gain_per_tag"` as the only op that reads another zone. A
new upkeep op that counts a zone, or a new state field upkeep reads, would make the bot reuse wrong forecasts, caught
only by the check-mode test on one fixture game. What the forecast reads becomes engine knowledge, and the suite fails
when a new field isn't classified.

## Acceptance criteria
- [x] AC1: `Effect.reads_zones()` returns the zones an effect counts cards in when it resolves; `[]` by default.
  `gain_per_tag` with `"zone": "discard"` returns `["discard"]`; `create` into the discard returns `[]`; every other
  op returns `[]`.
- [x] AC2: The engine exposes the zones `turn_forecast` reads for a card db (`TurnLoop`'s fixed zones plus every
  effect's `reads_zones()`); the bot's key uses it and no longer names an op. The existing cache tests pass unedited
  (Tally's discard is in the key, Scribe's isn't).
- [x] AC3: Given `GameState` and `CardInstance`, when the suite runs, then a test fails naming any script variable that
  is neither read by the forecast key nor listed, with a reason, as one the forecast doesn't read (the way `copy()`
  is checked, `script_vars`).
- [x] AC4: Behaviour is pinned: the generic bot plays the same games (`scripts/sim.sh 20` output identical before and
  after), and check mode reports 0 mismatches on the cache tests' games.
- [x] AC5: The `add-effect` skill has a step: an op that counts a zone's cards overrides `reads_zones()`.

## Out of scope
- Caching anything other than `turn_forecast`.
- Making the bot faster.

## Design notes
- New engine API: `Effect.reads_zones() -> Array[String]`; a query such as `forecast_zones() -> Array[String]` on the
  engine (or a static on `TurnLoop`) holding today's `FORECAST_ZONES` (`tableau`, `researched`, `civilization`,
  `government`, `active_events`) beside `TurnLoop.forecast`.
- The key reads today: turn, is_over, bonus_score, era, revolt_pending, anarchy_turn, anarchy_limit, last_raid_turn,
  resources; per card uid, id, territory_uid, station_uid, pop, turns_left, counters, progress, given_this_turn. AC3
  forces a decision on the rest; look hard at `eras_added` (era unlocks read it) and `base_uid` before listing them as
  unread.
- After 335 (the cache tests are compacted first).

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_turn_forecast::test_a_gain_per_tag_reads_the_zone_it_counts`, `test_a_create_into_the_discard_reads_no_zone`, `test_every_other_op_reads_no_zone` |
| AC2 | `test_turn_forecast::test_the_forecast_reads_the_board_plus_the_zones_effects_count`, `test_generic_bot_cache::test_the_key_uses_the_engines_forecast_zones_and_names_no_op`; the cache tests unedited |
| AC3 | `test_generic_bot_cache::test_every_game_state_field_is_in_the_key_or_listed_as_unread`, `test_every_card_instance_field_is_in_the_key_or_listed_as_unread`, `test_the_key_reads_every_field_its_lists_name`, `test_positions_differing_in_eras_added_keywords_or_base_have_different_keys` |
| AC4 | `scripts/sim.sh 20` before/after (Log); `test_every_cached_forecast_equals_a_fresh_one` |
| AC5 | the add-effect skill (doc) |

## Log
- 2026-10-06: specced from the project review; the user chose an engine hook plus a field check.
- 2026-10-06: built. Engine: `Effect.reads_zones()` (gain_per_tag returns its zone), `TurnLoop.FORECAST_ZONES` and
  `forecast_zones(e)`, the engine query `forecast_zones()`. Bot: `KEY_STATE_FIELDS` / `KEY_CARD_FIELDS` and
  `UNREAD_STATE_FIELDS` / `UNREAD_CARD_FIELDS` (each with a reason); the key gained `eras_added`, `keywords` and
  `base_uid`, which the check found it missed (era unlocks, keyword effects and raid aims, a pillage's fallback read
  them), flattened into the key so it holds no live array. `reads_zones()` reports only zones beyond the board for
  the counting ops (gain_per_keyword, lose_per_keyword, trade count the tableau, which every forecast reads).
- AC4: `scripts/sim.sh 20` (360 games, uncached) on main and on this branch: the reports are identical line for line
  (progress lines aside); both runs ~70 min. Check mode: 0 mismatches on the cache tests' games.
