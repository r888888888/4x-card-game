---
id: 193
title: Spacing and corner radius come from the guide's scales
type: feature
status: in-progress
branch: feat/193-spacing-and-radius-tokens
---

## Goal
Colour is tokenized and guarded (106, 178); spacing and corner radius are not. `ui/` passes about 50 numeric
literals to separations, margins, content margins and corner radii, 12 distinct separation values, several off the
guide's 4 px scale (3, 6, 10, 14, 22, 28, 36), and radii the guide forbids (6, 8, 10: "nothing between 6 and 24 px").
New code copies whatever literal is nearby, so the drift grows. After this, every spacing and radius on screen is a
step of the guide's scale (docs/design/mcm-style-guide.md §6.1, §6.3), named after the guide's token, and the suite
fails on a new literal. The user chose to snap to the guide's values (a visible change), not just name today's.

## Acceptance criteria
- [ ] AC1: Given the token constants, then `SPACE_0`…`SPACE_9` are 0, 4, 8, 12, 16, 24, 32, 48, 64, 96 and `RADIUS_0`,
  `RADIUS_1`, `RADIUS_2` are 0, 2, 4 and `RADIUS_FULL` is 9999 (the guide's `radius.full`) and `GLYPH_GAP` is 3 (§6.7); and `UIKit.SECTION_GAP` is 24, `UIKit.CARD_GAP` 12, `UIKit.HEADING_GAP` 8
  (§6.1: "SECTION_GAP 22, CARD_GAP 10 become 24 and 12").
- [ ] AC2: Given a mid-game board (seed 5, turn 3) and, in turn, each screen and modal open on it (supply, tech tree,
  card details, identity, event, game menu, settings, new game, game over, start), when every visible container is
  walked, then each `separation`, `h_separation`, `v_separation` and `margin_*` constant it resolves is on the space
  scale or is `GLYPH_GAP`; the failure names the node path, the constant and the value.
- [ ] AC3: Given the same screens, when every visible control's `panel` / `normal` stylebox that is a `StyleBoxFlat`
  is read, then its corner radius is 0, 2 or 4, or half its control's smaller side (a pip, `radius.full`), and its
  four content margins are on the space scale. Pressed and hover-pressed boxes are exempt (press travel shifts them
  by `GameTheme.PRESS`).
- [ ] AC4: Given the drop zone lit during a drag, the drag hint, the error pop-up (`UIKit.show_error`) and an empty
  slot outline (`UIKit.slot_outline`), then each stylebox's corner radius is 0 (§6.3: zones, tooltips and cards are
  cut square).
- [ ] AC5: Given every `ui/` script except the one defining the tokens, when its source is scanned, then no call to
  `add_theme_constant_override` for a separation or margin, `set_content_margin_all`, `content_margin_* =`,
  `set_corner_radius_all` or `set_corner_radius` passes a numeric literal other than 0; the failure lists `file:line`.

## Out of scope
- Border widths (`border.*`), shadows (already tokens: `GameTheme.PLINTH`, `PRESS`), the 12-column grid and the
  8 px baseline (§6.2), and motion distances in `Anim` (`HOVER_LIFT`, `LIFT_ROOM`, … are travel, not spacing).
- Font sizes: item 194.
- Layout changes beyond snapping a value to its step (no new rail, no title block).

## Design notes
- Where: a new `ui/tokens.gd` (`class_name Tokens`, constants only), or constants on `GameTheme` beside `PLINTH`.
  Recommendation: `Tokens`, named exactly as the guide (`Tokens.SPACE_2`, `Tokens.RADIUS_1`) so a model reading the
  guide finds them by name; `UIKit`'s role aliases (`SECTION_GAP`, …) stay and point at them.
