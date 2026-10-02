---
id: 206
title: A Settings modal, opened from the menu and the title screen
type: feature
status: done
branch: feat/206-settings-modal
---

## Goal
Settings live in one place: a Settings modal opened from the game menu and from the title screen. The menu shrinks to
game actions (Restart, New game, Settings, Close, Exit), and the seed field moves into Settings with its Restart.

## Acceptance criteria
- [x] AC1: Given a game in progress and the menu open, then the menu shows, in order: Restart, New game, Settings,
  Close, Exit, as a `UIKit.button_column`; it no longer shows the seed field, Reduce motion, Day mode or sound rows.
- [x] AC2: When Settings is pressed in the menu, then a `SettingsModal` opens stacked on the menu, with: Reduce motion,
  Day mode, Interface sounds and a volume slider per bus (the rows from 182, 183, 185), and a "Game" section with
  the seed field (showing the current game's seed) and "Restart with seed".
- [x] AC3: Given the seed field holds 42, when "Restart with seed" is pressed (or Enter in the field), then a new game
  starts on seed 42 with the same civilization and every modal closes; given it holds "abc" or is empty, the button is
  disabled and Enter does nothing.
- [x] AC4: The menu's Restart restarts on the current game's seed (no field needed).
- [x] AC5: Given the title screen, when Settings is pressed, then the same `SettingsModal` opens over the title screen,
  without the Game section; the Settings screen (`SettingsScreen`, 099) is gone and nothing pushes it.
- [x] AC6: Changing a setting in the modal saves it and applies at once (Day mode switches the open menu and modal,
  183's AC4); Esc, Close or a click outside closes only the Settings modal, leaving the menu open.

## Out of scope
- New settings.

## Design notes
- `ui/settings_screen.gd` goes (remove its tests in this item); its rows move to `ui/settings_modal.gd`.
- `GameMenu.start_requested(seed_value)` splits into restart (current seed) and the modal's restart-with-seed.
- Styling follows 207 when that lands.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_settings_modal::test_the_menu_holds_only_game_actions`; changed: `test_menu::test_tab_from_close_reaches_exit_then_wraps_to_restart`, `test_button_widths::test_the_menu_column_shares_one_width_and_footer_buttons_fit_their_text` (Restart, New game, Settings) |
| AC2 | `test_settings_in_the_menu_opens_the_settings_modal_over_it` |
| AC3 | `test_restart_with_seed_starts_that_seed_as_the_same_civilization`, `test_enter_in_the_seed_field_restarts_and_a_bad_seed_cannot`; changed: `test_board_labels::test_the_settings_seed_field_shows_the_current_seed`, `test_button_widths::test_seed_fields_still_fill_their_row` |
| AC4 | `test_the_menus_restart_replays_this_games_seed` |
| AC5 | `test_the_title_screens_settings_opens_the_modal_without_the_game_section`; changed to the modal: `test_start_screen` (settings opens the modal, its toggle, Close back to the title, focus, Tab, Esc; `open_screens` counts the modal), `test_navigator::test_the_start_screens_are_on_the_navigator`, `test_button_widths::test_title_settings_and_new_game_columns_share_one_width`; `test_screen_header`'s settings header checks go (no screen) |
| AC6 | `test_a_setting_applies_at_once_and_esc_closes_only_the_settings_modal`; changed: `test_day_mode` (the modal switches and stays open; its Day mode row; Tab in it), `test_legend_key` and `test_sound_rows` (one set of rows, the modal's), `test_key_sounds`' two key tests |

Removed (one set of keys now, nothing to mirror): `test_day_mode::test_toggling_either_day_key_sets_it_and_shows_on_the_other`,
`test_sound_rows::test_the_menu_shows_the_interface_sounds_row_at_the_columns_width` and
`test_the_menu_and_settings_keys_mirror_each_other`. `main.menu_motion_toggle()` / `menu_day_toggle()` /
`menu_sound_toggle()` go with the menu's rows.

Decisions made writing the tests: the modal is `main.settings_modal` (hooks `motion_toggle`, `day_toggle`,
`sound_toggle`, `sliders`, `figures`, `seed_edit`, `restart_button`, `game_section`, `close_button`); it focuses
Reduce motion on opening; its focus loop is the keys, the sliders, the seed field and Restart with seed (in a game),
then Close. The menu keeps its "Playing as" line. "Restart with seed" is disabled while the field isn't a whole number.

## Manual check
- [ ] Menu → Settings → toggle Day mode: both sheets switch and stay open; Esc closes Settings, then the menu.

## Log
- Specced 2026-10-02 from the notes list. Decided 2026-10-02: one modal for the menu and the title screen; the seed
  field moves into it with its own Restart.
- 2026-10-02: Built. `ui/settings_modal.gd` (`SettingsModal`, `main.settings_modal`, `open(seed_value := -1)`,
  `show_settings()`, `restart_requested`); `ui/settings_screen.gd` is gone. `GameMenu` keeps its "Playing as" line and
  Restart (this game's seed), New game and Settings; its seed field and keys moved. `test_sheet_sounds`' screen tests
  use the New game screen (Settings is no longer a screen).
