---
id: 194
title: Text sizes come from the guide's type scale
type: feature
status: review
branch: feat/194-type-scale-tokens
---

## Goal
Text sizes are literals scattered through `ui/`: card faces use 15, 16, 17, 18, 19 and 22; three modals and the log
repeat 19 for their body text; the start screen sets 40, game over 32, the identity modal `[font_size=30]` in
BBCode. Several aren't on the guide's scale (§5.2), and the theme's own Heading (19) and Title (26) differ from the
guide's 15 and 28. After this, every size on screen is a step of the guide's type scale, the repeated looks are
theme variations, and the suite fails on a new literal size. The user chose to snap to the guide's values.

## Acceptance criteria
- [x] AC1: Given the theme, then it has Label variations named for the guide's roles at its sizes: `Display` 40,
  `Title` 28, `Heading` 15, `Body` 20, `BodySmall` 17, `Caption` 14, `Stat` 26 (numeral), and a RichTextLabel
  variation `RichBody` whose normal, bold and italics sizes are 20. `Title` and `Display` use the display face
  (`GameTheme.display()`), `Heading` the semibold label face.
- [x] AC2: Given `UIKit.heading("The realm")` in the main scene, then the label shows the text in capitals
  (`uppercase` on, its `text` unchanged) at 15 px, with positive letter spacing (§5.3: caps are tracked +10%,
  1–2 px at 15).
- [x] AC3: Given a mid-game board (seed 5, turn 3) and, in turn, each screen and modal open on it (supply, tech tree,
  card details, identity, event, game menu, settings, new game, game over, start), when every visible Label, Button,
  LineEdit and RichTextLabel is walked, then each resolved font size (`font_size`, and a RichTextLabel's
  `normal_font_size` / `bold_font_size` / `italics_font_size`) is one of 14, 15, 17, 20, 26, 28, 40, 44, 56; the
  failure names the node path and size.
- [x] AC4: Given a hand card, a tableau card, a dimmed card with its reason strip and a territory card on that
  board, then every text size on each face is on the scale (AC3's set).
- [x] AC5: Given every `ui/` script except `game_theme.gd`, when its source is scanned, then no
  `add_theme_font_size_override`, `set_font_size`, or call to `CardFace.label` / `CardFace.rich_label` /
  `UIKit.fx_label` passes a numeric literal, and no string contains `[font_size=`; the failure lists `file:line`.

## Out of scope
- Case and tracking for roles other than Heading (Display and label-caps are uppercase in the guide; do that in a
  later item if the user wants it), line heights, and IBM Plex Mono for `numeral-xl` (not shipped).
- Spacing and radius: item 193.
- Card face layout beyond the size change (if a face no longer fits, note it in the Log; don't shrink the scale).

## Design notes
- Sizes are named in the token file from 193 (`Tokens.TYPE_BODY` = 20, …) so callers that need a number
  (`CardFace.label`, `Icons.fill`, `UIKit.fx_label`) pass a token, not a literal.
- Mapping (nearest step; a tie goes up): theme Heading 19→15 (caps), Title 26→28, `Link` 26→28, BarStat 20 stays
  (body; the bar fits 1920 px at 20, 144), body RichTextLabels 19→20 (card details, identity, log, territory info:
  use `RichBody`), card face title 22→20, rules 19→20, subtitle and VP 18→17, keywords 17, badge 15→14
  (label-caps), the details info line 16→17, legend key 16→14 (label-caps: lamp labels), toasts 22→20, drag hint
  19→20, game over 32→40 (display), the identity modal's BBCode heading 30→28 (use a `Title` label, not BBCode),
  start screen 40 (display; use the variation).
- Heading at 15 in lower case would read as a footnote; that's why AC2 brings caps and tracking with it. Tracking is
  a `FontVariation.spacing_glyph` on the Heading font.
- Approved guards that change: `test_theme::test_labels_look_as_before` (Heading 19, Title 26) and any test pinning
  a card face size. Rewrite them to the new values as this item's stated change, as 178 did.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_type_tokens::test_the_tokens_hold_the_guides_type_scale`, `test_the_theme_has_a_label_variation_per_type_role` |
| AC2 | `test_type_tokens::test_a_heading_is_capitals_at_15_tracked` |
| AC3 | `test_type_tokens::test_every_text_size_on_screen_is_on_the_scale` |
| AC4 | `test_type_tokens::test_every_text_size_on_a_card_face_is_on_the_scale` |
| AC5 | `test_type_tokens::test_no_ui_script_passes_a_literal_text_size` |

## Manual check
- [ ] Card faces in hand and on the tableau, both modes: the name fits on one line for the longest card names, rules
  text doesn't overflow a hand card, the reason strip reads.
- [ ] Section headings ("THE REALM", "IN HAND") read as labels, not footnotes; the top bar still fits 1920 px.
- [ ] Each screen and modal from AC3 at 1920×1080.
- [ ] `godot --path . -- --civ sumer --turns 20 --seed 5`: game over reads as a display line (Jost, 40); the identity
  modal (top bar's civilization button) shows each name as a title over its text; the log reads at 20.

## Log
- Specced from the design-system review (2026-10-02). The user chose to snap values to the guide. Depends on 193
  (the token file).
- Red: AC1 also checks `Tokens.TYPE_*` (the Design notes' token constants), named as the guide's type tokens
  (`TYPE_BODY`, `TYPE_LABEL_CAPS`, …). `mid_game`, `each_screen` and `visible_controls` moved from
  `test_spacing_tokens` / `test_day_mode` into `test_case.gd` (shared with 193's walk). `test_theme::test_labels_look_as_before`
  changes Heading 19 → 15 and Title 26 → 28, as the Design notes state. AC5 flags 41 lines today (literal sizes in
  calls that take a size, and the identity modal's `[font_size=30]`).

- Green: `Tokens.TYPE_*`; GameTheme's Display, Body, BodySmall, Caption and RichBody variations, Title 28, Heading 15
  (`heading_font()`: SemiCondensed SemiBold, `spacing_glyph` 2), Link 28; `UIKit.heading` sets `uppercase`. Every
  literal size replaced per the Design notes' mapping; the cost figure stays 20 (`TYPE_BODY`, already on the scale).
  The identity modal's `[font_size=30]` names became `Title` labels over a `RichBody` per section; `body_text()`
  returns the same text as before, so its tests are unchanged. Game over is a `Display` label (it was a 32 px
  Heading). No card face test broke (names still fit).
- Green: `UIKit.title` was built on `heading`, so titles caught the capitals; a new test
  (`test_a_title_keeps_its_case`) failed first, and `title` now builds its own label. Display isn't in capitals
  either (the Out of scope's case for other roles).
- Verify: suite 1204 → 1211, green with a clean `HOME` and the player's Day mode on; headless launch: 0 errors.
