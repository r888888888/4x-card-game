---
id: 315
title: The generic bot caches forecasts by state, without changing a single decision
type: feature
status: in-progress
branch: feat/315-generic-bot-speed
---

## Goal
The spike's generic bot took about 25 s a game against ScriptedBot's 2 s; a third of that was forecasting the next
turn (one forecast per position valued) and a third measuring card values. A 6-civ, 3-strategy, 20-seed sim run would
take hours. After this, the bot computes each distinct forecast once, and plays exactly the same games, only faster.

## Acceptance criteria
- [ ] AC1: Given a fixture game played to the end by `GenericBot` with the forecast cache on and again with it off
  (same seed and strategy), then both games end with the same score, the same zones (ids in order) and the same log.
- [ ] AC2: In AC1's game, every forecast the cache returned equals a fresh `turn_forecast()` of the same position
  (a check mode compares them at every lookup).
- [ ] AC3: In AC1's game, the cache on computes fewer forecasts than it looks up (a counter on `GenericBot`, reset per
  game): two candidates that differ only in what the forecast doesn't read (a `buy` adds a card to the discard) share
  one forecast.
- [ ] AC4: The cache lives for one call of `best_action` (or one rollout turn) and holds nothing between games: two
  games played one after the other give the same results as each played alone.

## Out of scope
- Changing the value function or the weights. Caching card values (313 keeps them 4 turns already).

## Design notes
- The key is what the forecast reads: each working card in the tableau and always-on zones (uid, territory, pop, idle),
  active events and raids with their targets, resources, turn, era, Anarchy's state and modifiers. If AC1 or AC2 fail
  for a key that misses something, widen the key, never relax the test.
- Spike profile (40 turns, before its own fixes): forecast 113k calls / 52 s; after pruning buys and the extra
  lookahead step: ~200 forecasts and ~30 card values per turn.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_generic_bot_cache::test_the_cache_plays_the_same_game_as_without_it` |
| AC2 | `test_generic_bot_cache::test_every_cached_forecast_equals_a_fresh_one` |
| AC3 | `test_generic_bot_cache::test_the_cache_computes_fewer_forecasts_than_it_looks_up`, `test_positions_that_differ_only_in_the_hand_share_one_forecast`, `test_without_the_cache_every_lookup_is_computed` |
| AC4 | `test_generic_bot_cache::test_a_game_plays_the_same_after_another_as_alone` |

## Manual check
- [ ] Seconds per game (mean of `scripts/sim.sh 10 generic`) before and after, in the Log. Target: under 10 s. If
  314's cheap-mode rollouts keep it above, say so in the Log with where the time goes.

## Log
- 2026-10-05: specced from the generic-bot spike, with 309–314. Follows 314.
- 2026-10-05: worst case found while investigating 318: seed 1 `wide` greece takes 13½ minutes alone (804 s in a
  turn-by-turn probe, 631 s of it on the every-4th-turn revolt rollouts, 772 s after turn 50; the tableau reaches 179
  cards). Per position valued, `legal_actions` grows from 0.5 to 17 ms and `value` from 0.6 to 3.7 ms between turns 10
  and 90. Use it as the slow benchmark beside the 10-seed mean: forecast caching alone may not bring it down.
- Baseline profile (2026-10-05, after 319–321; one 100-turn generic/egypt seed-1 game with timers, machine busy with
  other runs): 67 s in all, 54 s of it in the 43 revolt and government rollouts. Forecasts: 37.8k calls, 37 s (8.5k
  outside rollouts, 29.3k inside); `sample_fork` 31.6k calls, 13 s; `legal_actions` 3.9k calls, 7 s; card values 0.7 s.
  A probe key (turn, resources, score, era, Anarchy and raid state, and each card in the tableau, always-on zones and
  active events with its territory, station, pop, turns left, counters and site progress) costs 0.03 ms against a
  forecast's ~1 ms and repeats for 54% of forecasts: the cache should save about 20 s of the 37, so the game would still
  take ~45 s, above the 10 s target. The rest is forking each candidate and `legal_actions`, mostly inside rollouts.
- Red: the fixture game (10 turns, Kings in the government deck) runs revolt rollouts and revolts. AC3's example uses a
  discard, not a buy: a buy spends wealth, which the forecast reads (Anarchy's drain is a share of the stock), so it
  can't share a forecast. AC4 plays seed 2 alone, then seed 1, then seed 2 again. The cache's members: static
  `forecast_cache` (on by default) and `check_forecasts` switches, `forecast_lookups`, `forecasts_computed`,
  `forecast_checks` and `forecast_mismatches` counters reset by `play()` and `reset_forecast_counts()`.
