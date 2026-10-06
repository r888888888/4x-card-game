---
id: 363
title: The hand scrolls smoothly sideways, on the steel scrollbar
type: feature
status: ready
branch: feat/363-hand-scrolls-smoothly
---

## Goal
The hand scrolls sideways when it holds more cards than fit. It still jumps under the wheel, its scrollbar keeps
Godot's default grey look, and moving the card focus to an off-screen card snaps the row
(`ensure_control_visible`). Give the hand the same glide and the same thin steel scrollbar as the Build modal's list
(356, guide §7.17), sideways.

## Acceptance criteria
- [ ] AC1: Given a `SmoothScroll` with vertical scrolling disabled and content wider than it, with Reduce motion off,
  when one wheel-down notch reaches it, then its `scroll_horizontal` has not moved in that frame, moves after one
  frame, coasts for several frames, and comes to rest `Anim.SCROLL_STEP` px right (± 2); wheel-up brings it back;
  a horizontal wheel (`MOUSE_BUTTON_WHEEL_RIGHT` / `_LEFT`) does the same. It stops dead
  at either end.
- [ ] AC2: Given Reduce motion on, then a notch moves it the whole step at once.
- [ ] AC3: Given a hand of more cards than fit (a 1280 × 720 window), then `main.hand_scroll` is a `SmoothScroll`; when
  the card focus moves (Left and Right) to a card outside the visible part of the row, then after the scroll settles
  that card's slot lies wholly inside the hand's scroll area; with Reduce motion on, it is there in the same frame.
- [ ] AC4: Given the theme, then a horizontal scrollbar's grabber is a `CONTROL` (steel) bar, `TEXT_DIM` under the
  pointer and while dragged, on a `FIELD` track, square, no taller than `Tokens.SPACE_2`, as the vertical one (356).
- [ ] AC5: Given the hand scrolled, then a hovered card's lift and a drag out of the hand work as before (the existing
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
<!-- Filled in by Claude during the red phase. -->

## Manual check

## Log
- 2026-10-06: Follow-up from 356's Log.
