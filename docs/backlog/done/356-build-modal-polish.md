---
id: 356
title: Smooth the Build modal's scrolling and quiet its selected row
type: feature
status: done
branch: feat/356-build-modal-polish
---

## Goal
The Build modal's list scrolls in jumps under the wheel, on Godot's default scrollbar, and its selected row is pulled
out onto a hard shadow like a raised key, louder than a choice in a list needs. Make its scrolling glide (eased, with
momentum that coasts to a stop), style its scrollbar for the desk, quiet the selected row to a background change with
an indicator lamp (chosen from [list-quiet-options.html](../design/mocks/list-quiet-options.html), option H), and
give the sheet more air: a gap before each heading after the first (Buildings → Upgrades → Units) and padding under the
card.

## Acceptance criteria
- [x] AC1 (momentum): Given a `SmoothScroll` (a `ScrollContainer`) whose content is taller than it, at the top, with
  Reduce motion off, when one wheel-down notch reaches it, then its `scroll_vertical` has not moved in the same
  frame, has moved after one frame, keeps moving for several frames after the event (it coasts), and comes to rest
  `Anim.SCROLL_STEP` px down (± 2 px). A wheel-up notch from there brings it back to 0.
- [x] AC2 (edges): Given it 10 px from the bottom, when a wheel-down notch reaches it, then it stops at the bottom
  (`scroll_vertical` at its maximum) and its motion ends there (no velocity left).
- [x] AC3 (Reduce motion): Given Reduce motion on, when a wheel-down notch reaches it, then `scroll_vertical` is
  `Anim.SCROLL_STEP` down in the same frame.
- [x] AC4 (scrollbar): Given the theme, then a vertical scrollbar's grabber is a `CONTROL` (steel) bar, `TEXT_DIM`
  under the pointer and while dragged, on a `FIELD` track, square, no wider than `Tokens.SPACE_2`.
- [x] AC5 (Build modal): Given the Build modal open, then its list sits in a `SmoothScroll`; and given a menu taller
  than the list column, when Down moves the selection to a row below the visible area, then after the scroll settles
  that row lies wholly inside the column.
- [x] AC6 (quiet selection, the mock's H): Given a `ListRow`, then its pressed and hover-pressed looks are a filled
  `RAISED` strip in place (no shadow, no expand margins, the same content margins as its normal look). Given a
  `SelectList` with rows a, b and c and b selected, then only b shows its indicator lamp (`ReadyLamp`, §7.11), lit,
  `Tokens.SPACE_4` in from the row's left edge before its name; a and c keep the lamp's room but show none; no row
  has an index tab. Selecting c moves the lamp to c; Up and Down and the focus ring behave as before (217).
- [x] AC7 (heading gap): Given the Build modal with Buildings and Units rows, then the Units heading's top is at least
  `Tokens.SPACE_5` (24 px) below the last Buildings row's bottom, and the Buildings heading still starts at the top of
  the well.
- [x] AC8 (card padding): Given the Build modal with a buildable row selected, then the first line under the card (its
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
- `SelectList` puts a `ReadyLamp` on every row (`ReadyLamp.attach`: the icon keeps its room), lit quietly (no
  starburst, no `ui.confirm`: that is for news), shown only on the selected row; the `IndexTab` goes.
- Guide (updated with the choice): §4.4 "Selected" row, §7.11 lamp, §7.16 Selectable list, a new §7.17 Scroll area, §9.4 a Scroll row, §9.5; tokens.md;
  the specimen's selectable list.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_smooth_scroll::test_a_wheel_notch_glides_the_step_and_coasts_to_rest` |
| AC2 | `test_smooth_scroll::test_a_notch_past_the_bottom_stops_there_with_no_motion_left` |
| AC3 | `test_smooth_scroll::test_with_reduce_motion_a_notch_jumps_the_step` |
| AC4 | `test_smooth_scroll::test_the_scrollbar_is_a_thin_steel_grabber_on_a_well` |
| AC5 | `test_build_modal::test_the_build_list_scrolls_smoothly`, `test_build_modal::test_down_scrolls_the_selected_row_into_view` |
| AC6 | `test_select_list::test_a_list_row_draws_no_box_until_selected`, `test_select_list::test_only_the_selected_row_shows_its_lamp_lit` (was `…_shows_its_index_tab`), and the lamp in place of the tab in `test_select_list::test_a_click_or_up_and_down_choose_a_row`, `test_select_list::test_a_list_rows_focus_is_the_ring_not_the_selection`, `test_start_screen::test_the_civilizations_are_a_select_list_with_one_lamp` (was `…_with_one_index_tab`), `test_start_screen::test_moving_the_focus_off_the_selected_row_keeps_the_selection` (all changed) |
| AC7 | `test_build_modal::test_a_heading_after_rows_has_room_above_it` |
| AC8 | `test_build_modal::test_the_card_has_room_under_it`; the window fit stays `test_the_modal_is_a_680_px_ledger_inside_the_window` and `test_the_longest_flavor_keeps_the_modal_inside_the_window` |

## Manual check
1. `godot --path .`, start any game, open the home territory and press Build… (or B).
2. The selected row is a lighter strip with a lit sage lamp before its name; no row slides or casts a shadow, and
   there's no orange tab. Other rows' names line up with the selected one's.
3. Up and Down move the lamp; with more rows than fit, the list glides to keep the selection in view.
4. Wheel over the list: one notch eases about 120 px and coasts to a stop; several notches add up; it stops dead at
   the top and bottom. The scrollbar is a thin steel bar that lightens under the pointer and while dragged.
5. Settings → Reduce motion ON: a notch and Up/Down jump instead of gliding.
6. There's clear space above Upgrades and Units, and 24 px between the card and the lines under it.
7. The new game screen's civilization list shows the same lamp selection.
8. Both checks in Day mode too.

## Log
- 2026-10-06: Mock [list-quiet-options.html](../design/mocks/list-quiet-options.html) (twelve options); the user chose
  H, the lamp on the chosen row only. The style guide was updated with the choice (§4.4, §7.11, §7.16, new §7.17,
  §9.4, §9.5, §10.5, §11.10), then tokens.md and the specimen once built.
- `docs/testing.md` sits at its 25 KB cap (2 bytes under on main); a few helper rows were tightened to add this
  item's test file. The next new test file will hit it again.
- Follow-ups, not in this item: the Knowledge screen, the renewal modal and the tableau could use `SmoothScroll`; the
  theme styles only `VScrollBar` (the hand's horizontal bar keeps Godot's look); the specimen's audio throws
  "AudioParam … non-finite" on a list click on main too (not from this item).
- Tests 2268 → 2276.
