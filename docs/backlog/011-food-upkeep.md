---
id: 011
title: Pop eats food at upkeep; shortfall starves pop
type: feature
status: red-review
branch: feat/011-food-upkeep
---

## Goal
Population costs food every turn, so growth has an ongoing cost, and a food shortfall makes you lose
pop. Depends on 009.

## Acceptance criteria
- [ ] AC1: Given population on with `food_upkeep: 1`, `start: 2`, starting food 2 and a Capital
  (upkeep +2 food), when a new game starts (turn 1 upkeep), then food is 2 (2 + 2 produced − 2 eaten)
  and Homeland still has pop 2.
- [ ] AC2: Eating happens after production. Given starting food 0, `start: 2` and a Capital (+2), when
  turn 1 starts, then food is 0 and pop is still 2 (no starvation).
- [ ] AC3: Given starting food 0, `start: 3` and a Capital (+2), when turn 1 starts, then 2 food is
  eaten, 1 pop starves, Homeland has pop 2, and food is 0. Food never goes below 0.
- [ ] AC4: Each unpaid food removes 1 pop from the territory with the most pop at that moment. Ties go to
  the territory settled first (earliest on the tableau). Given Homeland pop 2, a settled territory T with pop 2, food 0 at the start of a turn
  and a shortfall of 1, then Homeland drops to 1 and T stays at 2.
- [ ] AC5: Pop can drop to 0. The territory's city stays on the tableau, and a territory with 0 pop
  eats nothing.
- [ ] AC6: Given `food_upkeep: 0`, or no `population` block, then upkeep eats no food.

## Out of scope
- Starvation events or messages beyond the game log.
- What happens to buildings when pop drops (012).

## Design notes
- Order within `_start_turn`: every card's upkeep effects resolve, then pop eats (`food_upkeep` × total
  pop), then the draw.
- Log line, e.g. "Pop eats 3 food." and "Homeland: 1 pop starved."

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_food_upkeep::test_pop_eats_food_at_upkeep`, `test_pop_eats_every_turn` |
| AC2 | `test_food_upkeep::test_pop_eats_after_production` |
| AC3 | `test_food_upkeep::test_shortfall_starves_pop` |
| AC4 | `test_food_upkeep::test_starvation_hits_the_biggest_territory`, `test_each_unpaid_food_rechecks_the_biggest_territory`, `test_starvation_tie_goes_to_the_territory_settled_first` |
| AC5 | `test_food_upkeep::test_pop_can_starve_to_0_and_the_city_stays` |
| AC6 | `test_food_upkeep::test_food_upkeep_0_eats_nothing`, `test_without_population_upkeep_eats_nothing` (guards: pass already) |

## Manual check
- [ ] Starving pop is visible (the log, and the territory's pop counter going down).

## Log
- 2026-09-28: spec'd with the user. Produce first, then eat; starve from the biggest territory; can reach 0.
- 2026-09-28: red. 10 failing tests plus 2 AC6 guards that already pass. AC4 reworded: "oldest (lowest uid)"
  became "settled first (earliest on the tableau)", because the starting territory gets its uid after the whole
  territory deck, so lowest uid would pick the wrong territory. Starvation re-checks the biggest territory for
  each unpaid food. Added a `village` city with no effects to `TEST_CARDS`, and moved `home_uid` to `test_case.gd`.
