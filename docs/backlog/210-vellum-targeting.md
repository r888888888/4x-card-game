---
id: 210
title: Targeting lays vellum over the board, the targets above it
type: feature
status: red-review
branch: feat/210-vellum-targeting
---

## Goal
When a card waits for a target (targeting mode, double-click on a card with several targets), a sheet of vellum wipes
across the board and only the valid targets stay above it, outlined and lit (`docs/design/transitions.html`
transition 6), so the choice is obvious. Cancelling wipes it off.

## Acceptance criteria
- [ ] AC1: Given a hand card with two or more valid targets (`valid_targets(uid)`), when targeting starts, then a
  vellum layer (`SCRIM`-like translucent `RAISED`) covers the Realm and the hand, wiping in from the left edge over
  0.26 s (`Anim.MACHINED`); the targeting card and each valid target's view are drawn above it, each target with a
  2 px `FOCUS` outline.
- [ ] AC2: Non-targets under the vellum don't take clicks; a click on a target plays the card on it (as today) and the
  vellum wipes off to the right in 0.20 s (`Anim.RELEASE`).
- [ ] AC3: When targeting is cancelled (Esc, right-click, or a click on the vellum), the card goes back to the hand and
  the vellum wipes off to the right; nothing is played.
- [ ] AC4: With Reduce motion: the vellum fades in and out over 0.12 s, no wipe.
- [ ] AC5: A drag (not targeting mode) keeps today's lit targets and drop highlight, with no vellum.

## Out of scope
- Cards with one target (they play straight away).

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_vellum::test_targeting_wipes_vellum_in_from_the_left_with_the_targets_above_it` |
| AC2 | `test_a_click_on_a_target_plays_there_and_the_vellum_wipes_off_right`, `test_a_click_on_a_non_target_card_reaches_only_the_vellum` |
| AC3 | `test_esc_right_click_or_a_click_on_the_vellum_cancel_and_wipe_it_off` |
| AC4 | `test_with_reduce_motion_the_vellum_fades_in_and_out` |
| AC5 | `test_a_drag_lights_targets_without_vellum` |

Decision made writing the tests: a click on a non-target card lands on the vellum, so it cancels targeting (AC3's
click on the vellum) rather than doing nothing.

## Manual check
- [ ] A card with two targets (e.g. a building with two eligible territories): the vellum and outlines read in both
  palettes; compare with the mock at ¼ speed.

## Log
- Specced 2026-10-02 from the notes list.
