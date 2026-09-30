---
id: 097
title: Evaluate ThemeGen for the UI theme
type: feature
status: draft
branch: feat/097-themegen-theme
---

## Goal
The UI theme is built in code today (`UIKit.style_controls` and the colour constants in `ui/ui_kit.gd`). ThemeGen
(https://github.com/Inspiaaa/ThemeGen, MIT) lets us define the theme in a GDScript file with reusable styles
and shared colours, and previews it live in the editor. Try it and adopt it only if the theme gets easier to
change without changing how the board looks.

## Acceptance criteria
<!-- UI-only: no engine behaviour changes. -->
- [ ] AC1: Given ThemeGen installed under `addons/`, when the suite runs, then it stays green and
  `test_ui_smoke` and `test_ui_structure` pass unchanged.
- [ ] AC2: Given the generated theme, when the board opens, then every `Button` and `AccentButton` has
  `normal`, `hover`, `pressed` and `disabled` styleboxes (the looks `style_controls` sets today).
- [ ] AC3: Given the colour constants `UIKit` exports (`ACCENT`, `COST_COLOR`, `GAIN_COLOR`, `PANEL_COLOR`), when
  the theme is generated, then it takes those colours from one shared source rather than a second copy.

## Out of scope
- Redesigning the look. The first pass reproduces today's theme.
- Card faces (`card_face.gd`) unless they already read from the theme.

## Design notes
- Check that ThemeGen works on Godot 4.7 before anything else. If it doesn't, close as `wontfix`.
- The addon lives in `addons/`, so it's exempt from the 700-line limit, which covers `engine/` and `ui/` only.

## Open questions
- Keep the generated `.tres` in the repo, or regenerate it at startup? Recommendation: commit it, so the game
  doesn't depend on the editor plugin at runtime.
- Adopt fully, or spike on a branch and decide from the diff? Recommendation: spike first, and record the
  verdict in the Log.

## Test plan
| AC | Test |
|---|---|

## Manual check
- [ ] Before/after screenshots of the start screen, board, supply screen and a modal look the same.
- [ ] Editing a colour in the ThemeGen script updates the editor preview.

## Log
