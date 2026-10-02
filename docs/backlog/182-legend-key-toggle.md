---
id: 182
title: The legend key for Reduce motion
type: feature
status: ready
branch: feat/182-legend-key-toggle
---

## Goal
The Reduce motion setting becomes the guide's legend key ([docs/design/mcm-style-guide.md](../design/mcm-style-guide.md)
§7.5, §15.4): a push key that latches down when on, with a lamp strip across its top that lights and its state printed
on its face, beside a "Reduce motion" label. Today it is a button whose text reads "Reduce motion: on", which looks like
an action rather than a setting. Proven in Godot in the `spike/mcm-godot` spike (`spike/legend_key.gd`).

## Acceptance criteria
- [ ] AC1: A `LegendKey` is a toggle `Button`: when pressed its text is "ON" and `lamp_color()` is `Palette.GAIN`; when
  not, "OFF" and `Palette.FIELD`. Setting it with `set_pressed_no_signal` updates the legend and lamp too.
- [ ] AC2: It uses the theme's button boxes, so latched it shows the `pressed` box (sunk 2 px, no shadow, 178) and
  unlatched the `normal` box on its shadow, each with room above the legend for the 6 px lamp strip; it is at least
  64 × 44 px.
- [ ] AC3: The settings screen and the game menu show Reduce motion as a row: a "Reduce motion" label and a
  `LegendKey` (`main.settings_screen.motion_toggle` and the menu's toggle are the keys). Toggling either sets
  `Settings.reduce_motion` and saves it, as now; opening either shows the current setting (given Reduce motion on,
  the key reads "ON"), and changing it on one shows on the other.
- [ ] AC4: The row stands in the menu's button column at the column's width, label left and key right; the other
  buttons in the column keep the widest button's width (`test_button_widths` checks the row in place of the old
  toggle button).
- [ ] AC5: The key is in each screen's focus loop where the old toggle was; Space or Enter on it toggles the setting;
  its tooltip is the one the old toggle had.

## Out of scope
- Other settings (there are none yet); the HTML pages' other switch designs.

## Design notes
- `ui/legend_key.gd` (`LegendKey`), from `spike/legend_key.gd`: it copies the theme's boxes in `_ready` (the spike found
  they aren't reachable before the key is in the tree) and draws the lamp strip, offset 2 px when latched.
- `UIKit.motion_toggle()` returns the row (or the key and the row separately); `UIKit.show_motion` sets the key.
- Builds on 178 (the pressed box with press travel).

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|

## Manual check
- [ ] Menu → Reduce motion: the key latches down and its strip lights green; pressing it again pops it back up.
- [ ] The row lines up with the menu's buttons.

## Log
- 2026-10-01: Specced from the mid-century style guide (the legend key was chosen over five other switch designs, see
  [docs/design/lamp-key-options.html](../design/lamp-key-options.html)) and the `spike/mcm-godot` spike.
