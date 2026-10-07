---
id: 376
title: The sim bot values its deck by what a turn can play, so it neither buys junk nor thins to nothing
type: feature
status: draft
branch: feat/376-bot-deck-worth-model
---

## Goal
GenericBot's deck's worth (`_deck_worth`) is the average `card_value` over the deck, hand and discard. With the
12-card starting deck and Slash and Burn's `trash` (369), that model misleads the bot two ways (traced games, 373's Log):

- A card that costs more than it gives has a negative value (Land Grants −5.05), so the average goes below 0. Any
  0-worth card then looks like an improvement: the bot buys whole piles it never plays (6 Sea Trades with no port; 6
  Caravans and 4 Scouts in one turn).
- The average rewards thinning: trashing any card below the average raises it, whatever the hand size and actions. A
  deck of one good card is the "best" deck. Tall Greece and tall Egypt ended with 0 and 1 cards.

Flooring each card at 0 (373's first try) stopped the pile-buying but made the thinning worse (with the average at 0
or above, every card below it is worth trashing) and every traced game scored lower. A turn plays at most
`_plays_a_turn` cards out of a hand of `hand_size`, so what the deck is worth is roughly the value of the best plays a
drawn hand allows: a card the bot wouldn't play costs a draw, and cutting the deck below a hand's worth of good cards
loses plays.

## Acceptance criteria
<!-- Draft: depends on the open question below. Shape of the criteria once it's answered: -->
- [ ] AC1: A card with a negative `card_value` lowers the deck's worth no more than a dead card (0) does.
- [ ] AC2: Given a deck with at least a hand of cards worth more than 0, trashing a 0-worth card raises the deck's
  worth (thinning still pays while the hand fills with good cards).
- [ ] AC3: Given a deck, hand and discard of exactly `_plays_a_turn` cards worth more than 0, trashing any one of them
  lowers the deck's worth (thinning below what a turn plays loses value).
- [ ] AC4: An empty deck is worth less than any deck holding a card worth more than 0.

## Open questions
- Which model: (a) the expected sum of the best `plays` of `hand_size` cards drawn from the deck (exact, costlier), or
  (b) the average of the best `min(n, hand_size)` card values × `plays` (cheap, approximate)? Recommended: (b), then
  compare.
- Acceptance beyond the criteria: a 20-seed `scripts/sim.sh --compare` against `main` (manual, the user's run) should
  show no strategy's score falling. Is that the bar, or is a fall acceptable if decks stop draining?

## Out of scope
- `WEIGHTS.deck` (0.05) and other tuning: a balance item.
- Renewal's choice of cards: 373.

## Design notes
- `sim/generic_bot.gd` only (`_deck_worth`, maybe `_plays_a_turn`). No engine, loader or data change.
- The forecast cache doesn't read the deck, so nothing there changes.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_generic_bot::test_…` |

## Manual check
- [ ] `scripts/sim.sh --compare <main checkout> 20` from the item's worktree: scores per strategy, and no drained decks.

## Log
- 2026-10-06: Split out of 373 after the floor alone made the traced games worse.
