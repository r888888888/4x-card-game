---
id: 040
title: test_reshuffle_when_deck_runs_out no longer reshuffles; reshuffle is untested
type: bug
status: review
branch: fix/040-reshuffle-test
---

## Reproduction
- Seed: 1 (`make_engine` default); any seed gives the same result
- Steps:
  1. `make_engine({"farm": 6})`: turn 1 hand 5, deck 1, discard 0.
  2. `end_turn()`.
- Expected (what the test's comment says): the hand is discarded, 1 card is drawn from the deck, then the
  discard (5) is reshuffled into the deck and 4 more are drawn.
- Actual: since 024 the hand is kept, so the draw up to `hand_size` draws 0 cards. Hand 5, deck 1, discard 0,
  and no "Reshuffled" line in the log. The test's asserts (hand 5, deck 1, discard 0) happen to match, so it
  passes without reaching the reshuffle. No other test covers `draw` reshuffling the discard.

## Acceptance criteria
<!-- In tests/test_rules.gd, replacing test_reshuffle_when_deck_runs_out. Assert on zones, not the log. -->
- [x] AC1: Given `make_engine({"farm": 6})` (hand 5, deck 1, discard 0), when 3 hand cards are discarded with
  `discard_card` (hand 2, discard 3) and the turn ends, then the draw takes the 1 deck card, reshuffles the 3
  discarded cards into the deck and draws 2 of them: hand 5, deck 1, discard 0, and the 3 discarded uids are all
  in hand or deck.
- [x] AC2: Given the AC1 setup with seed 42 on two engines, when both do the same discards and end the turn,
  then both hands and decks hold the same uids in the same order.
- [x] AC3: Given `make_engine({"scout": 5}, {}, 1)` (Scout: draw 2; hand 5, deck 0, discard 0), when a Scout is
  played, then it draws nothing and nothing fails: hand 4, deck 0, discard 1 (the Scout), and `card_played`'s
  `drawn` is empty. (The played card is not in the discard yet while its own effects resolve, so it can't be
  reshuffled and drawn by itself. This pins current behavior.)

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_rules::test_bug_040_turn_end_draw_reshuffles_discard_into_deck` |
| AC2 | `test_rules::test_bug_040_reshuffle_is_reproducible_with_a_seed` |
| AC3 | `test_rules::test_bug_040_draw_with_empty_deck_and_discard_draws_nothing` |

## Root cause
The test was written when end of turn discarded the hand. Backlog 024 made unplayed cards stay in hand, so the
turn-end draw became 0 cards and the test stopped reaching the reshuffle; its asserts still matched by chance.

## Log
- 2026-09-29: Approved by the user ("do 040"). Replaced `test_reshuffle_when_deck_runs_out` with the three tests
  above. No production code changed: the reshuffle already works, so the new tests passed on first run. To prove
  they bite, `draw` was temporarily changed to never reshuffle: the AC1 test failed (hand 3, deck 0, discard 3)
  where the old test would still have passed; then reverted. Suite 378 → 380 tests, green.
