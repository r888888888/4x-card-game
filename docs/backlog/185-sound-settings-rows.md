---
id: 185
title: Sound rows in Settings and the game menu
type: feature
status: review
branch: feat/185-sound-settings-rows
---

## Goal
The player can set how loud the game is and switch interface sounds off ([docs/design/mcm-style-guide.md](../design/mcm-style-guide.md)
§12 rule 11): the settings screen gets an Interface sounds legend key and a slider for each of Master, Game and
Interface, and the game menu gets the Interface sounds key, so a player annoyed by clicks mid-game can silence them
in two presses without losing the event sounds.

## Acceptance criteria
- [x] AC1: The settings screen shows, below Reduce motion (and Day mode once 183 is in), an "Interface sounds" row (a
  label and a `LegendKey`, as 182's row) and then "Master", "Game" and "Interface" rows, each a label, an `HSlider`
  (0–100, step 10) and a figure reading the value with a percent sign ("70%").
- [x] AC2: Opening the screen shows the current settings: given master 80, game 50, interface 70 and interface sounds
  off, the sliders sit at 80, 50 and 70, the figures read "80%", "50%", "70%" and the key reads "OFF".
- [x] AC3: Moving a slider calls `Settings.set_volume` for its bus with the new value and updates its figure at once;
  given the Game slider at 50, pressing Right sets it to 60, calls `Settings.set_volume(Settings.GAME, 60)` and the
  figure reads "60%". Toggling the key calls `Settings.set_interface_sounds`.
- [x] AC4: The game menu shows the "Interface sounds" row (no sliders) under its Reduce motion row, at the column's
  width as 182's row. Changing the setting on the menu shows on the settings screen and the other way round.
- [x] AC5: The new rows are in each screen's focus loop in reading order (key, then Master, Game, Interface); each
  slider has a tooltip naming what it sets ("Clicks, panels and confirmations." for Interface, "Events: techs,
  cities, eras." for Game, "Everything." for Master).

## Out of scope
- A Music slider (no music yet); a test sound played while dragging a slider (it would play on the bus being set,
  which is a later nicety); the title screen's settings.

## Design notes
- `UIKit` gets a `volume_row(label, bus, tooltip)` builder alongside 182's legend-key row, so both screens build rows
  the same way; the slider is themed by `GameTheme` (178), not per control.
- Builds on 182 (the legend-key row) and 184 (the settings).

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_sound_rows::test_the_settings_screen_shows_the_sound_rows_under_day_mode` |
| AC2 | `test_the_settings_screen_shows_the_current_sound_settings` |
| AC3 | `test_pressing_right_on_a_slider_sets_its_volume`, `test_the_interface_sounds_key_sets_the_setting` |
| AC4 | `test_the_menu_shows_the_interface_sounds_row_at_the_columns_width`, `test_the_menu_and_settings_keys_mirror_each_other` |
| AC5 | `test_the_sound_rows_are_in_the_focus_loops_in_reading_order`, `test_each_slider_says_what_it_sets` |

## Manual check
- [ ] Settings: the three sliders line up under the key, with their figures right-aligned; dragging one moves in
  steps of 10.
- [ ] Menu → Interface sounds OFF: the key latches up and the next button press is silent (once 187 is in).

## Log
- 2026-10-02: Specced from the style guide (§12 rule 11). Decided 2026-10-02: sliders in steps of 10% for Master,
  Game and Interface, plus the Interface sounds legend key.
- 2026-10-02: Built. `UIKit.sound_toggle()`, `volume_row(label, bus, tooltip)` and `show_volume`; `SettingsScreen.sound_toggle`, `sliders`, `figures`, `show_sound()`; the menu's row sits under Day mode (183 came first). `GameTheme` styles `HSlider`. Changed existing tests for the new row: `test_button_widths` (the settings column is now all its rows; the menu column gains the row) and `test_legend_key`'s focus walk (Day mode → Interface sounds → Close).
