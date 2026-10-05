---
id: 315
title: The generic bot caches forecasts by state, without changing a single decision
type: feature
status: ready
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
| AC1 | `test_generic_bot_cache::test_…` |

## Manual check
- [ ] Seconds per game (mean of `scripts/sim.sh 10 generic`) before and after, in the Log. Target: under 10 s. If
  314's cheap-mode rollouts keep it above, say so in the Log with where the time goes.

## Log
- 2026-10-05: specced from the generic-bot spike, with 309–314. Follows 314.
