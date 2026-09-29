---
id: 076
title: Buildings cost mostly wealth, early ones cheaper
type: feature
status: in-progress
branch: feat/076-buildings-cost-wealth
---

## Goal
Give wealth early jobs and take buildings out of the food budget. Today most buildings cost food,
so every building competes with growth and Settlers, while early wealth (Capital +1 per turn) has
few affordable places to go. After this, every building costs wealth; non-food buildings cost wealth
only, food producers keep a token 1 food, the early buildings are cheap enough to afford in the
first turns, and the game starts with a little wealth so a building is playable on turn 1.

## Acceptance criteria
<!-- Content tests check shape, not balance numbers (see tests/test_content.gd). -->
- [ ] AC1: In the real data (`data/cards.json`), every card of type `CardDef.BUILDING` costs at least
  1 wealth.
- [ ] AC2: In the real data, a building with no effect that produces food (no effect whose `resource`
  is `GameEngine.FOOD`) has no food cost (no `food` key, or `food` 0), and a building that produces
  food costs at most 1 food.
- [ ] AC3: In the real data, the starting resources (`config.starting.resources`) include at least
  1 wealth and can pay the full cost of at least one building in the starting deck (`config.deck`).
- [ ] AC4: The real data loads with no errors or warnings (existing `test_real_data_loads_without_warnings`).
- [ ] AC5: Every card that costs wealth still has a wealth source in the deck or starting tableau
  (existing `test_every_wealth_cost_has_a_wealth_source`), and the 20-seed scripted sweep stays green:
  every game ends, wealth never goes below 0, a City is founded in ≥ 9 seeds, a wealth-cost card is
  played in ≥ 1 seed, a tech is bought in ≥ 1 seed (existing `test_scripted_sweep_over_20_seeds`).

## Out of scope
- Non-building cards (Settler, Scout, Caravan, growth cards, techs, events) keep their costs.
- Starting food, wealth income (Capital, Caravan, Market, techs) and supply prices.
- Engine or UI changes: costs are already a resource-keyed object, and card text is generated.

## Design notes
Data only (`data/cards.json`, `data/config.json`), plus the Resources row in `PLAN.md`. "Produces food" means an effect
with `resource: food` (`gain` or `gain_per_tag`); Granary's `grow` adds pop, not food.

Food producers keep 1 food and move the rest to wealth (same total):

| Building | Now | New |
|---|---|---|
| Farm | 2 food | 1 food + 1 wealth |
| Lumber Camp | 2 food | 1 food + 1 wealth |
| Pasture | 2 food | 1 food + 1 wealth |
| Irrigation | 3 food | 1 food + 2 wealth |
| Harbor | 3 food | 1 food + 2 wealth |

Early non-food buildings go wealth-only and get 1 cheaper, so they fit early Capital income:

| Building | Now | New |
|---|---|---|
| Mine | 3 food | 2 wealth |
| Granary | 3 food | 2 wealth |
| Temple | 2 food + 2 wealth | 3 wealth |

Starting resources: 2 food → 2 food + 2 wealth. On turn 1 that pays for a Farm, Lumber Camp, Mine
or Granary (not Temple or Market at 3); with the Capital's +1 per turn, both are affordable on turn 2.

Later non-food buildings go wealth-only at the same total:

| Building | Now | New |
|---|---|---|
| Market | 3 food | 3 wealth (kept at 3 so it doesn't pay back in 2 turns; see 077) |
| Forge | 2 food + 2 wealth | 4 wealth |
| Library | 1 food + 2 wealth | 3 wealth |
| Monument | 2 food + 3 wealth | 5 wealth |
| Pyramids | 6 food + 6 wealth | 12 wealth |

Balance risk: buildings now compete with techs and supply buys for wealth. Market's income is
reworked in 077. If the sweep thresholds in AC5 fail, stop and report rather than lowering them.
Run the `balance` skill and record the before/after numbers in the Log.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_content::test_every_building_costs_wealth` |
| AC2 | `test_content::test_only_food_buildings_cost_food_and_at_most_1` |
| AC3 | `test_content::test_starting_resources_afford_a_starting_deck_building` |
| AC4 | `test_content::test_real_data_loads_without_warnings` (existing) |
| AC5 | `test_content::test_every_wealth_cost_has_a_wealth_source`, `test_content::test_scripted_sweep_over_20_seeds` (existing) |

## Manual check
Run `godot --path .`.
- [ ] The shipped costs and starting resources match the notes above; the HUD shows 2 wealth on turn 1.
- [ ] Play a full game: a Farm or Mine is playable on turn 1, and food
  goes mostly to growth and Settlers. Record the final score and wealth/food left in the Log.

## Log
