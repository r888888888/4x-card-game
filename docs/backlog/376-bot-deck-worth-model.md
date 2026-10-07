---
id: 376
title: The sim bot values its deck by what a turn can play, so it neither buys junk nor thins to nothing
type: feature
status: in-progress
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
or above, every card below it is worth trashing) and every traced game scored lower. A turn draws a hand of
`hand_size` and plays at most `_plays_a_turn` of it (2–3 of 5 under a government), the best ones. So what the deck is
worth is the expected value of the best plays of a drawn hand: a card the bot wouldn't play costs a draw at most, and
cutting the deck below a turn's plays of good cards loses plays.

## Acceptance criteria
<!-- Draft until the open questions are answered. Fixtures: bot_game with a government whose actions are fewer than
the hand of 5 (Lone, 1 action; Band, 2), so the best-of-the-hand model is told apart from a random-plays one. -->
- [ ] AC1: A card with a negative `card_value` lowers the deck's worth no more than a dead card (0) does.
- [ ] AC2: Adding a card worth 0 or less to the deck never raises its worth (the pile-buying). Today it does whenever
  the average is below 0.
- [ ] AC3: Given more cards than a hand, trashing a 0-worth card never lowers the deck's worth, and raises it when a
  hand could come up short of good cards for a turn's plays (thinning still pays while it fills the plays).
- [ ] AC4: Given a deck, hand and discard of exactly `_plays_a_turn` cards worth more than 0, trashing any one of them
  lowers the deck's worth (thinning below what a turn plays loses value).
- [ ] AC5: An empty deck is worth less than any deck holding a card worth more than 0.
- [ ] AC6: With fewer plays than the hand, the worth counts the best plays of a drawn hand, not random ones: given
  values a > b > 0, a deck of one a and one b at 1 play a turn is worth what a deck of one a alone is (the b is never
  played). Exact value against a hand-computed expectation for a small deck larger than a hand.
- [ ] AC7: SimStats reports a `deck_end` metric: the cards in the deck, hand and discard at the game's end, so a
  compare shows drained decks.

