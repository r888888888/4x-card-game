---
id: 383
title: Overflowing card text cuts at a whole rule; hover pulls it over the art, then a meter opens the full rules
type: feature
status: ready
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
| AC1 | `test_…` |

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
