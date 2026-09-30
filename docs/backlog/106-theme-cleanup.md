---
id: 106
title: One palette and theme variations for the UI's colours and looks
type: feature
status: done
branch: feat/106-theme-cleanup
---

## Goal
Changing how the UI looks means hunting through `ui/` today: 54 `Color(...)` literals in 13 files, the dark overlay
panel (`262b31`) rebuilt in four places, and headings, titles and stats styled by per-label overrides. Put every UI
colour in one palette and every repeated look in the Theme `main` already builds in code, as Godot theme type
variations, so a colour or a look changes in one place. Nothing on screen changes. (The in-house alternative to
ThemeGen, 097.)

## Acceptance criteria
<!-- Structure tests over ui/*.gd (tests/test_ui_structure.gd) and theme tests (tests/test_theme.gd). -->
- [x] AC1: Nothing looks different. A test written first against today's code records the resolved look of: a
  heading, a title, a stat, an overlay panel's background and border, the side panel's log panel, a Button and the
  AccentButton (normal, hover, pressed, disabled: background, border, font colour), a LineEdit, a card's type colour
  per card type, and the focus ring. It passes before and after this item, unchanged.
- [x] AC2: One palette. `ui/palette.gd` (`class_name Palette`) names every UI colour as a constant (e.g.
  `Palette.PANEL`, `Palette.TEXT`, `Palette.TEXT_DIM`, `Palette.ACCENT`, `Palette.COST`, `Palette.GAIN`, and the card
  type colours). No `.gd` file in `ui/` other than `palette.gd` contains a `Color(` or `Color8(` constructor with
  literal arguments or a hex string; named engine colours (`Color.WHITE`, `Color.TRANSPARENT`) and
  `.lightened()`, `.darkened()`, `with_alpha`-style derivations of palette colours are allowed.
- [x] AC3: One theme. `ui/game_theme.gd` (`class_name GameTheme`) has `static func build() -> Theme`, which `main`
  uses as its theme. Besides today's Button, AccentButton and LineEdit styles, it defines the type variations
  `Heading` (Label), `Title` (Label), `Stat` (Label) and `DarkPanel` (PanelContainer), each with the items it needs
  (font size and colour; the panel stylebox).
- [x] AC4: Components use the variations. `UIKit.heading()`, `UIKit.title()` and `UIKit.stat()` return labels with
  `theme_type_variation` set to `Heading`, `Title` and `Stat` and no font size or font colour override (a stat keeps
  its own colour override: each stat is coloured by what it counts). The overlay, tech tree and event modal panels
  use `DarkPanel` instead of their own `panel_style(Color("262b31"), …)` stylebox.
- [x] AC5: `UIKit.style_controls` and `UIKit.panel_style`'s colour arguments move into `GameTheme` / `Palette`;
  `UIKit` keeps only layout helpers and constants (gaps, sizes). `test_ui_structure` lists `Palette` and
  `GameTheme` as components.

## Out of scope
- Layout constants (separations, margins, sizes): they stay where they are.
- Card faces' font sizes (`CardFace.label(text, size, colour)`): they vary per line on purpose. Their colours move
  to the palette under AC2.
- Any change to how things look, or a light theme (a later item could add one: a second palette, the same theme).

## Design notes
- UI only. The theme is still built in code at startup (097: no editor-generated `.tres`), so it can't go stale.
- AC1 is the safety net: write it in the red phase and confirm it passes on `main` before refactoring (it is a guard,
  not a failing test); the new tests for AC2–AC5 are the red ones.
- The palette names what a colour is for (`TEXT_DIM`, `PANEL`), not its hue, so a later light theme can swap values.
- Colours derived at run time from a palette colour (`CardView`'s dimmed border, `fill.lightened(0.15)`) stay derived.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 (guard) | `test_theme::test_labels_look_as_before`, `test_panels_look_as_before`, `test_buttons_look_as_before`, `test_fields_and_card_colours_look_as_before` |
| AC2 | `test_no_colour_literals_outside_the_palette`, `test_the_palette_names_the_ui_colours` |
| AC3 | `test_game_theme_builds_the_controls_and_variations`, `test_main_uses_the_game_theme` |
| AC4 | `test_ui_kit_labels_use_the_variations`, `test_overlay_panels_use_dark_panel` |
| AC5 | `test_ui_kit_no_longer_builds_the_theme`; `test_ui_structure` lists `Palette` and `GameTheme` |

## Manual check
- [ ] Before/after screenshots (title screen, board on seed 1, the menu, Buy Cards, Knowledge, a card's details, the
  event modal) look identical.
- [ ] Change `Palette.ACCENT` to a different colour and run the game: End turn and every accent use it; change it
  back.

## Log
- 2026-09-30: Specced after closing 097 (ThemeGen) as wontfix: the goal of an easier-to-change theme is met in code.
- 2026-09-30: Built. `ui/palette.gd` (46 named colours: surfaces, text, meaning, dimmed cards, card types, tech
  states, see-through layers) and `ui/game_theme.gd` (`build()`, `dark_panel(border)`, `focus_ring()`; the old
  `UIKit.style_controls` and `focus_ring` moved here). `UIKit.heading/title/stat` set the variations; `UIKit.overlay`
  uses `DarkPanel` and only overrides its stylebox for a coloured border (explore, research, supply, errors, the
  event modal). Existing constants (`CardView.TYPE_COLORS`, `WARN_COLOR`, `HIGHLIGHT_COLOR`, `FOCUS_COLOR`,
  `TopBar.FOOD_COLOR`, `UIKit.COST_COLOR` / `GAIN_COLOR`, `CardFace.STRIP_*`) are aliases of palette entries.
  `UIKit.ACCENT` and `UIKit.PANEL_COLOR` are gone (only the theme used them). CLAUDE.md's UI design section names
  the rule.
