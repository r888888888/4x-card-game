---
id: 178
title: Night shift palette, typefaces and machined controls
type: feature
status: review
branch: feat/178-night-shift-theme
---

## Goal
The game takes on the mid-century style guide's look ([docs/design/mcm-style-guide.md](../design/mcm-style-guide.md),
§4–§6, §15.1–15.2): the warm Night shift palette, the guide's typefaces with fixed-width figures, and buttons that read
as physical keys: square-ish, standing on a hard shadow and sinking into it when pressed. All of it lives in `Palette`
and `GameTheme`, so every screen changes at once. Proven in the `spike/mcm-godot` spike.

## Acceptance criteria
- [x] AC1: The palette holds the guide's Night shift values: `BACKGROUND` 1f1e1c, `RAISED` and `TILE` 2a2825, `FIELD` and
  `PANEL` 171614, `CONTROL` 3a3733, `CONTROL_BORDER` 857d70, `CONTROL_DISABLED` 171614, `CONTROL_DISABLED_BORDER`
  4a463f, `TEXT` ede6d6, `TEXT_DIM` b9b1a1, `TEXT_DISABLED` 8e877a, `ACCENT` e0703f, `TEXT_ON_ACCENT` 1f1e1c, `GAIN`
  93b585, `COST` and `WARN` e07a63, `FOCUS` 6cc3bc, `WEALTH` d9a441, `INSIGHT` 86a9cc, `UNREST` e07a63, `POP` 5fb0a9,
  `SHADOW` 0d0c0b (opaque), `EDGE` ede6d6; card types `ACTION` 86a9cc, `BUILDING` a9b26c, `CITY` d9a441, `TERRITORY`
  93b585, `TECH` 5fb0a9, `EVENT` e07a63. `test_theme`'s "looks as before" guard (106) is rewritten to these values.
- [x] AC2: The theme's default font is Barlow Regular; buttons use Barlow Semi Condensed Medium (the `AccentButton`
  SemiBold); `Stat` and `BarStat` labels Barlow Semi Condensed SemiBold; `Title` and `Link` Jost at weight 500. Every
  one is a `FontVariation` with the OpenType features `tnum` and `lnum` on, and the font files sit in `assets/fonts/`
  with their SIL OFL licence texts.
- [x] AC3: A `Button`'s normal box has fill `CONTROL`, a 2 px `CONTROL_BORDER` border, corner radius 2, content margins
  14 × 6, and a hard shadow: colour `SHADOW`, offset (2, 2), shadow size 1, anti-aliasing off. Hover: fill `CONTROL`
  lightened 8%, border `TEXT`, the same shadow. Disabled: fill `CONTROL_DISABLED`, border `CONTROL_DISABLED_BORDER`,
  shadow size 0.
- [x] AC4: The `pressed` and `hover_pressed` boxes sit 2 px down and right in their shadow: shadow size 0, expand
  margins left and top −2, right and bottom +2, and content margins 16, 8, 12, 4 (left, top, right, bottom), so the
  box and its label move together. The same holds for `AccentButton`.
- [x] AC5: `AccentButton` (End turn) has fill `ACCENT` (signal orange) with a `TEXT` border and `TEXT_ON_ACCENT` label,
  and is the only variation using `ACCENT` as a fill.
- [x] AC6: Panels are cut square: the overlay and modal panel (`DarkPanel`), the log's panel and every
  `UIKit.panel_style` box have corner radius 0; the focus ring is `FOCUS`, 2 px wide, radius 0, 4 px outside the
  control.

## Out of scope
- Card faces, card shadows and card motion (179); glyphs and costs (180); the Paper (light) mode; the left rail and
  title blocks.

## Design notes
- `GameTheme._box` gains the shadow; a `_pressed(box)` helper adds the press travel (negative expand margins on the
  top and left, positive on the bottom and right, moved content margins), as the spike did. Godot styleboxes can't
  translate, but this moves the drawn box and its text without a tween.
- Fonts: Barlow, Barlow Semi Condensed, Jost (variable) and IBM Plex Mono from github.com/google/fonts (OFL), about
  0.8 MB. Plex Mono is for 181's odometer and isn't used yet; it can land there instead.
- `test_theme`'s 106 guard pinned the old look on purpose; this item is the deliberate change it guards against, so
  its expected values change with AC1–AC6 rather than the guard being dropped.
- Contrast for these values is computed in the guide's §12.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_theme::test_the_palette_holds_the_night_shift_values`, `test_labels_look_as_before`, `test_fields_and_card_colours_look_as_before` (106's guard, rewritten) |
| AC2 | `test_theme::test_the_theme_uses_the_guides_typefaces`, `test_the_fonts_ship_with_their_licences` |
| AC3 | `test_theme::test_buttons_stand_on_a_hard_shadow` |
| AC4 | `test_theme::test_a_pressed_button_sinks_into_its_shadow` |
| AC5 | `test_theme::test_the_accent_button_is_signal_orange`, `test_only_the_accent_button_is_filled_with_the_accent` |
| AC6 | `test_theme::test_panels_are_cut_square`, `test_the_focus_ring_is_square_and_outside_the_control` |

## Manual check
- [ ] Seed 5, Egypt: the board, the menu, the tech tree, the supply screen, a modal and the game-over sheet all read in
  the Night shift colours, with no leftover cool-grey or white controls.
- [ ] Pressing a button sinks it 2 px into its shadow and it comes back on release; disabled buttons lie flat.
- [ ] Figures in the top bar don't shift sideways when a value goes from 9 to 10.

## Log
- 2026-10-01: Specced from the mid-century style guide and the `spike/mcm-godot` spike.
- 2026-10-02: Built from the spike's palette and `GameTheme` (`tabular()`, `display()`, `_pressed()`, `_flat()`),
  fonts Barlow Regular, Barlow Semi Condensed Medium and SemiBold and Jost (variable) with their OFL texts; IBM Plex
  Mono is left to 181. Decided at the red checkpoint: label sizes stay (19 / 26 / 26, BarStat 20); Title and the
  Stat default are `TEXT` rather than white; `EDGE` is opaque, so the overlay frame is 2 px; `FAINT_EDGE` (the log's
  border) keeps its value. Also swapped the last white defaults for `TEXT` (card face labels, `UIKit.stat`, the
  GrowPip and a hovered card's border). Not tuned: the see-through layers (`DIMMER`, `GHOST_*`, `DROP_BG`, `HINT_BG`)
  keep their cool values; 183 revisits them for Day mode.
