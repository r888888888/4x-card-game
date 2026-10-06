---
id: 336
title: The engine says what a forecast reads, so the bot's forecast cache can't go stale
type: feature
status: draft
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
- [ ] AC1: `Effect.reads_zones()` returns the zones an effect counts cards in when it resolves; `[]` by default.
  `gain_per_tag` with `"zone": "discard"` returns `["discard"]`; `create` into the discard returns `[]`; every other
  op returns `[]`.
- [ ] AC2: The engine exposes the zones `turn_forecast` reads for a card db (`TurnLoop`'s fixed zones plus every
  effect's `reads_zones()`); the bot's key uses it and no longer names an op. The existing cache tests pass unedited
  (Tally's discard is in the key, Scribe's isn't).
- [ ] AC3: Given `GameState` and `CardInstance`, when the suite runs, then a test fails naming any script variable that
  is neither read by the forecast key nor listed, with a reason, as one the forecast doesn't read (the way `copy()`
  is checked, `script_vars`).
- [ ] AC4: Behaviour is pinned: the generic bot plays the same games (`scripts/sim.sh 20` output identical before and
  after), and check mode reports 0 mismatches on the cache tests' games.
- [ ] AC5: The `add-effect` skill has a step: an op that counts a zone's cards overrides `reads_zones()`.

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

## Log
- 2026-10-06: specced from the project review; the user chose an engine hook plus a field check.
