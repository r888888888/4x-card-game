---
id: 335
title: Shorten the suite's critical path: fewer bot games in the cache tests, slow files dealt first
type: chore
status: draft
branch: feat/335-suite-critical-path
---

## Goal
The suite takes ~10 s wall clock, and one file sets that: `test_generic_bot_cache.gd` plays 10 full 10-turn bot games
(~5 s alone), and round-robin sharding can put it with other slow files (`test_sim_anarchy` ~2.6 s,
`test_knowledge_screen` ~2.8 s). Its tests also repeat themselves: `test_positions_that_differ_only_in_the_hand_share_one_forecast`
inlines `lookups_for_a_discard`. This comes before 336, which changes the code these tests cover.

## Acceptance criteria
- [ ] AC1: `test_generic_bot_cache.gd` plays each distinct fixture game (seed, strategy, cache on or off) at most once
  per run, sharing the results between tests; `test_the_cache_computes_fewer_forecasts_than_it_looks_up` and
  `test_without_the_cache_every_lookup_is_computed` read the counts recorded by those shared games. Every test keeps its
  name and its assertions.
- [ ] AC2: `test_positions_that_differ_only_in_the_hand_share_one_forecast` uses `lookups_for_a_discard`.
- [ ] AC3: Given shard files with costs (a list of slow files in `tests/lib/test_shards.gd`, slowest first), when files
  are dealt to n shards, then the slow files are dealt first, one per shard in turn, then the rest round-robin: with
  slow files [a, b] and others [c, d, e] over 2 shards, shard 0 gets [a, c, e] and shard 1 gets [b, d].
- [ ] AC4: Every shard still runs every file exactly once (no file lost or doubled for 1 to 12 shards), and the test
  count is unchanged.

## Out of scope
- Making the bot or the engine faster.
- Timing-based sharding from recorded runs.

## Design notes
- Sharding: order the file list with the slow files first, then `TestShards.pick` deals it unchanged (its existing
  tests stay green).
- Shared games: a file-level memo keyed by (seed, strategy, cache_on), recording `[score, zones, log]` and the bot's
  counters after each game.
- Measure wall time before and after (`scripts/test.sh`, `TEST_JOBS=1 scripts/test.sh test_generic_bot_cache`) and note
  both in the Log; update CLAUDE.md and `docs/testing.md`'s figures.

## Test plan
| AC | Test |
|---|---|

## Manual check
- [ ] `scripts/test.sh` wall time is lower than before (figures in the Log).

## Log
- 2026-10-06: specced from the project review (per-file timings: generic_bot_cache 7.8 s, sim_anarchy 5.4 s,
  knowledge_screen 5.6 s, a light file 2.8 s, Godot start included).
