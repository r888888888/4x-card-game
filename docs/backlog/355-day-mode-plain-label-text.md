---
id: 355
title: Plain labels (the new-game screen's "Seed") are white on paper in Day mode
type: bug
status: review
branch: fix/355-day-mode-plain-label-text
---

## Reproduction
- Seed: not needed.
- Steps:
  1. Turn Day mode on (Settings → Day mode).
  2. Open the menu → New game, and read the "Seed" label beside the seed field. Also Settings → the "Seed" label.
- Expected: the label reads in `Palette.TEXT` on the paper sheet, like the rest of the screen.
- Actual: it is white on paper, almost unreadable. The field's "random" placeholder is pale grey too.

## Acceptance criteria
- [x] AC1: Given Day mode on, when the new-game screen is open, then its "Seed" label's font colour is
  `Palette.TEXT`'s Day value (`22211f`), and the seed field's placeholder colour is `Palette.TEXT_DIM`'s Day value
  (`57534b`).
- [x] AC2: Given Day mode on and a game in progress, when the Settings modal is open, then its "Seed" label's font
  colour is `Palette.TEXT`'s Day value (`22211f`).
- [x] AC3: Given Night mode, when the new-game screen is open, then its "Seed" label reads `Palette.TEXT`'s Night
  value (`ede6d6`) and the placeholder `Palette.TEXT_DIM`'s Night value (`b9b1a1`); switching Day on and off with it
  open follows each mode.
- [x] AC4: Given Day mode on and a game in progress with the new-game screen, then the Settings modal, open, then no
  `Label` in main resolves its font colour to Godot's default white (`ffffff`), whatever its variation.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_day_mode::test_bug_355_the_new_game_seed_label_reads_on_paper_in_day_mode` |
| AC2 | `test_day_mode::test_bug_355_the_settings_seed_label_reads_on_paper_in_day_mode` |
| AC3 | `test_day_mode::test_bug_355_the_new_game_seed_label_follows_day_mode` |
| AC4 | `test_day_mode::test_bug_355_no_label_draws_in_default_white_in_day_mode` |

## Root cause
`GameTheme` set `font_color` only on its `Label` variations (`_label`), never on the base `Label`, so every
`Label.new()` with no variation (the seed rows, Settings' Day mode, motion and volume rows) drew in Godot's default
white in both modes, and the seed field's placeholder in Godot's pale grey. Night's dark sheets hid it, and the Day
tests (183, 197, 323) checked panels, buttons, card lines and rich text, never a plain label. `_controls` now gives
the base `Label` `Palette.TEXT` and `LineEdit`'s placeholder `Palette.TEXT_DIM`; AC4's sweep guards every label.

## Manual check
- Day mode: the new-game screen's and Settings' "Seed" labels and the "random" placeholder read dark on paper.
  Night mode looks as before (plain labels move from white to `TEXT`, `ede6d6`).
- Look over the other screens and modals in Day mode for any other white text (tooltips, toasts, the log, the
  Knowledge and Supply screens).

## Design notes
- Likely fix in `ui/game_theme.gd`'s `_controls`: give the base `Label` type `font_color` `Palette.TEXT`, and
  `LineEdit` `font_placeholder_color` `Palette.TEXT_DIM`. Every variation already sets its own colour, so only plain
  labels change. A label that sets its own override keeps it.
- Same family as 323 (`RichBody`) and 324 (the load-error overlay's plain `RichTextLabel`, at red review on
  `fix/324-day-mode-load-error-text`). Leave the base `RichTextLabel` to 324 so the two don't edit the same lines.

## Log
- 2026-10-06: specced from a user report. `GameTheme` sets `font_color` only on the `Label` variations
  (`_label`), never on the base `Label`, so a `Label.new()` with no variation draws in Godot's default white in
  both modes; Night's dark sheets hid it. `LineEdit` sets `font_color` but not the placeholder colour.
- 2026-10-06: red. AC4's sweep also finds Settings' row labels white (Reduce motion, Day mode, Interface sounds,
  the volume rows and their percentages, the Game row): the same cause.
- 2026-10-06: fixed in `ui/game_theme.gd` (two lines). Night's plain labels move from white to `TEXT` (`ede6d6`).
  Still open: 324 (the load-error overlay's plain `RichTextLabel`).
