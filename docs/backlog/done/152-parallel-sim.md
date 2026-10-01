---
id: 152
title: Run the balance sim on every CPU core
type: feature
status: done
branch: feat/152-parallel-sim
---

## Goal
Faster balance iteration. `scripts/sim.sh 20` plays 600 games (5 strategies × 6 civilizations × 20 seeds) in one
process: about 7 minutes on `main` after 143, and the balance skill runs it twice. The games are independent, so
`spike/sim-speed` split them over one child Godot process per core and merged the results: 12 cores took a 4-seed
run from 24s to 5s, with byte-identical output. (Threads in one process were slower than one process: the engine
contends on shared objects.)

## Acceptance criteria
- [x] AC1: Given seeds 1–3 with `--turns 5`, when `run_files` runs with strategy "all" and `procs` 1, 2 and 4, then
  the three reports are identical line for line (same numbers, same metric order, era metrics included).
- [x] AC2: Given a single strategy (`baseline`, `--civ sumer`, 2 seeds, `--turns 4`), when it runs with `procs` 2, then
  the report equals the one with `procs` 1.
- [x] AC3: Given more processes than games (3 games, `procs` 8), then it runs and the report equals `procs` 1.
- [x] AC4: Given `run_files` called with no `procs` option (as every existing test does), then it plays every game in
  its own process and starts no child process.
- [x] AC5: Given a child process that writes no results (it failed), when the run finishes, then `run_files` returns
  code 1 and a line naming the shard ("shard 2 of 4 wrote no results"), instead of a partial report or a hang.
- [x] AC6: After a run, with or without a failed shard, the temporary results directory is removed.

## Out of scope
- Caching `main`'s results between balance runs, and reporting standard error to stop at fewer seeds (both possible
  follow-ups from the spike).
- Parallel test runs.

## Design notes
- `run_files` gains an option `procs` (default 1). `sim/run.gd` sets it from `SIM_PROCS`, else
  `OS.get_processor_count()`; `scripts/sim.sh` needs no change. `SIM_PROCS=1` keeps the single-process run.
- Every game becomes a job `[seed, strategy, civ]` in a fixed order (strategy, civ, seed). Job i goes to child
  i % procs (round-robin, so the slower strategies spread out). A child is the same `res://sim/run.gd` started with
  `OS.create_process(OS.get_executable_path(), …)` and the parent's user args plus a last positional
  `shard=<i>,<n>,<file>`. It isn't a `--` option, since `LaunchOptions.parse` and the `game.gd` autoload reject
  unknown options. The child writes `{job index: metrics}` as JSON and quits without printing.
- Pitfalls the spike hit:
  - A child must still reach `quit()`. If the code after the games errors, `_initialize` aborts and the child idles
    forever, so the parent hangs.
  - `JSON.parse_string` sorts keys, so the parent rebuilds each game in metric order (METRICS, then era metrics by
    era).
  - Tests call `run_files` in-process, so they must never spawn children (AC4).
- The parent polls `OS.is_process_running`; add a timeout per run so a hung child fails (AC5) rather than blocking.
- Update the balance skill's timing note ("about 4 minutes at 20 seeds") once this lands.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_parallel_sim::test_the_report_is_the_same_on_1_2_and_4_processes` |
| AC2 | `test_parallel_sim::test_a_single_strategy_report_is_the_same_on_2_processes` |
| AC3 | `test_parallel_sim::test_more_processes_than_games_runs_one_per_game` |
| AC4 | `test_parallel_sim::test_run_files_plays_in_this_process_by_default` |
| AC5 | `test_parallel_sim::test_a_shard_with_no_results_fails_the_run_and_its_directory_goes` |
| AC6 | `test_parallel_sim::test_a_parallel_run_leaves_no_results_directory`, and AC5's test (after a failed shard) |

## Manual check
- [ ] `time scripts/sim.sh 20` on this machine: note the time against `SIM_PROCS=1 scripts/sim.sh 20`.

## Log
- 2026-10-01: from `spike/sim-speed`.
- 2026-10-01: built with 150 and 151 on the user's go-ahead (no separate red stop). Children don't get the parent's
  raw args, so a run started from the tests works too. They get explicit ones: the seed count, the strategy,
  `--civ` / `--turns`, then `cards=`, `config=`, `shard=i/n` and `out=` tokens at the end. `run.gd` strips those
  tokens before `LaunchOptions.parse`; the `game.gd` autoload ignores them as positional args. The job list
  (`_jobs`) is shared by the parent and `play_shard`, so a child plays exactly its slice. `run_files` reports
  `procs` (the processes used) so AC3/AC4 are observable. `CHILD_TIMEOUT_MSEC` (1 h) kills a hung child; its shard then
  fails the run. That timeout has no test.
- Verified: `scripts/sim.sh 2` and `scripts/sim.sh 3 wealth --civ greece --turns 30` print exactly what `main` printed.
  `scripts/sim.sh 20` took 14.7s on 12 cores (`main`: ~7 min serially before 150/151). `SIM_PROCS=1 scripts/sim.sh 4`
  took 21.9s (84s on `main` before 150/151). The new test file adds ~5s to the suite (it starts child processes).