- Snapping: each literal goes to its nearest step; a tie goes up (6→8, 10→12, 14→16, 22→24, 28→32, 36→32, 3→4).
  Inside a control the guide says `space.2` vertical × `space.4` horizontal, so the button box (`_box`, 14×6 today)
  becomes 16×8 and `GrowPip` 10/12×2 becomes 12×4 (or 8×0 if the pip row grows too tall: judge by eye).
  The card badge (radius 4, `radius.2`: "badges and keycaps") keeps 4; the dimmed card's reason strip (4) becomes 0.
- Values derived from tokens are fine (`HOVER_LIFT + SPACE_2` is 16). `Counter.TAG_GAP` becomes a token.
- 0 stays a legal literal in AC5 (no gap is not a design decision).
- Snapping the button box from 14×6 to 16×8 widens the top bar's six buttons by 4 px each; the bar is tight at
  1920 px (144). If it no longer fits, say so in the Log rather than shrinking the tokens.
- Approved guards that change: `test_theme`'s button content margins (14×6). Rewrite them to the new values as
  this item's stated change, as 178 did.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_spacing_tokens::test_the_tokens_hold_the_guides_scales`, `test_the_board_gaps_are_on_the_scale` |
| AC2 | `test_spacing_tokens::test_every_spacing_on_screen_is_on_the_scale` |
| AC3 | `test_spacing_tokens::test_every_box_on_screen_has_a_radius_and_margins_on_the_scales` |
| AC4 | `test_spacing_tokens::test_drop_zone_hint_error_and_slot_outline_are_square` |
| AC5 | `test_spacing_tokens::test_no_ui_script_passes_a_spacing_or_radius_literal` |

## Manual check
- [ ] The board at 1920×1080 in both Night and Day: the top bar still fits, the hand and Realm rows don't clip a
  hovered card, the territory view's pop meter row isn't taller than before.
- [ ] Each screen and modal from AC2: nothing overlaps or clips; the drag hint and error pop-up read as square tags.

## Log
- Specced from the design-system review (2026-10-02). The user chose to snap values to the guide.
- Red: AC1 gained `RADIUS_FULL` (9999, the guide's `radius.full`): the pips' `PIP_SIZE / 2` is a literal under AC5,
  and a token is the honest fix. The screen walk (AC2, AC3) also covers the log drawer, and the board's outer margin
  (18, `board_layout.gd:67`), which the spec's inventory missed. Default container constants (4) are on the scale.
- Red: `test_theme`'s button and field padding goes from 14x6 to 16x8 (`test_buttons_stand_on_a_hard_shadow`,
  `test_the_accent_button_is_signal_orange`, `test_fields_and_card_colours_look_as_before`), and the pressed box's
  margins from [16, 8, 12, 4] to [18, 10, 14, 6] (`check_sunk`, used by `test_a_pressed_button_sinks_into_its_shadow`),
  as the Design notes state.
- Green: `test_resource_glyphs` pins a cost's glyph-to-figure gap at 3 px, which the guide sets itself (§6.7) against
  its own scale rule (§6.1). The user chose to keep 3 px: `Tokens.GLYPH_GAP`, accepted by the screen walk (AC1, AC2
  amended), and item 180's test is unchanged.
- Green: AC5's call list misses `UIKit.panel_style`'s padding argument; the screen walk caught the tech tree tiles'
  6, and four more callers (dark panel 24, log 12, territory frame 18, tiles 6) now pass tokens. Follow-up: add
  `panel_style(` to AC5's calls so a literal padding fails statically too (the territory view isn't in the walk).
- Refactor: docs (CLAUDE.md, PLAN.md, docs/design/tokens.md) and `UIKit.panel_style`'s stale "round corners".
  The top bar still fits 1920 px (`test_board_layout::test_top_bar_controls_are_on_screen_and_buttons_fit_their_text`).
- Follow-up: `Counter.GLYPH_GAP` (6, a `custom_minimum_size` gap in the top bar's counters) shares a name with
  `Tokens.GLYPH_GAP` (3) and is off the scale; minimum-size gaps aren't covered by AC5. Worth a small item with the
  `panel_style(` gap above.
