---
id: 223
title: Make the test suite run in seconds, not minutes
type: feature
status: in-progress
branch: feat/223-faster-test-suite
---

## Goal
`scripts/test.sh` takes 101 s wall (21% CPU) on main, close to the Stop hook's 120 s timeout. Make the whole suite
run in well under 20 s, with no test dropped and no test made weaker, so every turn's check is quick and the hook
never times out.

Profiling on main (c5899a8, 1426 tests):
- The 1083 tests that never wait for a frame take 5.5 s together (median 0.7 ms). The engine is not the cost: a
  `make_engine` game is 0.5 ms to build, a 20-turn ScriptedBot game on the real data is 20 ms.
- The 343 tests that wait for frames take 93.6 s over 12 622 frames, ~7.4 ms each. Headless Godot can't draw, so it
  sleeps `low_processor_usage_mode_sleep_usec` (6.9 ms) every frame. Turning the sleep off alone doesn't help:
  animation tests wait on real time (`create_timer`, tween lengths) and just spin through more frames.
- With the sleep off and a fixed time step (`--fixed-fps 120`, ~8.3 ms of game time per frame, close to the ~7.4 ms
  the tests were written against) the suite is green in ~18 s. What's left is spread thin: building and freeing the
  main scene is ~18 ms per UI test (about 20 components, none over 3.2 ms), a 20-turn game through the UI ~0.32 s.
  The next lever is running test files in parallel.

## Acceptance criteria
- [ ] AC1: Given a run of the suite, when a test runs, then `OS.low_processor_usage_mode_sleep_usec` is 0 (no
  per-frame sleep).
- [ ] AC2: Given a run of the suite, when frames run, then each one's process delta is 1/120 s, even a frame that
  took 50 ms of real time: game time advances a fixed step, whatever the wall clock does.
- [ ] AC3: Given the sorted test files and a shard count n ≥ 1, when they are split into n shards, then shard i
  (0-based) gets files i, i + n, i + 2n, …: the shards are disjoint, together hold every file, and a count of 1 gives
  every file to shard 0.
- [ ] AC4: Given `scripts/test.sh` (with or without a filter or `--balance`), when it runs, then the files run in up
  to `TEST_JOBS` parallel Godot processes (default: the CPU count), each with its own empty `HOME` so no two share
  `user://`; it prints every FAIL line and then one last line `N tests, M failures` summed over the shards; it exits
  non-zero if any shard failed, a shard crashed, or no test matched the filter.
- [ ] AC5: Given a shard whose files hold no test matching the filter, when it runs, then it is not a failure by
  itself (only the whole run matching nothing is).

## Out of scope
- Engine performance work: profiling found no engine hot path worth the risk (see Goal).
- Running a chosen subset of "critical" tests instead of the whole suite.
- Speeding up the main scene's construction or `_refresh` (spread over ~20 components; small gain once sharded).

## Design notes
- `tests/run_tests.gd` sets the sleep to 0; `scripts/test.sh` passes `--fixed-fps 120` (Godot has no runtime setter
  for it). `--fixed-fps 60` is a little faster but breaks
  `test_era_sheet::test_the_sheet_wipes_in_then_rings_then_the_name_letter_by_letter`, which assumes two frames cover
  only a sliver of the wipe; 120 keeps that true without touching the test.
- The runner reads `TEST_SHARD=i/n` from the environment (a `--shard` user arg would reach the game's
  `LaunchOptions` too, which logs it as an unknown option); the split is a static function in `tests/lib/` so it can be tested.
- Each shard's `HOME` is a fresh temp dir, so the player's real `user://` (settings.cfg) is never touched by a run, and
  two sessions running the suite at once no longer race on the shared test temp files.
- The Stop hook reads the last line as the summary; keep `N tests, M failures` last.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_test_runner::test_frames_run_without_the_headless_sleep` |
| AC2 | `test_test_runner::test_each_frame_is_a_120th_of_a_second_whatever_the_wall_clock_does` |
| AC3 | `test_test_runner::test_shards_take_every_nth_file`, `test_test_runner::test_one_shard_takes_every_file` |
| AC4 | Manual check (the script that runs the suite can't run inside it) |
| AC5 | Manual check |

## Manual check
- [ ] `time scripts/test.sh` is green and well under 20 s; run it 3 times to look for flaky tests.
- [ ] `scripts/test.sh test_rules` runs only the rules tests across the shards; `scripts/test.sh no_such_test` fails
  with "No tests matched".
- [ ] A deliberately failing test shows its FAIL line, the summary counts it, and the exit code is 1.
- [ ] `scripts/test.sh --balance` still runs only `tests/balance/`.

## Log
- 2026-10-02: Specced from profiling (numbers in Goal). The user asked for engine optimization and a critical-test
  subset; the profile showed neither is where the time goes, so the item fixes the frame sleep and shards the run.
- 2026-10-02: Two of the red tests were wrong and were fixed during green. `pick(files, 3, 8)` of 7 files is ["d"],
  not none; the "past the last file" case is shard 7 of 8. And "a 0.25 s timer takes 30 frames ±1" took 32 in a
  serial run: each frame stepped exactly 1/120 s, but the count shifts with where in a frame the timer starts, and
  30 steps of 1/120 leave a float remainder of one more frame. AC2 now asserts the fixed step itself: each process
  delta is 1/120 s, a 50 ms frame included. Both tests still fail without the change (the shard script missing;
  deltas follow the wall clock without `--fixed-fps`).
- 2026-10-02: The shard goes in the environment (`TEST_SHARD`), not a user arg: `LaunchOptions` (Game autoload)
  logs every unknown `--` arg. `--balance` already gets that noise; left alone (it's outside a test, not a failure).
