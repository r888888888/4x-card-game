---
id: 054
title: Fresh-water start; Farm needs Fresh Water
type: feature
status: red-review
branch: feat/054-fresh-water-farms
---

## Goal
Farming follows water (TODO 11, 12). The Capital starts on a territory with Fresh Water, and a Farm can only be built
where there is Fresh Water. That makes River Valley, Lakeshore and Floodplain Delta worth settling for food. Both
changes ship together, or the Capital couldn't build Farms. Data only; `requires` already exists (005).

## Acceptance criteria
<!-- Content tests: invariants of the real data, no exact numbers. -->
- [ ] AC1: In the real data, the `starting.territory` card has the `fresh_water` keyword.
- [ ] AC2: In the real data, the Farm (`farm`) has `requires: ["fresh_water"]`, and at least 2 territories in the
  territory deck have `fresh_water`.
- [ ] AC3: In a new game on the real data (seed 1), a Farm put in the hand has the Capital's territory among its
  `valid_targets`.
- [ ] AC4: The existing content tests stay green: loads without warnings, every keyword on a territory and a card,
  the 20-seed scripted sweep, growth cards, and wealth coverage.

## Out of scope
- Rule changes. `requires` is any-of and already tested with TEST_CARDS (005).
- Other buildings that need Fresh Water (Irrigation already does).

## Design notes
- `data/cards.json`: `grassland` (starting only, not in the territory deck) gets `keywords: ["grassland", "fresh_water"]`
  and may be renamed "River Meadow" (the id stays). Pasture (needs grassland) still works at the Capital.
- `farm`: add `"requires": ["fresh_water"]`. Its Flood Plain bonus stays.
- Record `scripts/sim.sh` before and after in the Log (use the `balance` skill).

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_content::test_starting_territory_has_fresh_water` |
| AC2 | `test_content::test_farm_requires_fresh_water_and_the_deck_has_it` |
| AC3 | `test_content::test_farm_can_target_the_capitals_territory` (passes today: guards the pair) |
| AC4 | existing: `test_real_data_loads_without_warnings`, `test_every_keyword_is_on_a_territory_and_a_card`, `test_scripted_sweep_over_20_seeds`, `test_real_deck_has_growth_cards`, `test_every_wealth_cost_has_a_wealth_source` |

## Manual check
- [ ] The starting territory's name ("Grassland" or "River Meadow") and its tooltip list Fresh Water.
- [ ] A Farm can't target a Plains or Hills territory; the tooltip says it requires Fresh Water.
- [ ] Balance: food isn't starved out over a full game (sim numbers in the Log).

## Log
