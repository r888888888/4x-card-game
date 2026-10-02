---
id: 203
title: End turn as the specimen's key, at the sidebar's foot
type: feature
status: red-review
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
| AC1, AC6 | `test_end_turn_key::test_end_turn_is_the_big_key_at_the_bottom_right_of_the_sidebar`; removed: `test_board_layout::test_end_turn_is_in_the_top_bar_between_log_and_menu`; E still ends the turn: existing `test_board_layout::test_end_turn_still_ends_the_turn_and_shows_a_pending_discard` |
| AC2 | `test_the_lamp_is_ochre_with_actions_left_and_sage_when_spent`, `test_with_unlimited_actions_the_lamp_is_sage_without_a_caption`, `test_a_discard_owed_lights_brick_and_disables_the_key_with_the_reason`; changed: `test_board_layout`'s discard checks read the key's caption (it no longer reads "Discard N (hand limit M)") |
| AC3 | `test_pressing_it_shows_upkeep_until_the_new_turn_then_its_plate`, `test_the_plate_flaps_to_the_new_turn_or_changes_at_once_with_reduce_motion` |
| AC4 | `test_pressed_it_sinks_into_its_plinth`; the sounds: existing `test_key_sounds` End turn tests (changed: the dead-tap test finds the key on the sidebar, not by `AccentButton`) |
| AC5 | `test_game_over_disables_it_with_a_brick_lamp` |

Decisions made writing the tests: the key keeps "End turn" as its Button text (tests and the shortcut tooltip find it
by it) and draws "END TURN" in caps; a discard owed shows the engine's reason ("Discard down to 7 cards first.") as
the caption instead of "Discard N (hand limit M)"; the lamp is off while busy.

## Manual check
- [ ] Compare with the specimen's Turn section in both palettes: plinth, lamp, plate, press travel, the flap.

## Log
- Specced 2026-10-02 from the notes list. Decided 2026-10-02: the full §15.12 key (lamp states, plate, caption, busy).
