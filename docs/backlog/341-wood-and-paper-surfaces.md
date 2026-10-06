---
id: 341
title: Wood grain under the board and paper cards and modals (texture option G)
type: feature
status: red-review
branch: feat/341-wood-and-paper-surfaces
---

## Goal
The desk looks made of real materials without changing its design: faint walnut grain under the board and the top
bar, and every card and modal printed on paper (dark gray paper in Night, white paper in Day), resting on soft
shadows. This is option G of the texture spike (`spike/textures`, `docs/design/mocks/texture-options.html#g`), which
the user chose. Every colour stays its Palette role; the textures sit under those colours. The game and the design
docs both change, so the specimen keeps drawing what the game does.

## Acceptance criteria
"Grain under C at N %" means `walnut.png`, tiled, with the Palette colour C laid over it at N % opacity.
"Night paper" is `dark-gray-paper.png` under black at 30 %; "Day paper" is `white-paper.png` as it is.

- [ ] AC1 (board): Given a game on the board, the board behind everything (main's background) and the Rail show grain
  under BACKGROUND at 90 % in Night and 88 % in Day. The Rail's grain lines up with the board's (both tile from the
  screen's origin), so nothing marks the Rail's edge but its 1 px hairline, which stays.
- [ ] AC2 (top bar): Given either mode, the Strip shows grain under RAISED at 90 % (Night) or 88 % (Day) and keeps its
  3 px TEXT rule along its foot. Its keys keep today's flat look (CONTROL fill, CONTROL_BORDER rule, hard 2,2 plinth):
  no texture on any Button.
- [ ] AC3 (cards): Given Night, every card view (hand, Realm, supply, a modal's card) shows Night paper; given Day,
  Day paper. Its border colours by state are unchanged (CONTROL_BORDER at rest, TEXT hovered or dragged, WARN, FOCUS
  above the vellum, the highlight). A dimmed card shows the same paper under DIM_BG at 60 %, with DIM_BORDER. A frontier
  card is unchanged: no paper, its hatching and dashed rule on the board.
- [ ] AC4 (modals): Given either mode, every Sheet panel (each `Modal`) and every DarkPanel (each `UIKit.overlay`)
  shows the same paper as a card in that mode, and keeps its border (a 2 px TEXT rule on a Sheet; a DarkPanel's role
  colour).
- [ ] AC5 (soft shadows): A card's shadow is SHADOW, soft (anti-aliased, blurred) and straight down: at rest offset
  (0, 4), size 8, alpha 0.35 (Night) / 0.20 (Day); hovered (0, 8), size 16, alpha 0.45 / 0.28; dragged (0, 14),
  size 24, alpha 0.50 / 0.32. A Sheet's and a DarkPanel's shadow is SHADOW at (0, 16), size 32, alpha 0.55 (Night) /
  0.35 (Day). Keys, flags and the End turn key keep their hard plinths.
- [ ] AC6 (Day mode switch): Given a game in progress with a modal open, when Day mode is switched on and then off, the
  board, the Rail, the Strip, every card view and the open modal show that mode's grain, paper and shadow alphas
  (AC1–AC5) right away, with nothing reopened; the game state is unchanged.
- [ ] AC7 (contrast): In both modes, on the mean colour of each surface as drawn (board, Strip, card, Sheet), TEXT and
  TEXT_DIM read at 4.5:1 or more; on the card surface, CONTROL_BORDER, GAIN, WEALTH, INSIGHT, UNREST and POP read at
  3:1 or more (the bars `test_day_mode` already holds RAISED and BACKGROUND to).

## Out of scope
- Paper on other sheet-coloured surfaces: notification flags, tooltips, Knowledge tech tiles, the start screen's big
  buttons, list rows, the era vellum, the territory view's panel. They stay flat; a later item can extend paper.
- Grain on navigated screens' own fills (Knowledge, supply, territory) and on the start and new-game screens.
- Brass, oak and the blue dark paper from the spike; any textured key.
- A setting to turn textures off.
- Balance: none.

## Design notes
- **Assets.** Commit `walnut.png`, `dark-gray-paper.png` and `white-paper.png` (1254 × 1254 tiles) under
  `assets/background/` with their `.import` files. The spike's other textures (oak, brass-1, brass-2, dark-paper) are
  only for the mock: move them to `docs/design/mocks/textures/` behind a `.gdignore` so Godot doesn't import them, and
  point the mock page at that folder.
- **Tile scale** (the mock's, at the game's 1920 × 1080): walnut drawn at 960 px per tile (×0.77), paper at 700 px
  (×0.56). Tuned by eye under Manual check, not tested.
- **Godot.** A `StyleBoxFlat` draws no texture and a `StyleBoxTexture` draws no shadow or overlay colour, so each
  surface needs both. One way: a `Surfaces` script in `ui/` that bakes each mode's veiled textures once (the Image with
  the Palette colour blended over it, cached per mode and rebuilt on `Palette.use`) and hands out tiled
  `StyleBoxTexture`s for BOARD, STRIP, PAPER and DIMMED_PAPER; cards and sheets draw their soft shadow from a
  `StyleBoxFlat` behind the paper. The rest of the UI keeps asking the theme and `UIKit.painted` as today.
- **Palette.** The opacities (90 / 88 %, 60 %, the shadow alphas) are numbers, not colours: name them as constants
  where they're used. Night paper's black needs a colour role (e.g. `PAPER_SHADE`: black at 30 % in Night,
  transparent in Day) in both sets, since `ui/` may not write a colour literal.
- **Tests this supersedes** (deliberate design changes, rewritten by this item's criteria, not weakened):
  `test_card_faces::test_a_card_at_rest_has_no_shadow_and_a_lifted_one_a_hard_one` (AC5), the hard 8,8 shadow checks
  in `test_modal_sheets.gd` (AC5), and any `test_theme` / `test_day_mode` check that reads a card's, the Strip's, the
  Rail's or a sheet's fill as a flat `bg_color` (AC1–AC4, AC6).
- **Script size.** `card_view.gd` (539 lines) and `game_theme.gd` (555) are past the 500-line warning; keep the
  surface code in its own script rather than growing them.
- **Docs to update** (the item isn't done until they match the game):
  - `docs/design/mcm-specimen.html`: the board, Cards and Feedback (modal) sections draw the grain, paper and soft
    shadows in both modes, with the textures loaded from `../../assets/background/`.
  - `docs/design/tokens.md`: a Surfaces row in "Where things live", the paper and grain in the colour-role table,
    and the new shadow values in the shadows table.
  - `docs/design/mcm-style-guide.md`: §6.5 Shadows (soft card and sheet shadows; keys keep the hard plinth) and a
    short note on surfaces (grain under the board and bar, paper for cards and modals) in §4.1 Neutrals.
  - `docs/design/index.html`: bring `mocks/texture-options.html` over from `spike/textures`, with its row marked
    **Built**: option G, item 341.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
Means and contrast come from `tests/lib/surface_looks.gd` (a surface's texture mean vs. the criteria's veil over the
source PNG's mean, and that grain still shows).

| AC | Test |
|---|---|
| AC1 | `test_surfaces::test_the_board_and_the_rail_show_grain_under_the_background`, `test_surfaces::test_the_rails_grain_lines_up_with_the_boards`, `test_sidebar::test_the_rail_is_open_on_the_board_with_a_hairline_to_its_left` (rewritten) |
| AC2 | `test_surfaces::test_the_strip_shows_grain_under_raised_and_keeps_its_rule`, `test_surfaces::test_no_key_on_the_board_is_textured`, `test_sidebar::test_the_top_bar_sits_on_a_full_bleed_strip_ruled_underneath` (rewritten) |
| AC3 | `test_card_faces::test_every_card_at_rest_is_a_paper_sheet_in_a_thin_rule`, `test_card_faces::test_a_dimmed_card_uses_the_dim_colours`, `test_card_faces::test_a_frontier_card_has_no_paper`, `test_card_faces::test_the_border_shows_hover_drag_warning_and_target` (unchanged) |
| AC4 | `test_surfaces::test_a_modal_sheet_is_paper_on_a_soft_shadow`, `test_surfaces::test_an_overlay_panel_is_paper_in_its_role_colour_on_a_soft_shadow`, `test_modal_sheets::check_sheet` (rewritten), `test_settings_modal::test_a_setting_applies_at_once_and_esc_closes_only_the_settings_modal` (rewritten) |
| AC5 | `test_card_faces::test_a_cards_soft_shadow_grows_as_it_lifts_in_both_modes` (replaces `test_a_card_at_rest_has_no_shadow_and_a_lifted_one_a_hard_one`), the two `test_surfaces` sheet tests above; keys' hard plinths: `test_surfaces::test_no_key_on_the_board_is_textured`, `test_theme`, `test_end_turn_key`, `test_notification_flags` (unchanged) |
| AC6 | `test_surfaces::test_day_mode_switches_every_surface_with_a_modal_open`, `test_day_mode::check_look`, `test_open_modals_and_screens_switch_and_stay_open`, `test_the_settings_modal_switches_and_stays_open`, `test_bug_195_a_game_started_in_day_mode_shows_the_board_in_paper` (rewritten) |
| AC7 | `test_surfaces::test_text_and_hues_keep_their_contrast_on_each_surface` |

## Manual check
- [ ] Night and Day, at 1920 × 1080: the walnut grain is just visible under the board and the bar; no tile seams; the
  Rail's edge shows only its hairline.
- [ ] Cards and modals read as paper; the hand stands clear of the board in both modes; a dimmed card still reads as
  dimmed.
- [ ] Tile scales (walnut ×0.77, paper ×0.56) look right; adjust if the grain is too coarse or too fine.
- [ ] Hover and drag a card: the soft shadow grows; End turn and the keys still press into a hard plinth.
- [ ] The specimen's board and modal match the running game in both modes.

## Log
<!-- Decisions and surprises during implementation, newest last. -->
- Spec: paper limited to cards and modals (user's choice); soft shadows as in option G (user's choice), replacing the
  guide's hard lift and sheet shadows for cards and modals only.