## Open questions
- **Approved test to rewrite: approved by the user, 2026-10-06.** `test_generic_bot::test_a_card_worth_0_still_dilutes_the_draws`
  (373's AC3) compares 3 Temples and a dead Pioneer against 3 Temples. Four cards are fewer than a hand of 5, so every
  card is drawn every turn and the Pioneer costs nothing: under any draw-based model the two are equal and the test
  fails. Proposed: the same check on a deck larger than a hand (6 Temples and a Pioneer against 6 Temples), which AC3
  then covers.
- Acceptance beyond the criteria: a 20-seed `scripts/sim.sh --compare` against `main` (manual, the user's run) should
  show no strategy's score falling. Is that the bar, or is a fall acceptable if decks stop draining?
- If the compare shows (a) thinning too far (see Design notes, risks), fall back to (c)?

## Out of scope
- `WEIGHTS.deck` (0.05) and other tuning: a balance item.
- Renewal's choice of cards: 373.
- Permanents counted as recurring (Design notes): a follow-up item if the compare points at it.

## Design notes
- `sim/generic_bot.gd` (`_deck_worth`, the deck term in `value()`) and `sim/sim_stats.gd` (`deck_end`). No engine,
  loader or data change. The forecast cache doesn't read the deck, so nothing there changes.
- **Model (a), chosen: the expected sum of the best `plays` of a drawn hand.** Floor each card's value at 0 (dead
  cards and cards with no target count 0, as now), sort descending, n cards, h = min(hand_size, n). The card in place
  i (i better cards above it) is played when it is drawn and fewer than `plays` of the better ones are drawn with it:
  `T = Σ vᵢ · (h/n) · Σ_{k<plays} C(i,k)·C(n−1−i, h−1−k) / C(n−1, h−1)`. A sort plus O(n · plays) per `value()`: not
  costly (the draft assumed it was). Checked against a 200,000-hand Monte Carlo on a 12-card example (4.420 vs 4.421).
  `value()` adds `w.deck × ahead × T`; T replaces `plays × average`, so `_plays_a_turn` moves inside it.
- Models weighed (12-card example `[3,3,2,2,1.5,1,1,0.5,0,0,−2,−5]`, hand 5, 2 plays; scratch script, no games):

  | Model | add a 0 card | add a −5 card | greedy thinning stops at |
  |---|---|---|---|
  | current average | −0.09 (+ when the average is < 0) | −0.86 | `[3,3]` |
  | 373's floor | −0.18 | −0.18 | `[3,3]` |
  | (b) best `hand` cards averaged × plays | 0 | 0 | never thins |
  | (c) floored sum ÷ max(n, hand) × plays | −0.18 | −0.18 | the best 5 |
  | (a) best plays of a drawn hand | −0.19 | −0.19 | the best 2, the rest neutral |

  (b) is dropped: it assumes every hand is the deck's best, so dead cards cost nothing (fails AC3) and a decent card
  past the best 5 is worth 0. (c) is (a) with the bot playing a random `plays` of the hand instead of the best: equal
  to (a) when a turn plays the whole hand (no government), a one-liner, but it overstates what weak cards cost.
- **Risks.** (a) stops thinning at `plays` good cards; the rest are neutral. If those are permanents, the deck empties
  once they're played. (a)'s worth is roughly 2–4× the current one for the same deck (the best cards, no negatives), so
  the deck term weighs more at the same `WEIGHTS.deck`: the compare mixes the model change with that.
- **Permanents (follow-up, not here).** A building goes to the tableau when played (`CardPlay._destination`), yet the
  deck term counts every card as if it came back each turn (× turns ahead). So playing a good permanent lowers the
  deck's worth, and under the current average playing a negative one raised it. Likely why 373's floor shifted the
  openings (Fishing Huts → Corvée); untested.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_generic_bot::test_a_card_worth_less_than_nothing_counts_as_a_dead_card` |
| AC2 | `test_generic_bot::test_adding_a_card_worth_0_or_less_never_raises_the_decks_worth` |
| AC3 | `test_generic_bot::test_trashing_a_dead_card_pays_when_a_hand_can_come_up_short`, `…::test_trashing_a_dead_card_never_lowers_the_decks_worth`, `…::test_a_card_worth_0_still_dilutes_the_draws` (373's, rewritten; all three guards: pass today) |
| AC4 | `test_generic_bot::test_thinning_below_a_turns_plays_loses_value` |
| AC5 | `test_generic_bot::test_an_empty_deck_is_worth_less_than_one_with_a_card_worth_something` (guard: passes today) |
| AC6 | `test_generic_bot::test_turn_worth_counts_the_best_plays_of_a_drawn_hand`, `…::test_turn_worth_matches_every_hand_tried`, `…::test_a_card_a_turn_never_plays_adds_nothing` (guard) |
| AC7 | `test_sim::test_376_deck_end_counts_the_cards_drawn_from`; `test_sim::test_sim_stats_reports_mean_min_max_per_metric` (its metric list gains `deck_end`) |

## Manual check
- [ ] `scripts/sim.sh --compare <main checkout> 20` from the item's worktree: scores per strategy, and `deck_end` (no
  drained decks).

## Log
- 2026-10-06: Split out of 373 after the floor alone made the traced games worse.
- 2026-10-06: Investigated the models (scratch math on an example deck, no bot games): (a) has a cheap closed form, (b)
  fails the criteria, (c) is (a) without the choice. Chose (a); reworded AC2→AC3, added AC2 (pile-buying), AC6 (best,
  not random, plays) and AC7 (`deck_end`). Found that 373's approved dilution test conflicts with any draw-based model
  (open question).
- 2026-10-06: The user approved rewriting 373's dilution test. Red: the rewrite plays under Stewards (a turn plays the
  whole hand), since under Lone's 1 play a Pioneer among 6 Temples never costs a play.
