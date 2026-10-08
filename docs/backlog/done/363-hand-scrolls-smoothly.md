---
id: 363
title: The hand scrolls smoothly sideways, on the steel scrollbar
type: feature
status: done
branch: feat/363-hand-scrolls-smoothly
---

## Goal
The hand scrolls sideways when it holds more cards than fit. It still jumps under the wheel, its scrollbar keeps
Godot's default grey look, and moving the card focus to an off-screen card snaps the row
(`ensure_control_visible`). Give the hand the same glide and the same thin steel scrollbar as the Build modal's list
(356, guide §7.17), sideways.

## Acceptance criteria
- [x] AC1: Given a `SmoothScroll` with vertical scrolling disabled and content wider than it, with Reduce motion off,
  when one wheel-down notch reaches it, then its `scroll_horizontal` has not moved in that frame, moves after one
  frame, coasts for several frames, and comes to rest `Anim.SCROLL_STEP` px right (± 2); wheel-up brings it back;
  a horizontal wheel (`MOUSE_BUTTON_WHEEL_RIGHT` / `_LEFT`) does the same. It stops dead
  at either end.
- [x] AC2: Given Reduce motion on, then a notch moves it the whole step at once.
- [x] AC3: Given a hand of more cards than fit (a 1280 × 720 window), then `main.hand_scroll` is a `SmoothScroll`; when
  the card focus moves (Left and Right) to a card outside the visible part of the row, then after the scroll settles
  that card's slot lies wholly inside the hand's scroll area; with Reduce motion on, it is there in the same frame.
- [x] AC4: Given the theme, then a horizontal scrollbar's grabber is a `CONTROL` (steel) bar, `TEXT_DIM` under the
  pointer and while dragged, on a `FIELD` track, square, no taller than `Tokens.SPACE_2`, as the vertical one (356).
- [x] AC5: Given the hand scrolled, then a hovered card's lift and a drag out of the hand work as before (the existing
  hand and drag tests hold).

## Out of scope
- The vertical scroll areas (362).

## Design notes
- `SmoothScroll` gains the horizontal axis: it glides along whichever axis can scroll (vertical first), and `follow`
  eases a control into view on both axes. The hand's `card_focus.gd` calls `follow` instead of
  `ensure_control_visible`.
- `GameTheme`: the `HScrollBar` look from the `VScrollBar`'s (track margins top and bottom instead of left and right).
- Guide §7.17 and tokens.md's Scroll areas row say both axes.

## Test plan
All in `tests/test_smooth_scroll.gd` (no new file, so no new `docs/testing.md` row).

| AC | Tests |
|----|-------|
| AC1 | `test_a_notch_glides_a_sideways_scroll_the_step_and_coasts_to_rest` (wheel down/up and right/left), `test_a_notch_past_the_right_end_stops_there_with_no_motion_left` |
| AC2 | `test_with_reduce_motion_a_notch_jumps_a_sideways_scroll_the_step` |
| AC3 | `test_the_hand_eases_the_focused_card_into_view`, `test_with_reduce_motion_the_hand_jumps_the_focused_card_into_view` |
| AC4 | `test_the_sideways_scrollbar_is_a_thin_steel_grabber_on_a_well` (the vertical one now shares `check_bar_look`) |
| AC5 | the existing hand and drag tests |

`wheel_notch` in `tests/lib/test_case.gd` now calls a new `wheel_turn(main, scroll, button, point)` for any wheel
button.

## Manual check
1. `godot --path .` in a 1280 × 720 window, Reduce motion off; get more cards in hand than fit (draw effects, or
   `-- --seed 5 --turns 20` and play a few turns).
2. A wheel notch (down/up, and a sideways wheel or trackpad swipe) over the hand eases it about 120 px sideways and
   coasts to rest; it stops dead at either end.
3. The hand's scrollbar is a thin steel bar on a dark well, lighter under the pointer and while dragged.
4. Press Right repeatedly: the row eases each focused card into view; hold Left back: it eases back.
5. With the hand scrolled, hover a card (it lifts) and drag one onto the Realm (it plays as before).
6. Settings → Reduce motion on: a notch and a focus move jump at once.

## Log
- 2026-10-06: Follow-up from 356's Log.
- 2026-10-06: Built. `SmoothScroll` glides sideways when its vertical scrolling is disabled (all four wheel buttons
  push it there); `follow` works on both axes. Two follow fixes the hand's tests found: it measures the control in the
  content's own coordinates (Godot lays the content out a frame after a scroll is set, so a follow called right after
  another measured against a stale position and overshot), and a follow for a control already in view stops any
  earlier follow's tween instead of leaving it to carry the row past. With Reduce motion, `follow` sorts the content
  at once so the card is in view the same frame. `GameTheme._scroll_bar` builds both bars' looks.
