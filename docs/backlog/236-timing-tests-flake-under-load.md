---
id: 236
title: The cabinet doors and scaling tests flake on a loaded machine
type: bug
status: review
branch: fix/236-timing-tests-flake-under-load
---

## Reproduction
- Seed: none (test-suite timing).
- Steps:
  1. Load the machine (load average ~20 from parallel sessions) and run `scripts/test.sh`.
- Expected: green.
- Actual: `test_cabinet_doors::test_the_doors_close_then_part_on_the_government_choice` fails now and then ("the part
  as they part: 0.73 s"; "the close as they meet: 0.35 s" / "the part as they part: 0.45 s");
  `test_engine_scaling::test_modifiers_scale_linearly_with_the_tableau` failed once. Both pass when rerun alone.

The doors test measured sounds against `start := sfx.clock()`, the wall clock, taken before `end_turn`; the doors
schedule their sounds at `clock() + delay` when `close_over` runs, so however long `end_turn` and the first-time WAV
load inside `Sfx.play` took on a loaded machine added to the measured offsets. Reproduced by a 150 ms
`OS.delay_msec` before `end_turn`: "the close as they meet: 0.37 s", "the part as they part: 0.43 s". (Timers and
tweens are not the problem: the runner's `--fixed-fps 120` puts them on game time.) The scaling tests time each side
in a separate block of runs, so a busy spell can land on one side only.

## Acceptance criteria
- [x] AC1: Given the government choice coming (main scene, doors on) and `main.sfx`'s clock frozen, when `end_turn`
  brings the choice, then the close sound is due exactly CLOSE (0.20 s) and the part sound exactly CLOSE + HOLD
  (0.26 s) after it (±0.001 s), however long `end_turn` or the sound loading takes; the doors' edge, overlay and
  sound-count checks are unchanged.
- [x] AC2: With a 300 ms stall injected before and after each `end_turn` in the cabinet-door tests (scratch run),
  they all pass; with the part sound scheduled 10 ms late (scratch mutation), AC1 fails.
- [x] AC3: The scaling ratios (`test_engine_scaling` ×2, `test_sim::test_a_bot_tech_pick_costs_under_half_a_tech_tree`)
  time the two sides in alternating runs (`time_ratio` in `tests/lib/test_case.gd`, replacing `best_time_usec`),
  best of each, so a busy spell hits both sides; thresholds unchanged.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_cabinet_doors::test_the_doors_close_then_part_on_the_government_choice` (clock frozen, ±0.001 s); `test_the_doors_play_once_however_often_the_board_refreshes` (clock frozen) |
| AC2 | scratch runs (stall injection, mutation), not committed |
| AC3 | `test_engine_scaling::test_modifiers_scale_linearly_with_the_tableau`, `test_a_met_eureka_check_does_not_grow_with_the_tableau`; `test_sim::test_a_bot_tech_pick_costs_under_half_a_tech_tree` |

## Root cause
The doors test compared sound times scheduled on the wall clock (`Sfx.clock()`) with a wall-clock start taken
before `end_turn`, so time spent in `end_turn` and in loading the sounds counted as animation time. It passed alone
because an idle machine does that work in a few ms, inside the 0.06 s slack. Now it freezes the sound clock, which
makes the check exact (±0.001 s, tighter than before). The scaling ratios timed slow and fast sides in separate
blocks; they now alternate run by run. A timing ratio can only be made robust, not deterministic.

## Manual check
- Run `scripts/test.sh` a few times while the machine is loaded (other sessions running their suites): green.

## Log
- Test-only change: no UI or engine behaviour changes.
- Checked under load (12 busy `yes` processes): `test_cabinet_doors` and `test_engine_scaling` green, 3 rounds.
- Same wall-clock risk elsewhere: none found for sounds; other UI tests `await create_timer`, which is game time
  under `--fixed-fps` and so safe.
