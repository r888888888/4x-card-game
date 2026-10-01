---
id: 108
title: Civilizations can make some cards cheaper
type: feature
status: review
branch: feat/108-civilization-discounts
---

## Goal
A civilization can carry a standing discount: while it's yours, some cards cost less to play, buy or research.
This gives Babylon (astronomy and scholarship), Phoenicia (trade) and Egypt (monument builders) a signature bonus.

## Acceptance criteria
Fixtures: a test civilization with `discounts: [{"type": "tech", "wealth": 1}]`, one with
`[{"tag": "wonder", "wealth": 3}]`, and one with `[{"supply": true, "wealth": 1}]`.

- [x] AC1 (loader): civilization field `discounts` is optional: a list of {one filter, one or more resource amounts}.
  The filter is `type` (a card type), `tag` (any tag) or `supply: true`. Amounts are ints ≥ 1 of known resources.
  An unknown type or resource, a missing filter, two filters in one entry, or an amount < 1 is a load error naming
  the card and `discounts`. On another card type it's an unknown-field warning (it's in `DataLoader.TYPE_FIELDS`).
- [x] AC2 (tech): with the tech discount, a tech with printed cost 4 has `tech_cost` 3; with the prereq discount and
  passes it still stacks, and never goes below 1. `buy_tech` charges 3 and `buy_tech_error` uses 3.
- [x] AC3 (play): new query `play_cost(uid) -> Dictionary` returns a hand card's cost after discounts. With the wonder
  discount, a wonder costing 12 wealth has `play_cost` {wealth: 9}; with 9 wealth `play_error` is "" and `play_card`
  leaves 0 wealth. A cost never goes below 0 per resource. A card without the tag is unchanged.
- [x] AC4 (supply): with the supply discount, a supply pile priced 3 has `buy_price` 2, `buy` charges 2, and a pile
  priced 1 costs 0 (still buyable, still limited by its count).
- [x] AC5: with no civilization, or a civilization with no `discounts`, every cost equals today's.

## Out of scope
- Discounts from governments, techs or buildings (the lookup should make that easy later, but no content uses it).
- Card text for discounts beyond one generated line per entry, e.g. "Techs cost 1 less wealth."
- Discounting actions: a card played from hand always uses 1 action (127); `play_cost` covers resources only.

## Design notes
- New `CardDef` field `discounts` (civilization only, via `TYPE_FIELDS`). New module (e.g. `engine/discounts.gd`);
  `game_engine.gd` only gets the `play_cost` delegate (after 125's split).
- Discounts stay their own field, not a key of 129's `modifiers`: an entry needs a filter, not just a number. When
  discounts spread to other card types, collect them over the same cards as `Modifiers.total` (working tableau,
  `ALWAYS_ON_ZONES`, active events).
- With the action economy (127), resources pile up and actions are the bottleneck, so a discount is worth less than
  when this was written; note it for the balance item rather than raising the amounts here.
- Card text is generated: "Techs cost 1 less wealth.", "Wonders cost 3 less wealth.", "Supply cards cost 1 less
  wealth."
- UI shows the discounted cost where it shows a live cost (hand cards, supply prices, tech costs), by calling the
  engine queries.
- Content after this item: Babylon gets the tech discount, Phoenicia the supply discount, Egypt the wonder discount.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_discounts::test_discounts_load`, `test_discounts_validation`, `test_discount_text` |
| AC2 | `test_discounts::test_a_tech_discount_lowers_tech_cost_and_what_buy_tech_charges`, `test_a_tech_discount_stacks_with_passes_and_prereqs_but_never_below_1` |
| AC3 | `test_discounts::test_a_tag_discount_lowers_play_cost_and_what_a_play_charges`, `test_a_discount_never_takes_a_cost_below_0_and_skips_other_cards` |
| AC4 | `test_discounts::test_a_supply_discount_lowers_buy_price_and_what_buy_charges` |
| AC5 | `test_discounts::test_costs_are_unchanged_without_discounts` |

## Manual check
- [ ] As Babylon, tech costs in the tech tree and the research choice are 1 lower than printed (Mining 1 instead
  of 2). As Phoenicia, the Buy Cards screen's prices are 1 lower (Scout 1 wealth). As Egypt, a Pyramids in hand
  shows "9 wealth" on its face, and playing it with 9 wealth works. Each civilization's card (new game screen, the
  civilization modal) lists its discount line.

## Log
- A type or tag discount only lowers costs to play or research; only a `supply: true` entry lowers supply prices.
- The hand card face asks `play_cost` (falling back to the printed cost when the card isn't in the hand yet); card
  details still show the printed cost.
- Balance worry (for the balance item): with actions the bottleneck (127), discounts may matter less; Egypt's −3 on
  a 12-wealth wonder is the biggest.
- 2026-09-30: noted the action economy (127) and 129's `modifiers`; scope and criteria unchanged.
