---
id: 099
title: Split the start screen into a title screen, a new game screen and settings
type: feature
status: review
branch: feat/099-title-screen
---

## Goal
The start screen (063, 064) crams the title, the civilization cards, the seed field, New game and Reduce motion
into one busy panel. Replace it with a classic title screen that has three buttons: New game, Settings and Exit.
New game opens a separate screen where you pick the civilization and the seed and then start. Settings opens a
screen with the Reduce motion toggle.

## Acceptance criteria
<!-- UI tests in the real main scene (tests/test_start_screen.gd), like 063. -->
- [x] AC1: On launch the title screen is open. It shows the game's title and exactly three buttons, in this
  order: "New game", "Settings" and "Exit". It has no seed field, no civilization cards and no Reduce motion toggle.
  No game has started and the board is hidden, as in 063 AC1.
- [x] AC2: Pressing New game on the title screen hides it and opens the new game screen. That screen shows the
  listed civilizations with the saved one preselected (064), the seed field (empty means random), a "Start" button
  and a "Back" button. No game has started yet.
- [x] AC3: On the new game screen, Start with the seed field at "42" starts seed 42 as the selected civilization
  and hides the screen. An empty or non-integer seed ("", "abc", "4.5") starts a random seed from 1 to 999999.
  Enter in the seed field does the same as Start. Selecting a civilization still saves it (064).
- [x] AC4: Settings on the title screen opens the settings screen, which holds the Reduce motion toggle and a
  "Back" button. The toggle shows and saves the same `Settings` value as the menu's toggle (063 AC3). Back on the
  settings screen and Back on the new game screen both return to the title screen with no game started.
- [x] AC5: Exit on the title screen calls the quit hook once.
- [x] AC6: The in-game menu's "New game" abandons the current game and opens the new game screen, not the title
  screen. Back from there goes to the title screen. Restart and the game-over replay behave as today.
- [x] AC7: Keyboard. When each screen opens, its first button has the focus: New game on the title screen, Start
  on the new game screen, Back on the settings screen. Enter presses the focused button. Tab and the arrows stay
  on the open screen and wrap. Esc on the new game screen or the settings screen works like Back. Esc on the
  title screen does nothing.

## Out of scope
- New settings beyond Reduce motion. The in-game menu keeps its own toggle and its seed field.
- Save/load, continue, and difficulty.
- Visual polish beyond a clean layout (098 covers tween polish).

## Design notes
- This is UI only. The engine and `Game.new_game(seed, civ)` do not change.
- Suggested split: `ui/start_screen.gd` becomes the title screen. The civilization and seed picker moves into
  a `NewGameScreen` component (`seed_edit`, `start_button`, `back_button`, `selected`, `select()`,
  `civilization_ids()`, `start_requested(seed_value)`). A small `SettingsScreen` component holds the motion
  toggle. `main.gd` connects them. Watch `main.gd`: it is at about 527 lines (500 prints a warning, 700 fails).
- Existing 063 and 064 tests that expect the seed field and cards on the start screen (`seed_edit`,
  `new_game_button` starting the game, `motion_toggle`) will change to go through the new game and settings
  screens. List each one at the red checkpoint as an approved change to an existing test.
- The overlays' z-order stays as in 063: above the game-over overlay and below the card details. You can still open
  a civilization's details from the new game screen.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_start_screen::test_launch_shows_the_title_screen_and_starts_no_game`, `test_title_screen_has_the_title_and_three_buttons` |
| AC2 | `test_new_game_opens_the_new_game_screen_without_starting`, `test_the_saved_civilization_is_preselected` |
| AC3 | `test_start_with_seed_42_starts_that_seed`, `test_start_with_an_empty_or_bad_seed_uses_a_random_seed`, `test_enter_in_the_seed_field_starts`, `test_selecting_a_civilization_saves_it_and_start_uses_it` |
| AC4 | `test_settings_opens_the_settings_screen_with_the_motion_toggle`, `test_settings_and_menu_toggles_share_the_setting`, `test_back_returns_to_the_title_screen_from_both_screens` |
| AC5 | `test_exit_on_the_title_screen_calls_the_quit_hook_once` |
| AC6 | `test_menu_new_game_opens_the_new_game_screen`, `test_back_after_the_menu_new_game_goes_to_the_title_screen`, `test_menu_restart_replays_the_seed_without_a_screen`, `test_game_over_replay_starts_straight_away`, `test_restart_keeps_the_civilization` |
| AC7 | `test_each_screen_focuses_its_first_button`, `test_enter_presses_the_focused_button`, `test_tab_and_arrows_stay_on_the_open_screen_and_wrap`, `test_esc_goes_back_from_the_new_game_and_settings_screens`, `test_esc_on_the_title_screen_does_nothing` |
| Design | `test_ui_structure::test_each_ui_component_has_its_own_script`, `test_main_uses_each_component` (`NewGameScreen`, `SettingsScreen`) |

## Manual check
- [ ] Run `godot --path .`: the title screen shows the game's name over New game, Settings and Exit, and looks uncluttered at the default window size and when resized.
- [ ] Go title → New game → Back → Settings → Back → New game → Start. Each screen replaces the previous one, and
  no screen shows through another.
- [ ] Menu → New game → pick another civilization → Start works repeatedly and leaves no old cards on the board.
- [ ] Click a civilization card's details on the new game screen: the details modal opens above the screen.
- [ ] Exit quits the game.

## Log
- 2026-09-30: Specced. The user chose: the menu's New game goes to the new game screen (not the title screen), and
  Settings holds only Reduce motion plus Back, with the menu keeping its own toggle.
- 2026-09-30: Built. `ui/start_screen.gd` is now the title screen (`new_game_button`, `settings_button`,
  `exit_button`); the civilization and seed picker moved to `ui/new_game_screen.gd` (`NewGameScreen`, Start and
  Back) and Reduce motion to `ui/settings_screen.gd` (`SettingsScreen`). `main.gd` gains `show_title_screen()` and
  `show_new_game_screen()` (replacing `show_start_screen()`), and Esc on the inner screens goes back in `_input`
  (the details modal takes Esc first). The 063/064 start-screen tests were moved onto the new screens as approved.
- 2026-09-30: Follow-up worry: `ui/main.gd` is now 669 lines (limit 700). The three screens' navigation (open,
  hide, Back, Esc, `_screen_open`) is a real boundary for a split if the next UI item needs room.
