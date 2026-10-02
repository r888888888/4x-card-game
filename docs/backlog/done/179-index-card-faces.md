---
id: 179
title: Index-card faces and machined card motion
type: feature
status: done
branch: feat/179-index-card-faces
---

## Goal
Cards look like the guide's index cards ([docs/design/mcm-style-guide.md](../design/mcm-style-guide.md) §6.7, §15.6):
one sheet face for every type in a thin rule frame, the type shown by a coloured band under the name, a hard
shadow only when lifted. And they move like mechanisms: they slide, they don't grow, wobble or bounce. Today a card
is tinted by its type, grows 8% on hover, tilts up to 12° while dragged and squashes when it lands, which is what makes
the board feel like an app.

## Acceptance criteria
- [x] AC1: Given any card at rest (hand, Realm, territory, supply), its panel has fill `Palette.RAISED`, a 2 px
  `Palette.CONTROL_BORDER` border and corner radius 0, whatever its type; a dimmed card has fill `DIM_BG` and border
  `DIM_BORDER`; the border is `TEXT` while hovered or dragged, `WARN` with a warning, and `GAIN` 3 px wide when
  highlighted as a target.
- [x] AC2: Directly below the card's name sits a 5 px band in the card's type colour (`CardView.TYPE_COLORS`), on hand,
  tableau and board faces; a dimmed card's band is `DIM_BORDER`; an unsettled frontier territory has none (it keeps its
  hatching and dashed border).
- [x] AC3: A card at rest has no shadow; a hovered hand card has a hard shadow (colour `SHADOW`, offset (4, 4), shadow
  size 1); a dragged card's offset is (8, 8).
- [x] AC4: A hovered hand card keeps scale 1.0 and rises `Anim.HOVER_LIFT` = 8 px; a dragged card keeps scale 1.0 and
  tilts at most 3° (`Anim.MAX_TILT`) however fast it moves.
- [x] AC5: A card landing in a slot, or bought on the supply screen, doesn't squash: its scale stays (1, 1) throughout.
  `CardView.squash`, `CardMotion.squash`, `Anim.LAND_SQUASH` and `Anim.LAND_TIME` are gone.
  `test_card_landing::test_a_card_sent_to_another_slot_still_squashes_when_it_lands` becomes "doesn't squash", and its
  helper waits a fixed time instead of `LAND_TIME`; the dealt-card and rejected-card tests still pass unedited (a
  rejected card still shakes; narrowing the shake to the guide's 4 px is left for later).
- [x] AC6: No tween in `ui/` uses `Tween.TRANS_BACK`, `TRANS_ELASTIC` or `TRANS_BOUNCE` (`test_ui_structure` reads the
  scripts); the pulses, pops and slides that did use `TRANS_QUART` with `EASE_OUT`.

## Out of scope
- The cost on the card (180); dealing a pile into a grid (§15.13, a later item); a selected card's index tab.

## Design notes
- The band can be a `ColorRect` named `Band` in `CardFace` after the name (testable as a node), or drawn by `CardView`;
  the spike drew it, which is harder to test. A node inset by the panel's 12 px content margin is fine; the guide's
  edge-to-edge band is a nice-to-have.
- AC5 removes a path the rule change makes pointless (CLAUDE.md: remove its code and tests in the same item).
- Builds on 178 (palette values).

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_card_faces::test_every_card_at_rest_is_a_raised_sheet_in_a_thin_rule`, `test_a_dimmed_card_uses_the_dim_colours`, `test_the_border_shows_hover_drag_warning_and_target` |
| AC2 | `test_card_faces::test_a_band_of_the_type_colour_sits_under_the_name`, `test_a_dimmed_cards_band_is_the_dim_border`, `test_a_frontier_territory_has_no_band` |
| AC3 | `test_card_faces::test_a_card_at_rest_has_no_shadow_and_a_lifted_one_a_hard_one` |
| AC4 | `test_card_faces::test_a_hovered_hand_card_rises_eight_px_without_growing`, `test_a_dragged_card_keeps_its_size_and_tilts_at_most_three_degrees` |
| AC5 | `test_card_faces::test_the_squash_is_gone`, `test_a_card_bought_on_the_supply_screen_doesnt_squash`, `test_card_landing::test_a_card_sent_to_another_slot_doesnt_squash_when_it_lands` (was "still squashes") |
| AC6 | `test_ui_structure::test_no_tween_overshoots_or_bounces`, `test_the_pulses_pops_and_slides_ease_out_quartically` |

## Manual check
- [ ] Seed 5, Egypt: hovering the hand slides each card up a little with a hard shadow and nothing grows; dragging a
  card barely tilts; playing one onto the Realm lands with a firm stop.
- [ ] The type bands make the six types easy to tell apart at a glance, and dimmed cards stay readable.

## Log
- 2026-10-01: Specced from the mid-century style guide and the `spike/mcm-godot` spike (which set these values in
  `Anim` and `CardView`).
- 2026-10-02: Built. `CardFace` adds a `Band` ColorRect after the name (inset by the panel's 12 px margin, not edge to
  edge); `CardView` recolours it when dimmed. `Anim.HOVER_SCALE` and `DRAG_SCALE` went too (nothing grows), and the
  focus ring is square. Test fix in green, assertion unchanged:
  `test_a_card_bought_on_the_supply_screen_doesnt_squash` waited 30 frames for the piles' pop-in, which headless
  frames outrun; it now waits `POP_IN_TIME` + 0.2 s of real time. The drag-tilt test can't produce drag speed headless
  (`warp_mouse` doesn't register), so its 3° bound rests on `Anim.MAX_TILT`.
