---
id: 383
title: Overflowing card text cuts at a whole rule; hover pulls it over the art, then a meter opens the full rules
type: feature
status: in-progress
branch: feat/383-card-text-overflow-hover
---

## Goal
With the art plate (381), a hand card has room for about six lines of rules, and the long tail still overruns it
even with the tighter text (382). Today such a card just grows, breaking the hand's even row. Instead, a card keeps
its size: at rest it shows whole rules and a "+N more" foot; when the pointer rests on a hand card, the text sheet
slides up over the art as far as it needs; and if rules are still hidden, the foot's rule fills like a gauge and the
full rules open beside the card, with no click. This replaces the plain tooltip on hand cards. From `spike/card-art`
(option I of `docs/design/mocks/card-overflow-options.html`, with the meter cue).

## Acceptance criteria
<!-- UI tests: a fixture card with 10 one-line rules ("long") and one with 2 ("short"), hand-size faces at
264 × 360. Timers are driven by the test (as other timed UI tests do), never by waiting. -->
- [ ] AC1: Given a hand-size face for "long", when it is laid out, then the card stays 360 px tall, every rules line
  shown is wholly inside the rules area (none partly visible), and a foot named `Over` reads "+N more" where N is the
  number of hidden lines; "short" has no foot. A rule that is one paragraph is cut after its last whole sentence that
  fits (N counts the hidden sentences); a rule that can't fit even its first line is hidden whole.
- [ ] AC2: On a hand card the foot also reads "details I"; on the card in the details, Build, event, raid or Renewal
  modal it reads only "+N more", and those cards never react to hover (their full text is beside them).
- [ ] AC3: Given "long" in the hand, when the pointer rests on it for `Anim.OVERFLOW_INTENT` (0.12 s) without moving,
  then its text sheet (type line, ledger, rules, foot, fine print) rises over the art plate by exactly the height
  the hidden content needs, capped at the plate plus its gap (104 px), easing over `Anim.OVERFLOW_SLIDE` (0.12 s),
  and the rules and foot are cut again for the larger area. A pointer that leaves or moves before 0.12 s changes
  nothing; leaving after restores the rest layout. "short" never moves beyond its hover lift.
- [ ] AC4: Given rules still hidden after the sheet rises, when the pointer stays, then the foot's meter fills from 0
  to its full width over `Anim.OVERFLOW_WAIT` (1.1 s), and when full a rules popover opens beside the card (right of
  it, or left when the right edge has no room for it) holding the card's name and its long-form rules
  (`rules_tooltip`), then its play error and detail if any. If everything fits after the rise, no meter runs and no
  popover opens.
- [ ] AC5: The popover is not a modal: the pointer may move from the card onto it without closing it; leaving both,
  Esc, or a press anywhere closes it. A press on the card at any step (waiting, rising, filling, open) cancels the
  step and the press goes on to select, drag or double-click as today. Hand cards no longer set `tooltip_text`;
  tableau, Realm and supply-pile cards keep their tooltips.
- [ ] AC6: Focusing a hand card with the keyboard raises its sheet at once (no meter; `I` opens the details as today).
  With Reduce motion the sheet moves without easing, the meter fills in three equal steps, and the popover appears
  without its slide.

## Out of scope
- Tableau-size faces: they keep growing when their text overruns (382 removes most of it).
- The pictures (381 ships placeholders) and the face text (382).
- Touch input (there is none today).
- A "continued" popover with only the hidden lines (the spike's mock judged it to lose context).

## Design notes
- Order: after 381 (the plate the sheet covers) and 382 (the face whose parts the sheet carries); built without 382
  it works the same on today's text, with more cards reaching the popover.
- Starting code: `spike/card-art`'s mock (`docs/design/mocks/card-overflow-options.html`, option I: `cut`,
  `shiftFor`, `slideTo`, `setupH`). Lessons from it: lay out and cut at the final position with motion off, then
  animate (measuring mid-tween gives wrong cuts); the sheet's top rule must take no layout room; a cut keeps whole
  rules only.
- `CardFace` wraps everything below the art in a `Sheet` container (paper fill, z above the plate, a 1 px ink rule
  at its top edge drawn without taking room) whose top margin goes negative to rise. The cut (which lines to hide,
  the paragraph's sentence cut) is layout, so it lives in `ui/` (a small `RulesCut` helper beside `CardFace`, to
  keep `card_view.gd`, at 560 of 700 lines, from growing).
- Timing constants in `Anim`: `OVERFLOW_INTENT` 0.12, `OVERFLOW_SLIDE` 0.12, `OVERFLOW_WAIT` 1.1. The meter is a
  2 px `TEXT` bar over the foot's dashed rule, linear (a gauge), `steps(3)` with Reduce motion.
