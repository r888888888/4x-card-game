---
id: 219
title: The window bar key replaces the legend key
type: feature
status: review
branch: feat/219-window-bar-key
---

## Goal
Every toggle (Reduce motion, Day mode, Interface sounds) changes from the legend key (a 64 × 44 key with a lamp strip
across its top and ON/OFF printed on its face, 182) to the **window bar** from
[docs/design/lamp-key-options.html](../design/lamp-key-options.html) (variant 1): a square 32 × 32 key whose only mark is
a small lamp window across the middle of its face, with the state word, ON or OFF, printed beside it. The key is smaller
and quieter in a settings column, and the light is the only thing on the face. The guide (§7.5, §15.4) is updated to match.

## Acceptance criteria
- [x] AC1: A `LegendKey` is a toggle `Button` with no text of its own and a size of at least 32 × 32 px (the
  64 × 44 minimum is gone). Latched, `lamp_color()` is `Palette.GAIN`; unlatched, `Palette.FIELD`. This holds after
  `set_pressed_no_signal` too.
- [x] AC2: It still uses the theme's button boxes: latched it shows the `pressed` box (sunk 2 px, no shadow), unlatched the
  `normal` box on its shadow. The boxes add no extra top margin for a lamp strip (the lamp is centred in the face).
- [x] AC3: `LegendKey.state_text()` returns "ON" while latched and "OFF" while not, including after
  `set_pressed_no_signal`.
- [x] AC4: The Settings modal (206) shows each toggle as a row: the setting's name on the left, and on the right the key
  followed by its state label (`key.state_label`, the next child in the row). The label's text is `state_text()` and
  follows the key, including when it is set with `set_pressed_no_signal` (given Reduce motion on, opening the modal
  shows its label "ON").
- [x] AC5: The row still fills the width it is given (the modal's column width), the state label ends at the row's right
  edge, and the label is as wide for ON as for OFF, so the key does not move when toggled (`test_button_widths`
  keeps passing).
- [x] AC6: Focus, Space/Enter toggling, tooltips, saving and the key sounds (187) behave as before.

## Out of scope
- Other lamp-key variants, and changing the lamp colour per setting.
- The sound/animation timings (unchanged from 182/187).

## Design notes
- `ui/legend_key.gd`: drop `LAMP_HEIGHT`'s top margin in `_copy_boxes`, set `text` to "", and draw the lamp as a centred
  14 × 6 window (offset by `GameTheme.PRESS` when latched) instead of the full-width strip. The class keeps its name
  (it is still the toggle key) so callers do not change; its doc comment is rewritten.
- New on `LegendKey`: `state_text() -> String` and `state_label: Label`, a caps label the key makes and keeps in step
  (on `toggled` and in `_process`, as the old legend did). `UIKit.setting_row(text, key)` adds `key.state_label` right
  after a `LegendKey`.
- Guide: §7.5 item 5 and §15.4 rewritten for the window bar (32×32 key, 14×6 lamp window, state word beside it,
  label in `type.label-caps`; the transitions table stays, with "the legend changes" becoming "the state word changes");
  mark variant 1 as chosen on the options page, leaving the other variants for reference. Also check §21's "Toggles" row
  and the sound-table descriptions that say "printed ON/OFF legend".
- Supersedes 182's legend-key design (182 stays done).

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_legend_key::test_the_key_is_a_square_toggle_whose_lamp_lights_when_latched` |
| AC2 | `test_legend_key::test_the_key_sits_on_the_themes_boxes_with_the_lamp_in_its_face` |
| AC3 | `test_legend_key::test_the_keys_state_text_is_on_while_latched_and_off_while_up` |
| AC4 | `test_legend_key::test_the_settings_modal_shows_a_reduce_motion_row_with_a_key_and_its_state`, `test_every_settings_toggle_row_shows_its_state_label`, `test_toggling_the_key_sets_saves_and_shows_it`; changed (the state is read beside the key with `shown_state`, not off its face): `test_start_screen::test_the_settings_modals_toggle_is_the_setting`, `test_day_mode::test_the_settings_modal_shows_a_day_mode_key_under_reduce_motion`, `test_sound_rows::test_the_settings_modal_shows_the_current_sound_settings`, `test_the_interface_sounds_key_sets_the_setting` |
| AC5 | `test_legend_key::test_the_row_spans_the_column_label_left_key_and_state_right`; `test_button_widths::test_title_settings_and_new_game_columns_share_one_width` (unchanged) |
| AC6 | unchanged, already green: `test_legend_key::test_the_key_is_in_the_focus_loop_and_space_toggles_it`, `test_key_sounds::test_the_legend_key_latches_on_and_lets_go_with_its_own_sounds`, the tooltip in the AC4 modal test, the saves in `test_toggling_the_key_sets_saves_and_shows_it` |

## Manual check
- [ ] `godot --path .` → Settings: Reduce motion, Day mode and Interface sounds each show a small square key with a lit
  green window when ON, a dark window when OFF, and the word ON/OFF right of it at the row's right edge.
- [ ] Pressing it: over-travels, latches 2 px down; the key does not shift sideways when the word changes.
- [ ] Day mode: the window and key read in both palettes.

## Log
- 2026-10-02: Specced from the user's request to swap the legend key for the window bar.
- 2026-10-02: Built. `LegendKey` keeps its name: text "", 32 × 32 minimum, shrink-centred vertically so it stays square
  in its row, a 14 × 6 lamp window drawn centred (sinking 2 px when latched). New `state_text()` and `state_label`
  (the `StateWord` theme variation: `type.label-caps`, `TEXT_DIM`, the heading face), sized on `ready` to the wider of
  ON/OFF so the key doesn't move; the key frees it if it never joined a row. `UIKit.setting_row` adds it after a
  `LegendKey`. Tests read the shown state through the new `shown_state(key)` helper. Docs: guide §7.5, §15.4 (now
  "lamp key"; §21's Toggles row, the sound tables), `tokens.md`, `testing.md`; the specimen, `transitions.html` and
  `card-stacks.html` draw the window bar; the options page marks variant 1 chosen. The guide's spike notes (§20) keep
  "legend key" as history. One suite run failed the "player's settings.cfg changed" guard; it passed with an isolated
  HOME, so another session wrote the shared `user://` file during the run.
