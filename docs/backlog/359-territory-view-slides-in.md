---
id: 359
title: The territory view slides in from the right like Knowledge
type: feature
status: red-review
branch: feat/359-territory-view-slides-in
---

## Goal
The territory view wipes out of its card (350), and it still doesn't feel right. Open it the way the Knowledge screen
opens (208): a sheet run in from the right edge while the Realm moves aside, and run back out to the right on Back. The
territory view is the only screen pushed from a rect, so the wipe goes with it.

## Acceptance criteria
- [ ] AC1: Given a game on the board with Reduce motion off, when the player opens a territory's view from its card,
  then the view slides in from the right: it starts its own width off its place (`Navigator.offset_of(view).x` ≈ the
  view's width) and is in place (offset 0) by `Navigator.SLIDE_IN` (0.32 s), while the Realm moves `Navigator.SHIFT`
  (-24 px) left; the view is never scaled or clipped.
- [ ] AC2: Given the open territory view, when Back is pressed, then the view is closed at once (`is_open()` false) and
  runs out to the right over `Navigator.SLIDE_OUT` (0.26 s) as the Realm comes back to offset 0, then is hidden.
- [ ] AC3: Given Reduce motion on, when the view opens and closes, then it only fades (`SLIDE_FADE`), with no offset.
- [ ] AC4: Given the territory view open, when Knowledge is opened over it and closed, then Knowledge slides over the
  view and back off it as it does over the Realm (208's tests still pass).
- [ ] AC5: The wipe is gone: `Navigator.push` takes no `from` rect, and `wipe_rect`, `wipe_outline`, `leaving_shot`,
  the clip, outline and snapshot code, and `Anim.WIPE_IN` / `WIPE_OUT` / `WIPE_LINGER` are removed with their tests;
  `wait_screen_transition` waits for the longest remaining transition.

## Out of scope
- Changing the slide itself (timings, easing, shift) or Knowledge's transition.
- Sounds: unchanged (NAV_FORWARD / NAV_BACK).

## Design notes
- `TerritoryView.open` pushes with `slide = true` (as `KnowledgeScreen` does); with `from` gone, `push`'s signature
  becomes `push(screen, focus, title, slide)` and `Navigator`'s `_from` array goes.
- The view's header and the Realm swap places in the same VBox slot, so the slide's stand-in (224) should keep the hand
  and the sections around it still, as it does for Knowledge; check by eye.
- Update the style guide: §9.2's note on the old grow, §10.2 (the territory joins Knowledge as a sheet from the right;
  drop the wipe from a card's rectangle for screens) and §11.6's "Entering" line. The pile's TOO BIG sheet (§10.2
  reference in the sound table) is unbuilt; leave its wording.
- `spike/territory-transition` (the wipe/blind/slide/rise spike) is no longer cited by an open item once this lands.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1, AC2 | `test_screen_header::test_a_territory_view_slides_in_from_the_right_and_back_out` (replaces `test_a_territory_view_wipes_out_of_its_card_and_back_into_it`) |
| AC3 | `test_screen_header::test_with_reduce_motion_a_territory_view_only_fades` |
| AC4 | existing `test_knowledge_screen::test_over_a_territory_view_it_pushes_on_top_and_back_returns_to_the_view`, `test_over_a_territory_its_tab_goes_back_one_step_to_the_view` |
| AC5 | `test_navigator::test_push_takes_no_rect_its_fourth_argument_slides`; `test_navigator::test_with_reduce_motion_a_push_only_fades` (now pushes a slide); 350's `test_push_from_a_rect_wipes_the_screen_out_of_it_unscaled`, `test_back_after_a_wipe_shrinks_a_snapshot_into_the_rect`, `test_a_new_step_finishes_a_running_wipe_first` removed; `test_push_without_a_rect_fades_in` renamed `test_push_without_a_slide_fades_in` |

## Manual check
- [ ] Open a territory (seed 5, Egypt, Thebes): the view runs in from the right as the Realm moves aside; Back runs it
  out to the right. The hand and the header stay put throughout.
- [ ] Open Knowledge from inside the territory view and back: both slides look right stacked.

## Log
