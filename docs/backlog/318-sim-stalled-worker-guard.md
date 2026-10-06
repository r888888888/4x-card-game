---
id: 318
title: A parallel sim run names a stalled or dead worker and fails, instead of waiting silently for up to an hour
type: bug
status: review
branch: fix/318-sim-stalled-worker-guard
---

## Reproduction
- Seed: 1 (all strategies, all civs: 18 games), cold: `SIM_CACHE=0 scripts/sim.sh 1` on the Mac (7 workers).
- Steps:
  1. Run it. 17 games finish within ~4 minutes; one worker claims job index 10 (seed 1, `wide`, **greece**; the
     run's `jobs.json` lists it 11th) and runs it alone while the parent waits at 0% CPU, printing nothing.
  2. On 2026-10-05 the user killed it after 19 minutes, thinking it hung.
- Expected: a run either prints that it's still working (and on what) or fails with a message naming the worker, the
  game and how far it got, within a bounded time of that worker stopping making progress.
- Actual: no output until every worker exits. The only guard is `CHILD_TIMEOUT_MSEC` (60 min for the **whole run**),
  after which the parent kills the workers and reports `game 11 of 18 has no result`, with no seed, strategy, civ or
  turn.

### What the investigation found (2026-10-05)
- **It wasn't a hang.** Reproduced at 20:28: worker 2 claimed job 10 at 20:30:12 and ran it at 99% CPU (14:47 CPU
  time) until the run ended normally at 20:43:37 with exit 0. `SIM_PROCS=1 SIM_CACHE=0 scripts/sim.sh 1 wide --civ
  greece` alone took 13½ minutes and also exited 0 (score 838, 55 cities). The leftover `jobs.json` of the killed run
  (`$TMPDIR/sim-64719-317149`) shows job 10 was wide/**greece**, not phoenicia (index 8, which finished in ~2 minutes,
  as the solo check showed). The worker was busy computing, not blocked on I/O, claims or the lock, and the game
  doesn't depend on what the worker played before: it's as slow on its own. The 19 minutes against 13½ is load and
  core placement (the run is `nice 10`).
- **Why that game is slow.** The wide bot settles every territory it can (land weight 20): by turn 90 the tableau
  holds 179 cards. Each position the bot values costs time roughly in proportion to the tableau (at turn 10 → 90:
  `legal_actions` 0.5 → 17 ms, `value` 0.6 → 3.7 ms, `turn_forecast` 0.5 → 3.2 ms; `fork` stays at 0.5 ms), while the
  number of positions per turn stays about the same. Every 4th turn `_weigh_revolt` plays 1 + (governments in the
  deck) rollouts of 12 turns each on that big tableau: 40–58 s per such turn for greece against 12–28 s for egypt.
  Turn-by-turn probe of wide/greece seed 1: **631 s of 804 s on the rollout turns**, 772 s after turn 50. Wide/egypt
  took 256 s, most games 1–2 minutes. Making that faster belongs to the bot-speed work (315, see its Log); this item
  is about the run never looking hung and never waiting forever.
- **The 60-minute cap is also wrong the other way.** It counts from the start of the run, not from a worker's last
  progress. A cold `scripts/sim.sh 20` (360 games, about 20× this run's 15 minutes of wall time on 7 workers) would be
  killed at 60 minutes while every worker is healthy, and fail with "no result" for the unfinished games. That breaks
  unattended cloud runs (317).

## Acceptance criteria
- [x] AC1: Given a worker playing a game, when each turn of that game ends (and when it claims the game), then its
  progress file in the run directory holds the job index, the turn reached and the time it was written. When the game
  ends, its result is written as today and the progress file says no game is in play. A run on 1 process writes none.
- [x] AC2 (stalled): Given a parallel run whose stall limit is 0 seconds (options `stall_sec`), when it runs 2 games of
  2 turns on 2 workers, then it returns code 1 within a few seconds; its lines name, for each worker it stopped, the
  worker, the game (`game 1 of 2`), its seed, strategy and civ, the last turn reached and `stalled: no turn finished in
  0 s`; no worker process of the run is still running afterwards, and its results directory is removed.
- [x] AC3 (dead): Given a run directory where worker 3 claimed job 10 of 18 (seed 1, `wide`, `greece`), its progress
  file says turn 57, it wrote no result and its process isn't running, when the parent reads the workers, then the
  run's errors include `worker 3 stopped during game 11 of 18 (seed 1, wide, greece) at turn 57` instead of only
  `game 11 of 18 has no result`. A game that was never claimed still reports `has no result`.
- [x] AC4 (slow but alive): Given a parallel run with the default stall limit (10 minutes, `SIM_STALL_SEC` overrides it,
  a whole number of seconds of at least 1; anything else is ignored), when its games take longer in all than 60
  minutes but every worker finishes a turn more often than the limit, then nothing kills it: there is no whole-run
  deadline (`CHILD_TIMEOUT_MSEC` goes). Tested on the parsing function and on a run of 2 short games with a 600 s
  limit returning code 0; the hour-long case is a Manual check.
- [x] AC5 (progress): Given a parallel run still waiting on workers, when 60 s pass since its last progress line (or
  since it started), then it prints one line to stderr: games done of the total, and each running game with its seed,
  strategy, civ, turn and minutes so far, e.g. `sim: 17 of 18 games done; playing seed 1 wide greece (turn 63, 9 min)`.
  The line's text comes from a function tested on fixed progress data; the 60-second cadence is a Manual check.
- [x] AC6: The existing parallel tests (`tests/balance/test_parallel_sim.gd`) stay green unchanged: same reports on 1,
  2 and 4 processes, one game per claim, the lock.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_sim::test_bug_318_a_game_reports_each_turn_and_plays_the_same`, `test_sim_stall::test_bug_318_progress_reads_back_what_was_written`, `balance/test_parallel_sim::test_bug_318_a_worker_leaves_progress_saying_no_game_is_in_play` |
| AC2 | `balance/test_parallel_sim::test_bug_318_a_stalled_worker_is_stopped_and_named`, `test_sim_stall::test_bug_318_a_stalled_workers_game_names_the_stall_limit`, `test_sim_stall::test_bug_318_a_worker_stalled_between_games_is_named` |
| AC3 | `test_sim_stall::test_bug_318_a_dead_workers_game_is_named_with_its_turn` |
| AC4 | `test_sim_stall::test_bug_318_the_stall_limit_defaults_to_10_minutes`, `…_sim_stall_sec_sets_the_stall_limit`, `…_an_invalid_sim_stall_sec_is_ignored`, `balance/test_parallel_sim::test_bug_318_a_run_within_the_stall_limit_finishes` (passes before the fix: a guard that the stall check never stops a healthy run) |
| AC5 | `test_sim_stall::test_bug_318_the_progress_line_names_each_game_in_play` |
| AC6 | the rest of `balance/test_parallel_sim.gd`, unchanged |

## Design notes
- Progress: `SimStats.progress_path(dir, worker)` (`<worker>.progress.json`), written by `play_claimed` through an
  optional per-turn callback that `_play_one` calls when `engine.turn` advances (it already tracks that in `on_state`).
  In-process runs pass none, so their games and reports are unchanged. Time is `Time.get_unix_time_from_system()`,
  which the parent and workers share.
- The parent's wait loop (`_play_children`) checks every worker each pass (it polls every 20 ms today): a running
  worker whose progress is older than the stall limit is killed and recorded as stalled; a worker that exited is
  done. When all are done (or stopped), `read_workers` builds the errors from the claims, results and progress files
  (AC3's message for a claimed, unfinished game; `has no result` for the rest), then removes the directory.
- A stalled worker's other games aren't replayed: the run fails, because a report missing a game would be wrong. The
  other workers carry on to the end so their results come back in the same call; the run still exits 1.
- Limit: 10 minutes is ten times the slowest turn measured (a 58 s rollout turn of wide/greece under full load).
  `SIM_STALL_SEC` is read in `sim/run.gd` next to `SIM_PROCS`, into `options.stall_sec`.
- The progress line goes to stderr through `printerr`, which `scripts/sim.sh` passes through (it filters only Godot's
  own noise), so it shows in a terminal and in a cloud agent's log and never in the report on stdout.
- Tests that spawn workers belong in `tests/balance/` (real data, like the rest of `test_parallel_sim.gd`); AC3 and
  AC5's text are pure and can use hand-written files in a temp directory.

## Root cause
The parent's only guard was a 60-minute deadline for the whole run (`CHILD_TIMEOUT_MSEC`), so it couldn't tell a slow
game from a stuck one: it waited silently on a 13-minute game, would have killed a healthy run longer than an hour, and
when it did kill, its error had no worker, seed, strategy, civ or turn because workers wrote nothing until a game
ended. The parallel tests only played games of a few turns, so neither the deadline nor the silence ever showed. Now
each worker writes its progress every turn (`write_progress`), the parent stops one that finishes no turn within
`stall_sec` (`_watch`) and names what it was playing (`read_workers`), and prints a progress line each minute.

## Manual check
- [ ] `SIM_CACHE=0 scripts/sim.sh 1`: progress lines appear about once a minute while wide/greece runs alone, and the
  run exits 0.
- [ ] `SIM_STALL_SEC=30 SIM_CACHE=0 scripts/sim.sh 1`: the run fails within about a minute of a rollout turn that takes
  longer than 30 s, naming that worker and game, and `pgrep -fl sim/run.gd` shows no worker left.

## Log
- 2026-10-05: specced from a cold parallel run that looked hung (see Reproduction). Investigation in the Reproduction
  section; the slowness itself goes to 315.
- 2026-10-05: built. New `SimStats` API: `play_game` (was `_play_one`, with an `on_turn` callback), `write_progress`,
  `read_progress`, `progress_path`, `stall_sec_from_env`, `progress_line`; `read_workers` takes `stalled`;
  `CHILD_TIMEOUT_MSEC` is replaced by `DEFAULT_STALL_SEC` (600) and `PROGRESS_EVERY_SEC` (60). `sim/run.gd` reads
  `SIM_STALL_SEC`. `OS.kill` reaps the child itself: polling `is_process_running` on the pid afterwards errors.
- Follow-ups: `sim/sim_stats.gd` is now ~720 lines; its parallel-run code (claims, progress, lock, watch) could move
  to its own class as `SimCompare` did (the 700-line rule covers only `engine/` and `ui/`). `tests/balance/
  test_sim_reports.gd` plays full-length real-data games in one process and takes 20+ minutes of the balance suite
  (offered as a separate task).
