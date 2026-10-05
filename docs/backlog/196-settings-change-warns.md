---
id: 196
title: A run that sees the player's settings change warns instead of failing
type: bug
status: in-progress
branch: fix/196-settings-change-warns
---

## Reproduction
- Seed: 5 (any game).
- Steps:
  1. Run the game (`godot --path . -- --civ sumer --turns 20 --seed 5`).
  2. While `scripts/test.sh` runs (or the Stop hook's run), toggle Day mode in the game.
- Expected: the suite's result doesn't depend on what the player does in a game running beside it.
- Actual: the run fails with "the run changed the player's user://settings.cfg (tests must use a temp settings
  store)" (seen 2026-10-02 12:00 in the Stop hook), and blocks every session's Stop hook until rerun.

The check came from 195 (AC4). It compares the player's `user://settings.cfg` before and after the run, so it can't
tell a test writing the file from the player's game saving a setting (`user://` is shared by every checkout and the
game, keyed on the project name). Since 195 every test starts on a fresh store, so a test writing the player's file
is unlikely; a warning still points at it.

## Acceptance criteria
- [ ] AC1: Given the player's settings bytes before a run and different bytes after it, when the runner's check
  compares them (`settings_change_warning(before, after)` in `tests/lib/`, or the runner's own static), then it
  returns a warning naming `user://settings.cfg` and saying a test or a running game changed it.
- [ ] AC2: Given the same bytes before and after (including no file both times), then it returns "".
- [ ] AC3: Given a run in which the player's settings file changes, then the runner prints the warning on a `WARN`
  line and doesn't count it as a failure: with every test passing, it reports 0 failures and exits 0.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_test_runner::test_bug_196_different_settings_bytes_warn_naming_the_file`, `test_bug_196_a_file_that_appears_or_vanishes_warns` |
| AC2 | `test_test_runner::test_bug_196_same_settings_bytes_give_no_warning` |
| AC3 | Manual check: a deliberate break under a scratch `HOME` (runner behavior, as 195's AC4) |

## Root cause
<!-- Filled in by Claude after the fix. -->

## Log
- Specced 2026-10-02, after the Stop hook failed while the player toggled Day mode in a running game. The user chose
  a warning over catching only test writes.
- AC3 is runner behavior: check it like 195's AC4, by a deliberate break under a scratch `HOME` (a test that saves
  `SettingsStore.new()`): the run should print `WARN` and exit 0.
