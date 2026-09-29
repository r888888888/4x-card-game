---
id: 032
title: Buy cards from a supply
type: feature
status: red-review
branch: feat/032-card-supply
---

## Goal
Players can spend wealth to add more copies of existing cards to their deck, starting with Scout.
Some of the starting deck moves into a limited supply, so exploring, settling and growing
become things the player chooses to invest in. No new cards.

## Acceptance criteria
- [ ] AC1: Given config `supply: { "scout": { "price": 2, "count": 2 } }` and 3 wealth, when I
  `buy("scout")`, then it returns true, wealth is 1, a new Scout is on top of the discard,
  `supply_left("scout")` is 1, and `changed` is emitted.
- [ ] AC2: Given the same supply and 4 wealth, when I buy Scout twice in one turn, then both buys
  succeed, wealth is 0, the discard has 2 Scouts, and `supply_left("scout")` is 0. There is no limit per turn.
- [ ] AC3: `buy` returns false and changes nothing, and `buy_error` says why, when:
  (a) wealth is 1 and the price is 2 ("Scout costs 2 wealth (you have 1).");
  (b) the pile is empty ("No Scouts left in the supply.");
  (c) the card isn't in the supply, or the config has no supply ("Farm isn't in the supply.").
- [ ] AC4: `buy` is also blocked, with the same error `grow_error` gives, while the game is over,
  an explore choice is pending, research options are open, or a hand-limit discard is owed.
- [ ] AC5: The loader reports an error that names `supply`, the card id and the field when: the card id is unknown; the card is not
  an `action` or `building` (city, territory and tech are rejected); `price` is missing or less than 1;
  `count` is missing or less than 1. Without a `supply` block the config loads with an empty supply.
- [ ] AC6: `data/config.json` moves cards from `deck` to `supply`. Deck: scout 2, settler 2,
  temple 1, granary 1 (22 cards). Supply: scout (price 2, count 2), settler (3, 2), temple (3, 1),
  granary (2, 1). The real data loads with no errors.

## Out of scope
- New cards, a trade row or reveal, price decay, keyword- or tech-stocked piles.
- A per-turn buy limit or a `buy` op (for example on the Market building).
- Removing cards from the deck (retire or trade-in).
- Changing `deck_model` (it stays `fixed`; the supply is its own optional config block).

## Design notes
- Config: `"supply": { "<card_id>": { "price": <int ≥ 1>, "count": <int ≥ 1> } }`. Price is wealth only.
- Engine keeps the supply as remaining counts per card id, not as card instances. `buy` makes a new
  instance (like `create_card`) and puts it on the discard.
- New engine API: `supply()` (card_id → count left, in config order), `supply_left(card_id)`,
  `buy_price(card_id)`, `buy_error(card_id)`, `buy(card_id)`.
- UI: a Supply panel listing each card with its price and how many are left. Click a card to buy it. A card
  that can't be bought is dimmed, and its tooltip shows `buy_error`. The UI holds no rules.
- Prices are a first guess. Wealth is scarce early on (Capital +1 per turn, Caravan +2 per city), so a
  Scout costs about 2 turns of Capital income. Tune them after playtesting.
- Name: "Supply", so it doesn't clash with the Market building.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_supply::test_buying_pays_wealth_and_puts_the_card_on_the_discard`, `test_supply_lists_card_counts_left` |
| AC2 | `test_supply::test_buying_twice_in_one_turn_empties_the_pile` |
| AC3 | `test_supply::test_cannot_buy_without_enough_wealth`, `test_cannot_buy_from_an_empty_pile`, `test_cannot_buy_a_card_not_in_the_supply`, `test_cannot_buy_without_a_supply` |
| AC4 | `test_supply::test_cannot_buy_when_the_game_is_over`, `test_cannot_buy_while_an_explore_choice_is_pending`, `test_cannot_buy_while_research_options_are_open`, `test_cannot_buy_while_a_discard_is_pending` |
| AC5 | `test_supply::test_supply_block_is_normalized`, `test_supply_defaults_to_empty`, `test_supply_unknown_card_is_error`, `test_supply_rejects_cities_territories_and_techs`, `test_supply_price_must_be_at_least_1`, `test_supply_count_must_be_at_least_1`, `test_supply_entry_must_be_an_object` |
| AC6 | `test_content::test_real_supply_sells_scouts`, `test_every_supply_card_also_starts_in_the_deck`; changed: `test_real_deck_has_growth_cards` counts deck + supply |

## Manual check
- [ ] The Supply panel shows Scout, Settler, Temple, Granary with price and count left.
- [ ] Buying a Scout spends wealth, lowers the count, and the Scout later turns up in hand.
- [ ] An empty or unaffordable pile is dimmed and its tooltip says why.

## Log
- 2026-09-29: Scoped from the marketplace brainstorm: supply of existing cards only, Scout required.
  User chose: Scout/Settler/Temple/Granary, per-card price in config, no buy limit, limited piles.
- 2026-09-29: Approved by the user.
