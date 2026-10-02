---
id: 203
title: End turn as the specimen's key, at the sidebar's foot
type: feature
status: ready
branch: feat/203-end-turn-key
---

## Goal
End turn becomes the desk's biggest key (guide §15.12, `docs/design/mcm-specimen.html` "Turn"), at the bottom right
of the sidebar (202): a lamp that says whether you're ready, the turn plate, a caption for actions left, and a busy
state while the turn resolves.

## Acceptance criteria
- [ ] AC1: Given a game in progress, then End turn sits at the sidebar's bottom right: 220 × 64, `ACCENT` fill,
  3 px `TEXT` border, `RADIUS_1`, a 4,4 plinth shadow; a lamp at its left, the label "END TURN" in the caps label
  face, and the turn plate ("012" for turn 12, mono numeral on the `FIELD` inset) at its right.
- [ ] AC2: Lamp states, from the engine: given `end_turn_error()` is "" and `actions_left()` is 0, the lamp is lit in
  `GAIN` (sage) and the caption under the key is empty; given `end_turn_error()` is "" and `actions_left()` is 2, the
  lamp is lit in `WEALTH` (ochre) and the caption reads "2 actions left" ("1 action left" for 1); given
  `end_turn_error()` is non-empty (a discard owed), the lamp is lit in `UNREST` (brick), the key is disabled with no
  plinth, and the caption is the error.
- [ ] AC3: When End turn is pressed and the turn ends, then until the new turn's refresh finishes (at most 1.2 s), the
  key is busy: `CONTROL` fill, label "UPKEEP…", lamp off, presses ignored; the plate then shows the new turn (split-flap
  per character, `TYPE_NUMERAL_S`; with Reduce motion it changes at once). After that it returns to AC2's state.
- [ ] AC4: Pressed, it moves +4,+4 and loses its shadow (70 ms snap); the existing sounds (187: press, commit, turn
  drum) still play at the same moments.
- [ ] AC5: The game-over state disables it with `end_turn_error()`'s reason, lamp brick.
- [ ] AC6: The top strip no longer has End turn; its keyboard shortcut (if any) still works.

## Out of scope
- Era change ceremony on end turn (211).

## Design notes
- Unlimited actions (`actions_per_turn()` < 0 or the hand caption hidden today, 127): no caption, lamp sage.
- Caption wording is UI; the count comes from `actions_left()`.
- Needs 202.

## Test plan
| AC | Test |
|---|---|

## Manual check
- [ ] Compare with the specimen's Turn section in both palettes: plinth, lamp, plate, press travel, the flap.

## Log
- Specced 2026-10-02 from the notes list. Decided 2026-10-02: the full §15.12 key (lamp states, plate, caption, busy).
