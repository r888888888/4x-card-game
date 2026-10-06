---
id: 356
title: Smooth the Build modal's scrolling and quiet its selected row
type: feature
status: red-review
branch: feat/356-build-modal-polish
---

## Goal
The Build modal's list scrolls in jumps under the wheel, on Godot's default scrollbar, and its selected row is pulled
out onto a hard shadow like a raised key, louder than a choice in a list needs. Make its scrolling glide (eased, with
momentum that coasts to a stop), style its scrollbar for the desk, quiet the selected row to a background change, and
give the sheet more air: a gap before each heading after the first (Buildings → Upgrades → Units) and padding under the
card.

## Acceptance criteria
- [ ] AC1 (momentum): Given a `SmoothScroll` (a `ScrollContainer`) whose content is taller than it, at the top, with
  Reduce motion off, when one wheel-down notch reaches it, then its `scroll_vertical` has not moved in the same
  frame, has moved after one frame, keeps moving for several frames after the event (it coasts), and comes to rest
  `Anim.SCROLL_STEP` px down (± 2 px). A wheel-up notch from there brings it back to 0.
- [ ] AC2 (edges): Given it 10 px from the bottom, when a wheel-down notch reaches it, then it stops at the bottom
  (`scroll_vertical` at its maximum) and its motion ends there (no velocity left).
- [ ] AC3 (Reduce motion): Given Reduce motion on, when a wheel-down notch reaches it, then `scroll_vertical` is
  `Anim.SCROLL_STEP` down in the same frame.
- [ ] AC4 (scrollbar): Given the theme, then a vertical scrollbar's grabber is a `CONTROL` (steel) bar, `TEXT_DIM`
  under the pointer and while dragged, on a `FIELD` track, square, no wider than `Tokens.SPACE_2`.
- [ ] AC5 (Build modal): Given the Build modal open, then its list sits in a `SmoothScroll`; and given a menu taller
  than the list column, when Down moves the selection to a row below the visible area, then after the scroll settles
  that row lies wholly inside the column.
- [ ] AC6 (quiet selection): Given a `ListRow`, then its pressed and hover-pressed looks are a filled `RAISED` strip in
  place (no shadow, no expand margins, the same content margins as its normal look), and the selected row's index tab
  sits on the row's own leading edge.
- [ ] AC7 (heading gap): Given the Build modal with Buildings and Units rows, then the Units heading's top is at least
  `Tokens.SPACE_5` (24 px) below the last Buildings row's bottom, and the Buildings heading still starts at the top of
  the well.
- [ ] AC8 (card padding): Given the Build modal with a buildable row selected, then the first line under the card (its
  flavor or the "If built on" heading) starts `Tokens.SPACE_5` (24 px) below the card's bottom; the modal still fits a
  1920 × 1080 window (343, 354).

## Out of scope
- The Knowledge screen, the renewal modal and the hand's scroll areas (they can adopt `SmoothScroll` later).
- Hand cards' and tech tiles' selection (§10.5's slide and lift stay).

## Design notes
- `ui/smooth_scroll.gd`, `class_name SmoothScroll extends ScrollContainer`: takes the wheel itself (an impulse of
  velocity per notch that decays by `Anim.SCROLL_FRICTION`), so one notch travels `Anim.SCROLL_STEP`; `scroll_to(y)`
  eases a programmatic scroll (`TRANS_QUART`/`EASE_OUT`, no overshoot). Reduce motion: both jump.
- `GameTheme`: drop `SELECTED_SHADOW`'s use and `PULL` from `ListRow`; add the `VScrollBar` look.
- Guide: §4.4 "Selected" row, §7.16 Selectable list, a new §7.17 Scroll area, §9.4 a Scroll row, §9.5; tokens.md;
  the specimen's selectable list.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_smooth_scroll::test_a_wheel_notch_glides_the_step_and_coasts_to_rest` |
| AC2 | `test_smooth_scroll::test_a_notch_past_the_bottom_stops_there_with_no_motion_left` |
| AC3 | `test_smooth_scroll::test_with_reduce_motion_a_notch_jumps_the_step` |
| AC4 | `test_smooth_scroll::test_the_scrollbar_is_a_thin_steel_grabber_on_a_well` |
| AC5 | `test_build_modal::test_the_build_list_scrolls_smoothly`, `test_build_modal::test_down_scrolls_the_selected_row_into_view` |
| AC6 | `test_select_list::test_a_list_row_draws_no_box_until_selected` (changed), `test_select_list::test_only_the_selected_row_shows_its_index_tab` (changed) |
| AC7 | `test_build_modal::test_a_heading_after_rows_has_room_above_it` |
| AC8 | `test_build_modal::test_the_card_has_room_under_it`; the window fit stays `test_the_modal_is_a_680_px_ledger_inside_the_window` and `test_the_longest_flavor_keeps_the_modal_inside_the_window` |

## Manual check

## Log
