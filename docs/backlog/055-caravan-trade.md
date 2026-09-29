---
id: 055
title: Caravan needs 2 cities and pays with diminishing returns (trade op)
type: feature
status: ready
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

- [ ] AC1 (loader): `trade` needs `resource` (a known resource) and `per_root_city`, `pop_per` and `min_cities`
  (integers ≥ 1). A missing field, a non-integer, a value below 1 or an unknown resource is a load error naming the card
  and the field. `trade` with `trigger: "upkeep"` is a load error naming the card and the effect.
- [ ] AC2 (too few cities): Given 1 city and 3 food, `play_error(trader)` is "Trader needs 2 cities (you have 1).".
  `play_card` returns false, and the card, food and wealth are unchanged.
- [ ] AC3 (2 cities): Given 2 cities and 5 total pop, playing Trader gives +3 wealth (2×1 + 1) and costs 1 food.
- [ ] AC4 (scaling): 3 cities and 10 pop give +4 (2×1 + 2). 4 cities and 16 pop give +7 (2×2 + 3). 2 cities and 4 pop
  give +2. With population off (the fixture default) and 2 cities: +2.
- [ ] AC5 (text): the short card text is "Needs 2 cities\n+2 wealth ×√cities, +1 per 5 pop". The tooltip reads
  "Needs 2 cities. Gain 2 wealth × √cities (rounded down), plus 1 wealth per 5 pop."
- [ ] AC6 (content): the real Caravan uses `trade` with `min_cities` ≥ 2, and the real data loads with no warnings.
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
| AC1 | `test_data_loader::test_…` |

## Manual check
- [ ] With only the Capital, Caravan is dimmed and its tooltip says it needs 2 cities.
- [ ] After settling a second city, Caravan gives the wealth the text promises.

## Log
