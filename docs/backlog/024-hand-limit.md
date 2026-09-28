---
id: 024
title: Keep unplayed cards and discard down to a hand limit
type: feature
status: red-review
branch: feat/024-hand-limit
---

## Goal
Unplayed cards stay in hand for the next turn instead of being discarded, so the player can save a
card for a better moment. A hand limit stops endless hoarding: when a turn ends with more cards in
hand than the limit, the player picks which cards to discard.

## Acceptance criteria
In these criteria the config has `hand_size: 5` and `hand_limit: 7`, and `scout` is the TEST_CARDS
action that draws 2 (it has no cost).

- [ ] AC1 (keep the hand): Given a deck of 10 farms and a starting hand of 5, when I play 1 Farm and end
  the turn, then the other 4 Farms are still in hand, the discard pile is empty, and the new turn draws
  1 card, so the hand has 5 and the deck has 4.
- [ ] AC2 (draw up to hand size): Given a hand of 6 at the start of a turn (more than `hand_size`), no
  cards are drawn. Given a hand of 0, 5 are drawn.
- [ ] AC3 (at or under the limit): Given a deck of 10 scouts, when I play 2 Scouts (hand 5 → 6 → 7) and
  end the turn, then there is nothing to discard: `discard_needed()` is 0, the turn advances to 2, and
  the hand still has 7.
- [ ] AC4 (over the limit starts a discard): Given a deck of 10 scouts, when I play 3 Scouts (hand 8) and
  end the turn, then the turn does not advance (still turn 1), `discard_needed()` is 1, and the hand
  still has 8. `changed` is emitted.
- [ ] AC5 (discarding finishes the turn): Continuing AC4, when I call `discard_card(uid)` with a Scout in
  hand, then it returns true, that card is in the discard pile, and the turn ends by itself: turn is 2 and
  the hand has 7 (no draw, since 7 ≥ 5). With a hand of 9 (`discard_needed()` 2), the first
  `discard_card` returns true and leaves turn 1 with `discard_needed()` 1; the second ends the turn.
- [ ] AC6 (blocked while discarding): While `discard_needed()` > 0:
  - `play_error(uid)` for a card in hand is "Discard down to 7 cards first." and `play_card` fails with
    nothing changed
  - `grow_error(territory_uid)` is the same message and `grow` fails
  - calling `end_turn()` again changes nothing (still turn 1, same `discard_needed()`).
- [ ] AC7 (bad discards): `discard_card` returns false and changes nothing when no discard is pending
  (for example at the start of a turn with a hand of 5), or when the uid isn't in hand (for example the
  Capital, or a uid already discarded).
- [ ] AC8 (last turn): Given turn 20 of 20 and a hand of 8, when I end the turn, then no discard is asked
  for (`discard_needed()` stays 0) and the game ends as before.
- [ ] AC9 (config): `hand_limit` is optional in config.json and defaults to 7. A value below `hand_size`,
  or not an integer, is a load error naming config.json and `hand_limit`. `data/config.json` sets
  `"hand_limit": 7`.

## Out of scope
- Cards or effects that change the limit or discard from hand (a `discard` op).
- Discarding at any time other than the end of the turn.
- Cancelling a pending discard to go back and play cards.

## Design notes
- Config: new `hand_limit` (int ≥ `hand_size`, default 7).
- Engine API:
  - `discard_needed() -> int`: cards still to discard this cleanup; 0 when none is pending.
  - `discard_card(uid: int) -> bool`: discard one card from hand while a discard is pending; finishes
    the turn when `discard_needed()` reaches 0. Emits `changed`.
  - `end_turn()` runs cleanup, and if the hand is over the limit, stops there with a pending discard
    instead of starting the next turn. The event phase runs only once.
  - `_start_turn` draws `max(0, hand_size - hand.size())` instead of `hand_size`.
- Existing tests that relied on cleanup discarding the whole hand need updating, and each change needs
  your OK at the red checkpoint. Known one: `test_rules::test_reshuffle_when_deck_runs_out` still passes
  by coincidence but no longer causes a reshuffle, so it needs a new setup that empties the deck.
- With draw-up-to-5 and a limit of 7, the only way over the limit in the current content is net card
  draw (Scout: play 1, draw 1 → net 0 in `data/cards.json`). So the limit will rarely trigger until
  there is more draw. That's expected; the rule is in place for later content.
- UI: while `discard_needed()` > 0, the hand is in discard mode. A banner says "Discard N card(s)",
  and double-click or the keyboard play key discards the selected card, and
  E does nothing. The UI calls `discard_needed()` / `discard_card()` only.
- PLAN.md turn loop: step 2 becomes "Draw up to hand size", and step 5 becomes "Cleanup: keep your hand;
  over the hand limit, discard down to it".

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_hand_limit::test_unplayed_cards_stay_in_hand` |
| AC2 | `test_no_draw_when_hand_is_above_hand_size`, `test_empty_hand_draws_hand_size` (already passes: guards existing behavior) |
| AC3 | `test_end_turn_at_the_limit_needs_no_discard` |
| AC4 | `test_end_turn_over_the_limit_waits_for_discard` |
| AC5 | `test_discarding_down_to_the_limit_ends_the_turn`, `test_discard_two_cards_takes_two_calls` |
| AC6 | `test_play_is_blocked_while_discarding`, `test_grow_is_blocked_while_discarding`, `test_end_turn_again_does_nothing_while_discarding` |
| AC7 | `test_discard_refused_when_none_is_pending`, `test_discard_refused_for_a_card_not_in_hand`, `test_discard_refused_for_a_card_already_discarded` |
| AC8 | `test_no_discard_on_the_last_turn` |
| AC9 | `test_hand_limit_defaults_to_7`, `test_hand_limit_is_read_from_config`, `test_hand_limit_below_hand_size_is_an_error`, `test_hand_limit_must_be_an_integer`, `test_real_config_sets_hand_limit_7` |

## Manual check
- [ ] Play enough draw to go over 7, press E: the discard banner shows the right count, cards can't be
  played, and discarding with the mouse and with the keyboard each work and end the turn.
- [ ] At or under 7, E ends the turn at once and unplayed cards are still in hand.

## Log
