---
id: 232
title: Supply cards show their play cost, with the buy price on a tag below
type: feature
status: red-review
branch: feat/232-supply-price-tag
---

## Goal
On the supply screen the player sees both numbers that matter: what a card costs to play (in the title row, as on a
hand card, after the civilization's discounts) and what it costs to buy (on a gold "Buy" tag hanging below the
card, with the copies left under it). Both are in wealth for most buildings, so the two must not read alike.
Farm joins the supply, open from the start; Mine stays a locked pile, as now.

## Acceptance criteria
- [ ] AC1: Given a civilization with the discount `{tag: wonder, wealth: 3}` and supply piles for a 12-wealth wonder
  and a 2-wealth, 1-food wonder, when the engine is asked for a pile's play cost (`supply_play_cost(card_id)`), then
  it returns `{wealth: 9}` and `{wealth: 0, food: 1}`; with no civilization it returns the printed `{wealth: 12}`.
- [ ] AC2: Given a supply discount (`{supply: true, wealth: 1}`) and no tag or type discount, when the play cost of a
  supply pile is asked, then the supply discount is not taken off it (it returns the printed cost); the buy price
  is still lowered by 1 as now.
- [ ] AC3: Given a card id that is not a supply pile (a known card, or no card at all), when its supply play cost is
  asked, then it returns `{}`.
- [ ] AC4: Given the supply screen open as that civilization, then the 12-wealth wonder's pile card shows a Cost row
  in its title row with the entry `wealth` "9" (the same row a hand card shows), and a pile with no play cost shows
  an empty Cost row.
- [ ] AC5: Given the supply screen open on a pile with price 3 and 6 copies left, then neither the price nor the
  count is on the card face; a tag below the card reads "Buy" and "3" with the wealth glyph, and a label below the
  tag reads "6 left". After one buy they read "3" and "5 left".
- [ ] AC6: Given a pile the player can't buy (too little wealth, or sold out), then the card dims and its tooltip
  leads with the reason as now, and its tag dims with it (modulate alpha below 1); a buyable pile's tag doesn't.

## Out of scope
- Colouring a supply card's play cost WARN for resources the player is short of: on the supply you are buying, not
  playing, so the play cost stays in TEXT.
- Changing how a pile is bought (a click on the card, as now) or the screen's layout beyond the tag.
- Balance of Farm's price and pile size (see Manual check and Log).

## Design notes
- New engine API: `GameEngine.supply_play_cost(card_id) -> Dictionary`, `Discounts.cost(self, card_db[card_id])` for
  a supply pile, `{}` otherwise. `play_cost(uid)` only finds hand cards.
- `CardFace.build` shows the Cost row when `in_hand`; the supply needs it on a non-hand card. Pass the cost in
  (for example a `cost` argument or a `CardView.set_play_cost(cost)` that adds the row) instead of having the face
  ask the engine for a uid it can't resolve.
- `CardView.set_buy_info(price, left, error)` keeps its signature but stops writing `BuyInfo` on the face. The tag is
  a node below the card in `SupplyScreen`'s slot (the slot grows by the tag's height), tinted `Palette.WEALTH` with
  `TEXT_ON_ACCENT` text, glyph from `Icons.glyph(GameEngine.WEALTH, …)`. Its spacing and radius are `Tokens` steps.
- Data: add `"farm": {"price": 2, "count": 6}` to `data/config.json`'s supply (Pasture's numbers; Farm and Pasture
  share cost and effect).

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_discounts::test_a_supply_piles_play_cost_takes_off_the_civilizations_tag_discount` |
| AC2 | `test_discounts::test_a_supply_discount_lowers_the_buy_price_but_not_the_play_cost` |
| AC3 | `test_discounts::test_a_card_with_no_supply_pile_has_no_supply_play_cost` |
| AC4 | `test_supply_screen::test_a_pile_card_shows_its_discounted_play_cost_in_its_title_row` |
| AC5 | `test_supply_screen::test_the_buy_price_is_on_a_tag_below_the_card_with_the_copies_left_under_it`, `test_the_tag_and_count_follow_a_buy` |
| AC6 | `test_supply_screen::test_a_pile_that_cant_be_bought_dims_its_tag_too` |

## Manual check
- [ ] Open the supply on turn 1: Farm is there, its tag reads "Buy ◎ 2", "6 left" under it, and its title row
  shows 1 food, 2 wealth (1 food, 1 wealth as the civilization with the farm discount).
- [ ] The tag reads as part of the card (it lifts with it on hover and dims with it), and the play cost and buy
  price are easy to tell apart at a glance.
- [ ] Farm's supply numbers (price 2, 6 copies) look right for review.
- [ ] Mine still appears only after its tech.
- [ ] Data: `farm` is in `data/config.json`'s supply, not locked; `mine` is still there, locked. (Was AC7: a content
  test may not name card ids, so this is a manual check.)

## Log
- Farm's price and pile size weren't specified; assumed Pasture's (price 2, 6 copies). Balance worry: Farm starts
  unlocked while Pasture is locked behind a tech, so cheap early Farms may crowd out other buys. Leave tuning to a
  balance item.
- Red: AC7 (Farm and Mine in the shipped supply) moved to Manual check: content tests assert invariants, never
  per-card facts. AC1–AC4 use fixture wonders (Obelisk, Cairn) and a Builders civilization instead of the real Farm.
- Red: the UI tests need `SupplyScreen.price_tag(view) -> Control` and `SupplyScreen.copies_left(view) -> Label`.
