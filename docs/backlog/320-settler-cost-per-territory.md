---
id: 320
title: Settling costs more for each territory you hold
type: feature
status: ready
branch: feat/320-settler-cost-per-territory
---

## Goal
Each new settlement costs more than the last. A card may set `cost_per_territory`, which adds to its cost once per
settled territory. The real Settler costs 5 food plus 1 per territory, so the 2nd settlement costs 6 food and the
12th costs 16. Expansion slows on the way to 319's administration cap, not only after it. The price shown on the hand
card and the supply pile is always the current one.

## Acceptance criteria
Fixtures: a Settler-like action with cost `{food: 5}`, `"cost_per_territory": {"food": 1}` and a `settle` effect, a
frontier territory to settle.

- [ ] AC1: The price grows with the realm: with 1 settled territory, `play_cost(uid)` is `{food: 6}`; with 3 it is
  `{food: 8}`. Frontier territories don't count. A card without `cost_per_territory` costs its printed cost.
- [ ] AC2: Paying it: with 3 territories and 8 food, playing it pays 8, settles the frontier territory and leaves 0
  food. With 7 food, `play_error` is the usual price refusal naming food, and nothing changes.
- [ ] AC3: It counts at once: with 1 territory, 2 copies in hand and 13 food, the first play costs 6, and right after
  it the second's `play_cost` is `{food: 7}`.
- [ ] AC4: Discounts come off after the surcharge: with a civilization discount `{tag: "expand", food: 2}` and 3
  territories, the cost is `{food: 6}`. A cost never goes below 0 per resource. `supply_play_cost(id)` for its pile
  gives the same price as `play_cost` would for a copy in hand.
- [ ] AC5: Loader and text: `cost_per_territory` is `{resource: int ≥ 1}` over config resources (an unknown resource
  or a value < 1 is a load error naming the card, `cost_per_territory` and the value). Unrest in it is the usual
  "unrest can't be paid" error (`Fields.unpayable`). On a `project` card it's a load error. The card's text gains
  "Costs 1 more food for each territory you hold.". Real data (content invariant): every card with a `settle` effect
  sets `cost_per_territory`.

## Out of scope
- Admin unrest (319) and the bot (321). The bot already pays whatever `play_cost` says and values the fork after it,
  so it sees the price with no change; 321 checks that.
- Scaling explore (Scout) or tech costs by territories.
- Tuning the Settler's base price or step: the balance item after 321.

## Design notes
- Data: card field `"cost_per_territory": {resource: n}` on any card type that is played or built with a cost (not a
  general `TYPE_FIELDS` entry unless the loader needs one). `CardDef.cost_per_territory: Dictionary`.
- Engine: one place adds it: `Discounts.cost` (or `CardPlay.cost_to_play` before the discounts) computes printed cost
  + `cost_per_territory` × settled territories, less the discounts, clamped at 0. `play_cost`, `supply_play_cost`,
  `build_cost`, `play_error` and the bot all go through it, so the hand card (`card_face.gd`) and the supply screen
  show the current price with no UI change.
- Settled territory count: the same count as 319.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_cost_per_territory::test_…` |

## Manual check
- [ ] Shipped: Settler 5 food + 1 food per territory (review before merging).
- [ ] A Settler in hand shows its current price, which goes up after each settlement. The supply pile shows the same
  price. The card's text names the step.

## Log
- 2026-10-05: specced with the user with 319 as the two halves of a soft cap of about 12 settlements. Assumed linear
  (+1 food per territory) with discounts after the surcharge; the steep part of the curve is 319's unrest.