- The popover is 379's `Popover` (the §11.11 printed-tab look: ink fill, inverse text, square, a `label-caps` heading,
  a 6 px notch toward the card), 320 px wide, anchored to the card's side. If 383 is built before 379, it introduces
  `Popover` and 379 reuses it. Silent, like every hover (§11.11).
- Removing the hand card's tooltip drops two things it carried: the how-to hint ("Drag into the realm…", already on
  the hand heading's tooltip) and the play error's detail on cards that fit (the reason itself stays on the face's
  strip; the popover carries the detail when it opens). The user chose this (popover only when rules are hidden).
- Existing tests that read a hand card's `tooltip_text` (e.g. `test_actions.gd`'s "the last Shrine says why it can't
  be played") assert behaviour this item removes on purpose: they move to the reason strip's text, flagged at the red
  checkpoint for approval.
- Docs: the guide gets the overflow rules (§6.7 and §11.11, already on `docs/card-art-design`); tokens.md gains the
  `Anim` constants; the specimen gains a card that rises and fills.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_card_overflow::test_a_long_card_keeps_its_size_and_shows_only_whole_rules`, `test_a_short_card_has_no_foot`, `test_a_one_paragraph_rule_is_cut_after_its_last_whole_sentence`, `test_a_paragraph_whose_first_sentence_cannot_fit_is_hidden_whole`, `test_a_rule_that_does_not_fit_after_others_is_hidden_whole` |
| AC2 | `test_card_overflow::test_a_hand_row_card_foot_adds_details_i`, `test_a_hand_size_face_off_the_hand_row_reads_only_more_and_never_peeks`, `test_in_the_real_hand_the_foot_says_details_and_the_details_card_does_not` |
| AC3 | `test_card_overflow::test_the_overflow_timings_are_anim_constants`, `test_resting_on_a_long_card_raises_its_sheet_to_the_cap`, `test_a_medium_card_rises_only_as_far_as_its_hidden_rules_need`, `test_leaving_or_moving_before_the_intent_changes_nothing`, `test_leaving_after_the_rise_restores_the_rest_layout`, `test_a_short_card_never_rises` |
| AC4 | `test_card_overflow::test_still_hidden_rules_fill_the_meter_then_open_the_popover`, `test_the_popover_adds_the_play_error_and_its_detail`, `test_the_popover_opens_right_of_the_card_or_left_without_room`, `test_no_meter_or_popover_when_everything_fits_once_risen` |
| AC5 | `test_card_overflow::test_the_pointer_may_cross_onto_the_popover_and_leaving_both_closes_it`, `test_esc_or_a_press_anywhere_closes_the_popover`, `test_a_press_on_the_card_cancels_any_step_and_still_drags`, `test_hand_cards_set_no_tooltip_and_other_cards_keep_theirs`; changed: `test_actions::test_top_bar_counts_actions_and_spent_hands_dim`, `test_build_modal::test_a_hand_card_with_no_free_worker_says_why_on_its_strip` (was `…_explains_in_its_tooltip`) |
| AC6 | `test_card_overflow::test_keyboard_focus_raises_the_sheet_at_once_with_no_meter`, `test_reduce_motion_jumps_the_sheet_steps_the_meter_and_places_the_popover` |

## Manual check
- [ ] Hand with Sailing, Code of Laws, Theocracy, Anarchy and a Farm (`godot --path . -- --civ sumer --seed 5`, then
  draw or use the details): rest on each; the sheet rises only on long cards and only as far as needed; only the
  ones still short show the meter and then the popover; sweeping across the hand moves nothing.
- [ ] Move from a card onto its popover: it stays; leave both: it closes. Start a drag mid-meter: nothing blocks it.
- [ ] Reduce motion on: the sheet jumps, the meter steps in three, the popover appears in place.
- [ ] Night and Day: the sheet's paper covers the plate cleanly; the meter reads against the dashed rule.

## Log
<!-- Decisions and surprises during implementation, newest last. -->
- 2026-10-06: specced from `spike/card-art`. The user chose option I with the meter cue (1.1 s), the popover only
  when rules stay hidden, and the hover only on hand cards.
- 2026-10-07: red tests. The interface they set: `CardView.peek` (a `CardPeek`: `advance(delta)`, `rise()`, `meter()`,
  `popover`, `manual_clock` so tests drive time) and `CardView.peek_on(layer)` (a hand-row card; BoardViews calls it
  with main's fx layer, so modal faces never peek); the face's `Rules` box (one label per rule) and `Over` foot;
  `Popover.text()`. Long has 16 rules, not the comment's 10: 10 one-line rules would all fit once risen (about 6 at
  rest + 4 risen + the foot's line), so no meter would run. Two tests that read a hand card's tooltip move to its reason
  strip (`reason_text`, new in test_case.gd: the strip's label keeps no `source` meta, so `face_text` can't read it).
