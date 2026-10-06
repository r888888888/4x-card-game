---
id: 350
title: The territory view wipes out of its card instead of zooming
type: feature
status: review
branch: feat/350-wipe-from-card
---

## Goal
A screen pushed from a rect (the territory view, grown out of its card, 104) zooms: it is scaled unevenly from the
card's 245 × 150 up to the play area, so its text and frame stretch as it grows. The style guide asks for a wipe instead
(§9.2, §10.2): the view is revealed through a rect that grows from the card's bounds to the full view, with nothing
scaled. The spike `spike/territory-transition` tried a wipe, a blind, a slide and a rise-and-fade; the wipe looked
best.

## Acceptance criteria
- [x] AC1: Given an animated navigator with Reduce motion off, when a screen is pushed from rect R, then the screen is
  never scaled (scale stays 1), and what it shows starts at R (`wipe_rect(screen)` = R at once) and grows to its content
  rect (the union of its shown children, not the empty room under them) by `Anim.WIPE_IN` (0.30 s), easing out.
- [x] AC2: Given the same wipe, then a 2 px outline traces the shown rect's edge while it grows, and is gone
  `Anim.WIPE_LINGER` (0.12 s) after the wipe lands; afterwards nothing is clipped (`wipe_rect` is empty).
- [x] AC3: Given a screen pushed from R, when back is called, then the screen is hidden at once (not drawn, takes no
  clicks), the screen below shows at once, and a snapshot of the screen's content as last drawn (`leaving_shot()`) shrinks
  from the content rect into R over `Anim.WIPE_OUT` (0.24 s), then is freed. Nothing the board changes as the screen
  closes (its cards leave at once) shows during the close.
- [x] AC4: Unchanged: with Reduce motion a push from a rect only fades; a push without a rect fades; a slide slides; a
  new step finishes a running wipe first.
- [x] AC5: Given the territory view opened from its card, then it wipes out of the card (`wipe_rect` starts at the
  card's rect) and wipes back into it on Back.

## Out of scope
- The style guide's flash of the card's band colour in the title bar (§10.2): a follow-up if wanted.
- Sounds are unchanged (NAV_FORWARD / NAV_BACK).

## Design notes
- From the spike: the wipe masks the screen's children with `clip_children = CLIP_CHILDREN_ONLY` and a rect drawn in
  its `draw`; the close runs on a snapshot (`get_viewport().get_texture().get_image()` cropped to the content, in a
  clipping wrapper) because the board drops the view's cards the moment it closes, which reflowed the free slots.
  Headless runs have no image: the snapshot then shows nothing but still runs its course.
- The grow (`_scale_onto` and the scale tweens) becomes unreachable and is removed.
- New `Anim` tokens: `WIPE_IN`, `WIPE_OUT`, `WIPE_LINGER`. `wait_screen_transition` covers the longest.
- Test hooks: `Navigator.wipe_rect(screen) -> Rect2` (global; empty when not wiping), `wipe_outline(screen) -> Control`
  (or null), `leaving_shot() -> Control` (or null).

## Test plan
| AC | Test |
|---|---|
| AC1, AC2 | `test_navigator::test_push_from_a_rect_wipes_the_screen_out_of_it_unscaled` |
| AC3 | `test_navigator::test_back_after_a_wipe_shrinks_a_snapshot_into_the_rect` |
| AC4 | `test_navigator::test_a_new_step_finishes_a_running_wipe_first`; `test_navigator::test_with_reduce_motion_a_push_only_fades` (adds "no wipe"); `test_navigator::test_push_without_a_rect_fades_in`, `test_navigator::test_back_reverses_the_push_and_the_screen_below_takes_input_at_once` (now on the fade path) |
| AC5 | `test_screen_header::test_a_territory_view_wipes_out_of_its_card_and_back_into_it` (replaces `test_a_territory_view_grows_out_of_its_card_and_shrinks_back`) |

## Manual check
- [ ] Open a territory (seed 5, Egypt, Thebes): the view is revealed from the card outward, an outline on its edge, with
  no stretched text; Back wipes it back into the card with its cards still on it.

## Log
- Checked on the real data (seed 5, Egypt, slowed to 0.2×): the view is revealed from the Thebes card outward, and the
  close shrinks a snapshot with the Capital still on it back into the card.
- `wait_screen_transition` now waits for the longest of the fade and the wipe (its outline included).
- The spike `spike/territory-transition` stays unmerged as the reference.
