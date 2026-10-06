---
id: 335
title: Shorten the suite's critical path: fewer bot games in the cache tests, slow files dealt first
type: chore
status: review
branch: feat/335-suite-critical-path
---

## Goal
The suite takes ~10 s wall clock, and one file sets that: `test_generic_bot_cache.gd` plays 10 full 10-turn bot games
(~5 s alone), and round-robin sharding can put it with other slow files (`test_sim_anarchy` ~2.6 s,
`test_knowledge_screen` ~2.8 s). Its tests also repeat themselves: `test_positions_that_differ_only_in_the_hand_share_one_forecast`
inlines `lookups_for_a_discard`. This comes before 336, which changes the code these tests cover.

## Acceptance criteria
- [x] AC1: `test_generic_bot_cache.gd` plays each distinct fixture game (seed, strategy, cache on or off) at most once
  per run, sharing the results between tests; `test_the_cache_computes_fewer_forecasts_than_it_looks_up` and
  `test_without_the_cache_every_lookup_is_computed` read the counts recorded by those shared games. Every test keeps its
  name and its assertions.
- [x] AC2: `test_positions_that_differ_only_in_the_hand_share_one_forecast` uses `lookups_for_a_discard`.
- [x] AC3: Given shard files with costs (a list of slow files in `tests/lib/test_shards.gd`, slowest first), when files
  are dealt to n shards, then the slow files are dealt first, one per shard in turn, then the rest round-robin: with
  slow files [a, b] and others [c, d, e] over 2 shards, shard 0 gets [a, c, e] and shard 1 gets [b, d].
- [x] AC4: Every shard still runs every file exactly once (no file lost or doubled for 1 to 12 shards), and the test
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
| AC1 | `test_generic_bot_cache::test_the_shared_games_are_played_once_per_run`; the file's other tests keep their names and assertions |
| AC2 | refactor (no new test) |
| AC3 | `test_test_runner::test_slow_files_are_dealt_first_one_per_shard_then_the_rest_round_robin`, `test_slow_files_match_by_file_name_and_a_missing_one_is_skipped`, `test_the_slow_list_names_test_files_that_exist`, `test_the_runner_deals_the_slow_files_first` |
| AC4 | `test_test_runner::test_every_file_runs_exactly_once_for_1_to_12_shards`; the count grows only by these 6 tests |

## Manual check
- [ ] `scripts/test.sh` wall time is lower than before (figures in the Log).

## Log
- 2026-10-06: specced from the project review (per-file timings: generic_bot_cache 7.8 s, sim_anarchy 5.4 s,
  knowledge_screen 5.6 s, a light file 2.8 s, Godot start included).
- 2026-10-06: before, on main at 198bea5 (12-core Mac, other sessions idle): `scripts/test.sh` 11.1 s and 11.9 s
  (2193 tests); `TEST_JOBS=1 scripts/test.sh test_generic_bot_cache` 8.8 s. Per file, 4 at a time with Godot's start:
  generic_bot_cache 9.4 s, knowledge_screen 7.5 s, sim_anarchy 6.9 s, ui_smoke 5.6 s, start_screen 5.6 s, the rest ≤ 5.4 s.
- After (12-core Mac, the same load, runs interleaved with a checkout of main): `scripts/test.sh` main 11.7 / 12.2 /
  11.9 s, 335 11.7 / 11.1 / 11.1 s (≈ 0.6 s, 5% faster; 2199 tests); `TEST_JOBS=1 scripts/test.sh test_generic_bot_cache`
  8.8 → 7.2 s; serial suite 40 s. CLAUDE.md and docs/testing.md say ~11 s (the ~10 s figure was from an idler machine).
- The cache file plays 6 games, not 5: `test_a_game_plays_the_same_after_another_as_alone` needs seed 2 twice (alone
  and after seed 1), so the memo plays them in a fixed order; generic's cache-on game runs in check mode, which changes
  only the check counts, so `test_every_cached_forecast_equals_a_fresh_one` needs no game of its own.
- `TestShards.SLOW` is a fixed list (generic_bot_cache, knowledge_screen, sim_anarchy, ui_smoke, start_screen); it
  goes stale as files grow. Timing-based sharding stays out of scope.
