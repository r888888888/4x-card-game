---
id: 291
title: Run the sim on the performance cores but one, from a shared job queue, one run at a time
type: feature
status: ready
branch: feat/291-sim-spares-the-cpu
---

## Goal
A balance run stops taking over the machine. Since the bot started looking ahead (159, 240, 269), one 100-turn game
costs 12–25 s of CPU (seed 1: baseline 12.2 s, wide 24.5 s; 0.7 s and 1.6 s with lookahead off). So `scripts/sim.sh 20`
(600 games) is about 3 CPU-hours, and it runs on every core. The efficiency cores (4 of 12 here) finish their fixed
shards last. Two sessions running a sim at once start 24 processes. After this item:
- a run leaves a core free and doesn't use the slow cores;
- each worker takes the next game when it finishes one, so no worker sits idle while another works through a fixed
  shard;
- a second parallel run fails at once instead of piling onto the first.

## Acceptance criteria
- [ ] AC1: `SimStats.procs_from_env(env, cpu_count)` returns how many processes a run uses:
  - `{"SIM_PROCS": "3"}` with 12 CPUs → 3, and `{"SIM_PROCS": "1"}` → 1 (SIM_PROCS overrides);
  - `{"SIM_PERF_CORES": "8"}` with 12 CPUs → 7 (the performance cores but one);
  - `{}` with 12 CPUs → 11 (the performance-core count is unknown: every core but one);
  - `{}` with 1 CPU → 1, and `{"SIM_PERF_CORES": "1"}` → 1 (never fewer than 1);
  - `{"SIM_PROCS": "0"}` or `{"SIM_PROCS": "x"}` with `{"SIM_PERF_CORES": "8"}` → 7 (an invalid SIM_PROCS is ignored).
- [ ] AC2: Given a run directory for 6 jobs in which jobs 0–3 are already claimed, when a worker plays from it
  (`SimStats.play_claimed`), then it plays and writes exactly jobs 4 and 5. Then, given a second worker on the same
  directory, it plays none.
- [ ] AC3: Given 7 games (seeds 1–7, `baseline`, `--civ sumer`, `--turns 3`) on `procs` 2, when `run_files` runs, then
  the report equals the `procs` 1 report. The result's `games_per_proc` has 2 entries summing to 7 (each game played
  exactly once).
- [ ] AC4: Given the sim lock held by a running process (the test's own pid), when `run_files` runs with `procs` 2, then
  it returns code 1 and the line "another sim run is using the CPU (pid <pid>); try again when it ends". It plays no
  game, starts no child, and leaves the lock in place.
- [ ] AC5: Given the sim lock naming a pid that isn't running, when `run_files` runs with `procs` 2, then it takes the
  lock and runs (code 0). After the run, the lock is gone, also when a shard failed (152's AC5 case).
- [ ] AC6: Given the sim lock held by a running process, when `run_files` runs with `procs` 1 (in-process, as the tests
  and the main suite do), then it ignores the lock and runs (code 0).

## Out of scope
- Caching results (292) and the main-vs-branch comparison (293).
- Making the bot cheaper (294).
- macOS QoS (`taskpolicy`) instead of `nice`: try it by hand under Manual check; adopt it only if it clearly helps.
- `scripts/test.sh` stays on every core: the main suite takes ~4 s.

## Design notes
- **Processes.** `scripts/sim.sh` exports `SIM_PERF_CORES` from `sysctl -n hw.perflevel0.physicalcpu`, or leaves it
  empty where that key doesn't exist (Linux, Intel Macs). `sim/run.gd` sets `options.procs` from
  `SimStats.procs_from_env(OS.get_environment…, OS.get_processor_count())` instead of the bare CPU count. For the
  balance tests, `scripts/test.sh --balance` keeps its own `TEST_JOBS`.
- **Queue.** This replaces 152's round-robin shards. The parent writes nothing up front. Each child loops: claim the
  lowest unclaimed job index by creating `<run dir>/claims/<i>` with `DirAccess.make_dir_absolute`, which fails with
  `ERR_ALREADY_EXISTS` if another worker got there first, so the claim is atomic. Play the job, then append it to its
  own results file. A child quits when no job is left. `read_shards` keeps reading one file per child and checks that
  every job index came back. A missing job fails the run, naming the child that claimed it, as 152's AC5 does.
  `play_claimed(dir, …)` is the child's loop; `shard=i/n` becomes `worker=i`.
- `games_per_proc` (AC3) is observability for the test and the report header. It isn't printed per process.
- **Lock.** It lives at `OS.get_temp_dir()/4x-card-game-sim.lock`, the per-user temp dir, which every checkout and
  session shares. `run_files` takes an option `lock_path` so tests use their own path. The lock is a directory
  (`make_dir_absolute` is atomic) holding a `pid` file. Taking over a stale lock means removing it and retrying the
  make once.
  Godot's `OS.is_process_running` only knows its own children, so check a foreign pid with
  `OS.execute("kill", ["-0", str(pid)])` (exit 0 means it's running). Release the lock in every exit path of the
  parallel branch of `run_files`, as the results directory is released now.
- **Docs**, in the same item:
  - `scripts/sim.sh` header;
  - `sim/run.gd` doc comment;
  - the balance skill's timing note. It says "about 15 seconds at 20 seeds", which was true before lookahead.
    Re-measure, write the real number, and mention the lock message.

## Test plan
| AC | Test |
|---|---|
| AC1 | |

## Manual check
- [ ] `time scripts/sim.sh 20` on this machine with nothing else running: note wall time and confirm Activity Monitor
  shows 7 busy Godot processes and an idle core. Compare with `main`.
- [ ] While it runs, start `scripts/sim.sh 2` in another checkout: it exits at once with the lock message.
- [ ] Optional: `taskpolicy -c utility scripts/sim.sh 20` vs plain. Is the desktop more responsive, and at what cost
  in wall time? Note it in the Log.

## Log
- 2026-10-05: specced from the sim-CPU discussion (with 292, 293, 294). User chose: a second parallel run fails fast
  rather than waiting.
