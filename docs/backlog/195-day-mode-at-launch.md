---
id: 195
title: Launching with Day mode saved refreshes a board with no game, and the suite reads the player's settings
type: bug
status: review
branch: fix/195-day-mode-at-launch
---

## Reproduction
- Seed: any; no game needs to start.
- Steps:
  1. Turn Day mode on (Settings or the game menu), so `user://settings.cfg` holds `day_mode=true`; quit.
  2. Launch `godot --path .` (or `godot --headless --path . --quit-after 60`).
- Expected: the title screen in the Paper palette, no errors.
- Actual: 59 `SCRIPT ERROR`s before the title screen shows (`Invalid access to property or key 'tableau'` in
  `GameEngine.zone`, then `population.gd`, `events.gd`, `modifiers.gd` on a nil zone). The title screen then shows.
- Also: with the player's Day mode on, `scripts/test.sh` reports 1124 of 1201 tests failing with the same errors,
  for every session (the Stop hook included), though the code is fine. `HOME=<empty dir> scripts/test.sh` is green.

Found 2026-10-02 while merging 193; present since 183 (the commit before 192 shows the same 59 errors).

## Acceptance criteria
- [x] AC1: Given Day mode on in a temp settings store and `Game.engine` swapped for an engine whose game hasn't
  started (`board_engine()`, no `start`), when the main scene opens, then no script error is raised, the title screen
  is open, the board isn't shown, and a Button in main draws the Day `CONTROL` fill (the theme was built in Paper).
- [x] AC2: Given the same, when a game starts on seed 1, then the board shows in Paper: `main.background_color()` is
  `Palette.DAY["BACKGROUND"]` and a hand card's panel is `Palette.DAY["RAISED"]`.
- [x] AC3: Given the test runner, when any test starts, then `Settings.store` is not the player's store (its path isn't
  `user://settings.cfg`), and Day mode and Reduce motion are off; so the player's settings can't change a test's
  result.
- [x] AC4: Given a full suite run, then the player's `user://settings.cfg` is byte-for-byte unchanged (or still absent).

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_day_mode::test_bug_195_opening_main_in_day_mode_before_a_game_raises_no_error` |
| AC2 | `test_day_mode::test_bug_195_a_game_started_in_day_mode_shows_the_board_in_paper` |
| AC3 | `test_settings::test_bug_195_tests_run_on_a_temp_settings_store` |
| AC4 | the runner itself (`tests/run_tests.gd`): snapshots `user://settings.cfg` before the first test and reports a FAIL if a run changed it; checked by a deliberate break, as a guard |

## Root cause
Confirmed: `main._palette_day` started false, so `_apply_settings()` during
`_build_layout()` sees Day mode as a switch and calls `_refresh()` while `board_shown()` is still true (the title screen
hides the board only later in `_ready`), on an engine with no game. Fix: `_build_layout` records the palette it built
the theme in (`_palette_day = Palette.day`), so only a later switch rebuilds and repaints. It wasn't caught because
183's tests all switch Day mode after a game starts, and the suite ran on the player's real settings store, which had
Day mode off until 2026-10-02; the runner now starts every run on a fresh store (AC3) and fails a run that changes the
player's file (AC4).

## Manual check
- [ ] With Day mode saved, launch the game: no errors in the terminal, the title screen is Paper; start a game: the
  board is Paper.

## Log
- Specced 2026-10-02 from the 193 merge. Workaround until fixed: turn Day mode off in the game, or run the suite with
  `HOME` pointed at an empty folder.
- Red: AC1 and AC2 fail on the launch errors themselves (59 script errors from `_refresh` on an engine with no
  game), with a clean `HOME` and with the player's Day mode on. AC3 fails on `Settings.store` being the player's.
- Green: `main.gd` one line; `tests/run_tests.gd` swaps the Settings store before the first test and compares the
  player's file after the run. AC4 checked by a deliberate break (a test saving `SettingsStore.new()` under a scratch
  `HOME`): the run failed with "the run changed the player's user://settings.cfg". Suite 1201 → 1204, green with a
  clean `HOME` and with the player's Day mode on; a headless launch with Day mode saved shows 0 script errors (was 59).
