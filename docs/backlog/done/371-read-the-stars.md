---
id: 371
title: Read the Stars looks at the top 3 cards and takes one (Astronomy)
type: feature
status: done
branch: feat/371-read-the-stars
---

## Goal
Give the late game a way to dig for the card it needs: **Read the Stars**, an era-3 action that Astronomy unlocks in
the supply (Astronomy unlocks nothing today). It looks at the top 3 cards of your deck; you take one into your hand
and the other two go to the discard. This needs a new effect op, `look`, and reuses the `take` decision from 370,
adding a destination for the cards not taken.

Depends on 370 (the `take` decision kind).

## Acceptance criteria
- [x] AC1: Given a TEST_CARDS card with `{op: look, count: 3}` in hand and a deck of 5 known cards, when it is
  played, then the top 3 leave the deck, `pending()` is `{kind: take, options: [those 3 uids, top first]}`, and the
  hand is otherwise unchanged.
- [x] AC2: Given AC1's owed take, when the player takes one option, then it goes to the hand, the other two go to the
  discard, the deck holds the 2 cards that were below them in their order, and nothing is owed.
- [x] AC3: Given a deck of 1 card and a discard of 4, when the look card is played, then the deck's card and, after
  the discard is reshuffled into the deck (as `draw` does), 2 more are the options; the look card itself is never an
  option.
- [x] AC4: Given only one card in the deck and the discard together, then it goes to the hand at once and nothing is
  owed; given none, the card plays, nothing moves and nothing is owed.
- [x] AC5: `count` is an integer from 2 to 5, default 3; a missing count loads as 3, and a count of 1 or 6 or a
  non-integer is an error naming the card and `count`. The loader rejects `look` on `upkeep`, `start` and events.
  Rules text: "Look at the top 3 cards of your deck: take 1 into your hand, discard the rest".
- [x] AC6: While the take is owed, the cards looked at are in a zone that `GameState.copy()` copies (the suite's copy
  guard), and an engine copied mid-decision pays it the same way.

## Out of scope
- Putting the rest back on top or at the bottom (the user chose the discard, 2026-10-06).
- Balance: the price and pile size below are first guesses.

## Design notes
- **New op `look`** (`engine/effects/look_effect.gd`, `add-effect` skill): field `count` (2–5, default 3).
  `opens_choice()` true, `upkeep_ok()` false. `apply` calls a public engine helper that moves up to `count` cards
  from the top of the deck into a holding zone, reshuffling the discard in when the deck runs out, as
  `EngineCore.draw` does. The played card is out of every zone while it resolves, so it can't be looked at.
- **Holding zone**: explore's `reveal` zone holds revealed territories while an explore is owed. Only one decision is
  owed at a time, so reusing `reveal` may work; check that nothing in `ui/` draws `reveal` as territories. Otherwise
  add a zone to `GameEngine.ZONES`.
- **`take` (from 370) gains `rest`**: `state.pending.rest = "discard"` sends the options not taken to the discard
  when the take is paid; 370's recall leaves `rest` unset and the others stay where they are. The overlay, guard
  tables and `legal_actions` entry are 370's.
- Bot: GenericBot answers the take by value, as for 370.
- **Content** (`data/cards.json`, `data/config.json`):
  - `read_the_stars`, Read the Stars, action, cost —, vp 0, effects `look` 3. Flavor (§18, 124 characters, ends on
    an image): "Night after night the astronomers of Babylon chart the planets from the temple roof and write down what
    each sign foretells."
  - Astronomy: add `{op: unlock, card: read_the_stars}`.
  - `supply`: `read_the_stars` at price 5, count 4, `locked`.
- PLAN.md: the op in the card data format, `rest` on the `take` kind, Read the Stars under Astronomy.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_look::test_look_owes_a_take_of_the_top_three_cards` |
| AC2 | `test_look::test_taking_one_sends_the_rest_to_the_discard` |
| AC3 | `test_look::test_a_short_deck_reshuffles_the_discard_in` |
| AC4 | `test_look::test_a_lone_card_goes_to_the_hand_at_once`, `test_look::test_with_no_cards_to_look_at_nothing_happens` |
| AC5 | `test_look::test_look_loads`, `test_look::test_look_validation`, `test_look::test_look_card_text` |
| AC6 | `test_look::test_the_cards_looked_at_are_in_a_copied_zone_and_a_fork_pays_the_take_alike` |

## Manual check
- [ ] Shipped data: Read the Stars is a locked supply pile (price 5, 4 copies) until Astronomy; its text reads look at
  the top 3 cards of your deck, take 1 into your hand, discard the rest.
- [ ] `godot --path . -- --seed 5 --turns 70`: research Astronomy, buy Read the Stars and play it. The overlay shows 3
  cards, a click puts one in the hand, and the discard counter goes up by 2.
- [ ] Play it with a nearly empty deck: the discard reshuffles in, as on a draw.

## Log
<!-- Decisions and surprises during implementation, newest last. -->
- Spec: the cards not taken go to the discard (user, 2026-10-06).
- Build: the looked-at cards wait in 370's `offered` zone (approved at the red checkpoint), not `reveal`; `take` always
  sends the rest to the discard, so no `rest` field was needed. `EngineCore.reshuffle()` came out of `draw` so `look`
  reshuffles the same way.
- Build: Astronomy left `test_content`'s pure-discount tech list, now that it unlocks Read the Stars.
- Balance worry: none measured; price 5 and 4 copies are first guesses.
