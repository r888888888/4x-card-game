---
id: 192
title: Palette roles can't be misspelt or frozen by mistake
type: feature
status: review
branch: feat/192-palette-role-guards
---

## Goal
Day mode (183) switches every colour at once, but only if code reads a colour by its role when it draws. Two
easy mistakes slip past the suite today and only show as a stale colour after a switch: passing a `Color` such as
`Palette.GAIN` to `UIKit.stat` (accepted, but frozen at build time) instead of the role `&"GAIN"`, and misspelling a
role name (`&"TERRITROY"`), which only fails when that overlay opens. Adding a colour also takes three edits in
`palette.gd` (the static var, `NIGHT`, `DAY`) with nothing checking that all three were made. After this, each of
these mistakes fails the suite. The design-system review (LLM-friendliness) found these as the traps a model falls
into most easily.

## Acceptance criteria
- [x] AC1: Given `UIKit.stat`, when its parameters are inspected, then its colour parameter is typed `StringName`
  (a role name, default `&"TEXT"`); it no longer accepts a `Color`.
- [x] AC2: Given `UIKit.stat(parent, &"POP")` in the main scene, when Day mode is switched on and the UI repaints, then
  the label's font colour is `Palette.DAY["POP"]`; switched back, it is `Palette.NIGHT["POP"]`.
- [x] AC3: Given every `ui/` script, when its source is scanned for all-caps StringName literals (`&"[A-Z][A-Z_]*"`),
  then each one names a key of `Palette.NIGHT`; the failure lists `file:line` and the unknown name.
- [x] AC4: Given `Palette.NIGHT` and `Palette.DAY`, then they have exactly the same keys, and each key is a static
  `Color` var on `Palette`; and each `Color` static var on `Palette` is a key of both.

## Out of scope
- `UIKit.fx_label`'s `Color` parameter: its callers are short-lived (toasts, error pop-ups) or repaint it themselves
  (the drag hint).
- Proving every colour set in code repaints (a full walk of the tree in both modes); `test_day_mode` samples the look.
- Renaming Palette roles toward the guide's names (see docs/design/tokens.md).

## Design notes
- AC1 removes the `Color` path of `UIKit.stat`. No `ui/` caller uses it; two tests do
  (`test_theme::test_labels_look_as_before` passes `Palette.POP`, `test_theme::test_ui_kit_labels_use_the_variations`
  passes `Color.WHITE`). Per CLAUDE.md (a rule change that makes a path unreachable), this item rewrites those two
  calls to role names (`&"POP"`, `&"TEXT"`) with their assertions unchanged; that's the only change to approved tests.
- `Palette.color()` on an unknown name already errors at runtime (dictionary lookup); AC3 moves that failure to the
  suite.
- AC3 relies on all-caps StringNames in `ui/` being Palette roles only. Today they are (theme variations are
  CamelCase, `UIKit.PAINTED` is lowercase).

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_palette_roles::test_stat_takes_a_role_name_not_a_colour` |
| AC2 | `test_palette_roles::test_a_stat_follows_a_day_mode_switch` |
| AC3 | `test_palette_roles::test_every_role_name_in_the_ui_is_a_palette_role` |
| AC4 | `test_palette_roles::test_night_and_day_name_the_palettes_colours` |

## Log
- Specced from the design-system review (2026-10-02).
- Red: AC2–AC4 already hold today (guards). Each was checked against a deliberate break (stat set once without
  `painted`, `&"TERRITROY"` in choice_overlays, `HINT_BG` dropped from `DAY`): each test failed on its break.
- `get_script_property_list()` leaves out static vars, so AC4 reads Palette's `static var X: Color` lines from source.
- `test_theme`'s two `UIKit.stat` calls take `&"POP"` and `&"TEXT"` now (stated in Design notes), so the file still
  parses once the parameter is typed.
- Green: `UIKit.stat(parent, role: StringName = &"TEXT")`, always painted. Refactor: `with_temp_settings(body, path)`
  moved into `test_case.gd` (three copies: day mode, start screen, this file). Suite 1191 → 1195. No UI-visible
  change, so no manual check.
