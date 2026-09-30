---
id: 055
title: Caravan needs 2 cities and pays with diminishing returns (trade op)
type: feature
status: review
branch: feat/055-caravan-trade
---

## Goal
Caravan's "+2 wealth per city" scales linearly and works with one city (TODO 9). Trade needs somewhere to go: a
Caravan now needs at least 2 cities, and pays 2 × ⌊√cities⌋ + ⌊total pop / 5⌋ wealth. More cities help less and less,
and pop adds a steady trickle.

## Acceptance criteria
Fixture added to TEST_CARDS: `trader`, "Trader", action, cost 1 food, effect
`{"op": "trade", "resource": "wealth", "per_root_city": 2, "pop_per": 5, "min_cities": 2}`.
Cities are city-type cards in the tableau (Capital and settled Cities). Pop is total pop (0 with population off).

- [x] AC1 (loader): `trade` needs `resource` (a known resource) and `per_root_city`, `pop_per` and `min_cities`
  (integers ≥ 1). A missing field, a non-integer, a value below 1 or an unknown resource is a load error naming the card
  and the field. `trade` with `trigger: "upkeep"` is a load error naming the card and the effect.
- [x] AC2 (too few cities): Given 1 city and 3 food, `play_error(trader)` is "Trader needs 2 cities (you have 1).".
  `play_card` returns false, and the card, food and wealth are unchanged.
- [x] AC3 (2 cities): Given 2 cities and 5 total pop, playing Trader gives +3 wealth (2×1 + 1) and costs 1 food.
- [x] AC4 (scaling): 3 cities and 10 pop give +4 (2×1 + 2). 4 cities and 16 pop give +7 (2×2 + 3). 2 cities and 4 pop
  give +2. With population off (the fixture default) and 2 cities: +2.
- [x] AC5 (text): the short card text is "Needs 2 cities\n+2 wealth ×√cities, +1 per 5 pop". The tooltip reads
  "Needs 2 cities. Gain 2 wealth × √cities (rounded down), plus 1 wealth per 5 pop."
- [x] AC6 (content): the real Caravan uses `trade` with `min_cities` ≥ 2, and the real data loads with no warnings.
  The wealth smoke test and wealth-source coverage (022) stay green.

## Out of scope
- `trade` on upkeep (e.g. a Trade Route building); a follow-up if wanted.
- Counting trade partners other than your own cities.

## Design notes
- New op `trade` (`engine/effects/trade_effect.gd`); follow the `add-effect` skill. `play_block_error` returns the
  AC2 message. Cities: count tableau cards whose type is `CardDef.CITY`.
- The Caravan in `data/cards.json` keeps cost 1 food. Record sim numbers in the Log.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_trade::test_trade_op_loads`, `test_trade::test_trade_validation`, `test_forecast::test_ops_that_change_more_than_the_forecast_restores_are_rejected_on_upkeep` (`trade` in `UPKEEP_UNSAFE`) |
| AC2 | `test_trade::test_trade_with_too_few_cities_is_refused` |
| AC3 | `test_trade::test_trade_with_2_cities_and_5_pop_gives_3_wealth` |
| AC4 | `test_trade::test_trade_scales_with_root_cities_and_pop`, `test_trade::test_trade_without_population_counts_no_pop` |
| AC5 | `test_trade::test_trade_text` |
| AC6 | `test_content::test_caravan_trades_between_at_least_2_cities`; existing `test_real_data_loads_without_warnings`, `test_every_wealth_cost_has_a_wealth_source`, `test_real_deck_has_wealth_costs_and_capital_makes_wealth` |

## Manual check
- [ ] New game (seed 1), only the Capital: Caravan's card text reads "Needs 2 cities / +2 wealth ×√cities, +1 per 5 pop";
  it is dimmed, and playing it is refused with "Caravan needs 2 cities (you have 1).".
- [ ] Settle a second city (Scout/explore, then Settler). Note total pop P and wealth W; play Caravan:
  wealth becomes W + 2 + ⌊P/5⌋.

## Log
- 2026-09-29: `trade` op in `engine/effects/trade_effect.gd`. `Effect.play_block_error` now also takes the card
  (`play_block_error(engine, card)`), so the refusal can name it; Research ignores it. Trader started in
  `test_trade.gd` during red (in `TEST_CARDS` the unknown op broke every test) and moved to `TEST_CARDS` in refactor.
- Shipped Caravan: cost 1 food, `trade` wealth, `per_root_city` 2, `pop_per` 5, `min_cities` 2.
- Balance, `scripts/sim.sh 20` (main → this branch). Cities moved > 10%: with one city the bot can't play Caravan,
  so its food goes to Settlers earlier. `cities` min 0 was on main too.

  | metric | main mean (min–max) | 055 mean (min–max) | Δ mean |
  |---|---|---|---|
  | score | 55.95 (20–106) | 59.25 (27–103) | +3.30 |
  | cities | 4.55 (0–11) | 5.35 (0–11) | +0.80 (+18%) |
  | pop | 8.80 (4–16) | 9.30 (4–16) | +0.50 |
  | techs | 7.45 (5–12) | 7.50 (5–12) | +0.05 |
  | bought | 0 | 0 | 0 |
  | era | 2 | 2 | 0 |
