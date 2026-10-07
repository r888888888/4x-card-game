---
id: 373
title: The sim bot counts a card it wouldn't play as worth 0, and renews away its worst cards
type: feature
status: in-progress
branch: feat/373-bot-deck-worth-floor
---

## Goal
The recent content gives the deck's makeup more weight: the starting deck went from 8 cards to 12 (368, 369), Slash and
Burn trashes a card (369's `trash`), and renewal under Anarchy trashes cards too. GenericBot handles the new actions
(sea slots, unique creates, Hunt, Sea Trade, Precedent) through `legal_actions`, but its deck's worth goes wrong on
the real data. Traced games (seeds 3–8, one per civ and strategy, 2026-10-06) showed:

- **A card it wouldn't play drags the deck's worth negative.** `_deck_worth` averages `card_value` over the deck,
  hand and discard, and a card that costs more than it gives has a negative value (Land Grants −5.05 at Phoenicia's
  turn 54, with 4 copies held). Below-zero averages make any 0-value card look like an improvement, so the bot buys
  whole piles it never plays (6 Caravans and 4 Scouts in one turn; 6 Sea Trades with no port). They also make an
  empty deck look better than a weak one, so the bot trashes and renews its deck away: tall Greece ended with no cards
  and tall Egypt with 1. A card in the deck that you'd never play costs a draw, not value: it should count as 0.
- **Renewal only tries the first 40 combinations, in listing order** (`RENEWAL_COMBOS`). With a 12-card deck, 2 or more
  cards to renew is past 40 combinations (66 for 2 of 12), so the bot mostly trashes the first cards listed (the hand,
  then the deck), whatever they are worth. Babylon renewed its Research away.

After this the bot keeps a playable deck, and the sim's numbers for the new starting deck and the trash mean something.

## Acceptance criteria
- [ ] AC1: Given two fixture games (Lone ruling, 10 turns left) that differ only in the deck: one holds 2 Temples and a
  Guildhall (2 food, 2 wealth, no effect: `card_value` < 0), the other 2 Temples and a Pioneer with nothing to settle
  (counted as 0), when GenericBot values each (`GenericBot.value`, a fresh generic `Context`), then the two values are
  equal (within 0.001). A card worth less than nothing counts as 0, not below it.
- [ ] AC2: Given a fixture game whose deck, hand and discard hold only 3 Guildhalls, and the same game with all 3
  removed (no cards to draw), when GenericBot values each, then they are equal (within 0.001): an empty deck isn't
  worth more than one of cards it wouldn't play.
- [ ] AC3: Given the AC1 games with the Pioneer's deck also holding a 3rd Temple, the deck of 3 Temples and a Pioneer
  still values less than the deck of 3 Temples alone: a 0-worth card still dilutes the draws (this already holds; it
  guards the floor against dropping 0-worth cards from the count).
- [ ] AC4: Given a game that fell into Anarchy with renewal 2 owed, whose hand and deck hold 10 copies of a fixture
  order card that gains 2 food (Augury) and whose discard holds 2 Guildhalls (listed last among the options, which
  sort by name), and card values measured on turn 1 (Augury 1.0, Guildhall −1.0: while a decision is owed,
  `card_value` gives the last measured value), when GenericBot takes its turn, then the renewal trashes the 2 Guildhalls and no
  order card. (Today the Guildhalls are options 11 and 12; that pair is combination 66 of 66 and is never tried, and the bot
  trashes an Augury and a Guildhall.)
- [ ] AC5: Given the AC4 game played in a rollout (cheap mode, which measures no card values), when the renewal is
  owed, then the bot still answers it with a legal renewal of 2 cards (the order of options is left as listed).

## Out of scope
- Resource hoarding (hundreds of unspent wealth late in the game, 50 food by turn 20): what there is to spend on is a
  content and balance question, not the bot's value function.
- Corvée's unrest and held unrest's weight (0 today; unrest costs through its risk and rate).
- The `docs/TODO.md` wishes for tall: building up to 3 settlements, and putting upgrades first. A separate item if
  wanted.
- Whether the deck's worth should model the best plays of a hand rather than the average card. The floor keeps the
  average model.
- Precedent (370) and Read the Stars (371): their take decision reaches the bot through `LegalActions.DECISIONS`.
- Balance runs and tuning (`WEIGHTS`), per CLAUDE.md.

## Design notes
- `sim/generic_bot.gd` only. No engine, loader or data change.
- `_deck_worth`: `total += maxf(0.0, card_value(...))`; n still counts every card (dead or not).
- `_candidates`: outside a rollout, a renewal's options are sorted by `card_value` ascending (ties in listing order)
  before `_combos`, so the 40 combinations tried are those of the least valuable cards. Each is still valued on a fork.
  In a rollout (no card values measured, and `value()` leaves out the deck's worth), the listing order stays.
- While a decision is owed (the renewal), `card_value` gives the last value measured (0 if none), so the sort uses
  values from earlier turns, as in a real game; AC4's test seeds the context's `card_values` the same way.
- Class doc: the value line about the deck's worth says a card counts as at least 0, and the renewal line says the
  least valuable options are combined first.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_generic_bot::test_a_card_worth_less_than_nothing_counts_as_0` |
| AC2 | `test_generic_bot::test_an_empty_deck_is_worth_no_more_than_cards_it_wouldnt_play` |
| AC3 | `test_generic_bot::test_a_card_worth_0_still_dilutes_the_draws` (guard: passes today) |
| AC4 | `test_generic_bot::test_renewal_trashes_the_least_valuable_cards_even_when_listed_last` |
| AC5 | `test_generic_bot::test_a_rollout_still_answers_a_renewal` (guard: passes today) |

## Manual check
- [ ] Trace a few real-data games (one per strategy, 100 turns): no game ends with fewer cards in its deck, hand and
  discard than a hand, and no turn buys a whole pile of a card the bot then never plays.

## Log
- 2026-10-06: Found by tracing GenericBot on real data after 364–372 (scratch trace and probe scripts, not kept).
