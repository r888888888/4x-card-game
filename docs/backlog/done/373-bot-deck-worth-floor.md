---
id: 373
title: The sim bot's renewal trashes its least valuable cards, not the first ones listed
type: feature
status: done
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

After this a renewal trashes the cards the bot values least. The negative deck's worth (the first finding) is left for
376: flooring it at 0 made the traced games worse (see the Log).

## Acceptance criteria
Dropped (the user, 2026-10-06, after the traced games in the Log): AC1 and AC2, the floor.
- ~~AC1~~: Given two fixture games (Lone ruling, 10 turns left) that differ only in the deck: one holds 2 Temples and a
  Guildhall (2 food, 2 wealth, no effect: `card_value` < 0), the other 2 Temples and a Pioneer with nothing to settle
  (counted as 0), when GenericBot values each (`GenericBot.value`, a fresh generic `Context`), then the two values are
  equal (within 0.001). A card worth less than nothing counts as 0, not below it.
- ~~AC2~~: Given a fixture game whose deck, hand and discard hold only 3 Guildhalls, and the same game with all 3
  removed (no cards to draw), when GenericBot values each, then they are equal (within 0.001): an empty deck isn't
  worth more than one of cards it wouldn't play.
- [x] AC3: Given fixture games (Lone ruling, 10 turns left), the deck of 3 Temples and a Pioneer with nothing to settle
  values less than the deck of 3 Temples alone: a 0-worth card still dilutes the draws (a guard; it held before).
- [x] AC4: Given a game that fell into Anarchy with renewal 2 owed, whose hand and deck hold 10 copies of a fixture
  order card that gains 2 food (Augury) and whose discard holds 2 Guildhalls (listed last among the options, which
  sort by name), and card values measured on turn 1 (Augury 1.0, Guildhall −1.0: while a decision is owed,
  `card_value` gives the last measured value), when GenericBot takes its turn, then the renewal trashes the 2 Guildhalls and no
  order card. (Today the Guildhalls are options 11 and 12; that pair is combination 66 of 66 and is never tried, and the bot
  trashes an Augury and a Guildhall.)
- [x] AC5: Given the AC4 game played in a rollout (cheap mode, which measures no card values), when the renewal is
  owed, then the bot still answers it with a legal renewal of 2 cards (the order of options is left as listed).

## Out of scope
- Resource hoarding (hundreds of unspent wealth late in the game, 50 food by turn 20): what there is to spend on is a
  content and balance question, not the bot's value function.
- Corvée's unrest and held unrest's weight (0 today; unrest costs through its risk and rate).
- The `docs/TODO.md` wishes for tall: building up to 3 settlements, and putting upgrades first. A separate item if
  wanted.
- The deck's worth: negative card values and the average-card model that rewards thinning to nothing. 376.
- Precedent (370) and Read the Stars (371): their take decision reaches the bot through `LegalActions.DECISIONS`.
- Balance runs and tuning (`WEIGHTS`), per CLAUDE.md.

## Design notes
- `sim/generic_bot.gd` only. No engine, loader or data change.
- `_candidates`: outside a rollout, a renewal's options are sorted by `card_value` ascending (ties in listing order)
  before `_combos`, so the 40 combinations tried are those of the least valuable cards. Each is still valued on a fork.
  In a rollout (no card values measured, and `value()` leaves out the deck's worth), the listing order stays.
- While a decision is owed (the renewal), `card_value` gives the last value measured (0 if none), so the sort uses
  values from earlier turns, as in a real game; AC4's test seeds the context's `card_values` the same way.
- Class doc and PLAN.md: the renewal's combinations are of the least valuable cards first.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC3 | `test_generic_bot::test_a_card_worth_0_still_dilutes_the_draws` (guard: passes today) |
| AC4 | `test_generic_bot::test_renewal_trashes_the_least_valuable_cards_even_when_listed_last` |
| AC5 | `test_generic_bot::test_a_rollout_still_answers_a_renewal` (guard: passes today) |

## Manual check
- [ ] Balance run (manual, per CLAUDE.md), to see that the renewal sort alone doesn't cost score:
  `scripts/sim.sh --compare <main checkout> 20` from this branch's worktree. Expect small moves only: renewal happens
  only under Anarchy.

## Log
- 2026-10-06: Found by tracing GenericBot on real data after 364–372 (scratch trace and probe scripts, not kept).
- 2026-10-06: Green, but the manual check fails. Traced the same six games (seeds 3–8, one per civ, 100 turns) on the
  base commit (cdb28833) and on this branch, on the same data. Pile-buying turns drop (Phoenicia 5 → 1, Persia 4 → 2),
  but every game scores lower: Phoenicia generic 230 → 113, Egypt tall 114 → 91, Sumer wide 603 → 549, Babylon generic
  170 → 144, Greece tall 422 → 125, Persia wide 677 → 472. Decks still drain: with the deck's worth at least 0,
  trashing any card below the average raises it, so Slash and Burn thins to nothing (Phoenicia now ends with 0 cards,
  where base kept 22). The games split from turn 1 (Greece: base builds Fishing Huts, the branch plays Corvée), so the
  floor shifts the whole opening, not just trashing. One seed per cell: not a balance run, but 6 of 6 lower.
  The average-card model is the deeper problem: it rewards thinning to the few best cards whatever the hand size and
  actions. Waiting on the user: keep only the renewal sort, or rework the deck's worth (a separate item, with a sim
  comparison).
- 2026-10-06: The user chose the renewal fix only. Removed the floor and AC1–AC2's tests; AC3–AC5 stay. The deck's
  worth goes to 376. The traced games above were run before this checkout's CLAUDE.md said balance runs are manual
  (runs of real-data bot games, including scratch traces, wait for the user); the renewal-only build was not traced.
