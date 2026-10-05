---
id: 292
title: Cache each sim game's result by the code and data that produced it
type: feature
status: done
branch: feat/292-sim-result-cache
---

## Goal
Never play the same game twice. The balance skill re-runs `main` every time, though `main` rarely changed since the
last run. A sim game is deterministic: the same engine, bot and data, seed, strategy, civ and turn limit always give
the same metrics. So each game's metrics are cached under a key built from all of those, and a later run with the same
key reads them instead of playing. The cache is shared by every checkout and worktree, so a fresh `main` worktree
reuses what the main checkout played.

## Acceptance criteria
- [x] AC1: Given an empty cache directory, when `run_files` runs seeds 1–2 of `baseline` (`--civ sumer`, `--turns 4`),
  then the result has `played` 2 and `cached` 0. When it runs again, it has `played` 0 and `cached` 2, and the report
  lines are identical except the header's cache count.
- [x] AC2: Given those 2 cached games, when the run changes any part of the key (`--turns 5`, `--civ greece`,
  `wealth`, or seed 3), then the changed games are played (`played` 2, or 1 for seeds 1–3), not read.
- [x] AC3: Given those 2 cached games, when the run uses a copy of `config.json` with one value changed (its path in
  the `config` option), then both games are played again. A byte-identical copy at another path reads both from the
  cache: the key hashes the data's contents, not its path.
- [x] AC4: `SimStats.source_hash(root)` hashes every `.gd` file under `root`'s `engine/`, `sim/` and `autoload/`. Given
  two temp trees that are identical, they hash the same. When one line of one `.gd` file changes, they differ. When a
  file outside those folders or a `.uid` file changes, they still hash the same.
- [x] AC5: Given half the jobs of a 4-game run cached (seeds 1–2 of 4), when it runs on `procs` 2, then only seeds 3–4
  go to the workers and the report equals an uncached `procs` 1 run. Given all 4 cached, it starts no child process.
- [x] AC6: Given a cache entry that isn't valid JSON, or lacks a metric the run reports, then that game is played
  again, the entry is overwritten, and the run succeeds. Given the `cache` option false (`SIM_CACHE=0`), then every
  game is played and nothing is written to the cache.

## Out of scope
- Eviction. An entry is about 1 KB, so a full run is about 0.6 MB per code version. Clear it by hand
  (`rm -rf` the folder named in the skill) if it ever matters.
- The main-vs-branch comparison (293).

## Design notes
- **Location.** `user://sim-cache/<source hash>-<data hash>/<strategy>-<civ or default>-<seed>-<turns>.json`, holding
  `{metric: int}`. `user://` is shared by every checkout of this project, and the tests isolate it per shard
  (`scripts/test.sh` gives each shard its own HOME, 223). `run_files` takes `cache_dir` so a test can point at a temp
  directory. `SIM_CACHE=0` in `sim/run.gd` sets `cache: false`.
- **Key.** `source_hash` is a SHA-256 over the sorted relative paths and contents of the `.gd` files in `engine/`,
  `sim/` and `autoload/`, plus `Engine.get_version_info().string`. The data hash covers the cards and config files'
  bytes. The turn limit is the one actually played: the `--turns` option, or the config's.
- The parent computes the hash once and checks the cache before handing out jobs. Workers (291's queue) see only
  uncached jobs, and the parent writes each result back. Workers never touch the cache, so there are no write races
  between them. Two separate runs can write the same entry with identical contents, which is harmless (write to a
  temp name, then rename).
- Header line: `20 seeds (1-20), 450 of 600 games cached` (just `20 seeds (1-20)` when none are cached, so existing
  report tests hold).
- The result gains `played` and `cached`.
- Builds on 291 (the queue); works with `procs` 1 too.
- Update the balance skill: running `main` again is nearly free once cached.

## Test plan
| AC | Test |
|---|---|
| AC1 | `balance/test_sim_cache_runs::test_a_second_run_reads_every_game_from_the_cache` |
| AC2 | `balance/test_sim_cache_runs::test_a_different_turn_limit_civ_strategy_or_seed_misses` |
| AC3 | `balance/test_sim_cache_runs::test_changed_data_misses_and_a_byte_identical_copy_hits` |
| AC4 | `test_sim_cache::test_identical_trees_hash_the_same`, `…::test_a_changed_line_in_the_game_code_changes_the_hash`, `…::test_a_new_script_changes_the_hash`, `…::test_other_files_leave_the_hash_alone` |
| AC5 | `balance/test_sim_cache_runs::test_a_parallel_run_plays_only_the_uncached_games` |
| AC6 | `balance/test_sim_cache_runs::test_a_bad_cache_entry_is_played_again_and_overwritten`, `…::test_with_the_cache_off_every_game_is_played_and_nothing_written` |

## Manual check
- [ ] `scripts/sim.sh 20` twice: the second run says `600 of 600 games cached` and takes a few seconds.
- [ ] Make a balance worktree of `main` (as the balance skill does) after the main checkout ran: its run is cached too.

## Log
- 2026-10-05: specced from the sim-CPU discussion. User chose: one cache shared by all checkouts.
- 2026-10-05: built on 291's branch (it needs the queue).
  - **Cache only when asked.** The cache is on only when `run_files` gets a `cache_dir`. `sim/run.gd` passes
    `user://sim-cache`, so existing tests never see cache state.
  - **Folder layout.** Folders are `<cache_dir>/<code hash 16>-<data hash 16>/turns-<n>/<strategy>-<civ>-<seed>.json`.
  - **Parallel runs.** A parallel run claims the cached games up front, so its workers only see the rest.
    `read_workers` gained `expected` (the jobs it must find).
  - **Bad entries.** These are read with a `JSON` instance: `JSON.parse_string` logs an engine error on a bad entry.
  - `remove_tree` moved into `tests/lib/test_case.gd` (three test files had it).
- Verified: `SIM_CACHE=0 scripts/sim.sh 3 wealth --civ greece --turns 30` prints exactly what `main` prints. Run
  twice with the cache: the second says `3 of 3 games cached` (0.4 s).
- Suite 1860 → 1864 tests; balance suite 17 → 23.
