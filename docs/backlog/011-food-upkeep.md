---
id: 011
title: Pop eats food at upkeep; shortfall starves pop
type: feature
status: ready
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
- [ ] AC4: Each unpaid food removes 1 pop from the territory with the most pop. Ties go to the oldest
  (lowest uid). Given Homeland pop 2, a settled territory T with pop 2, food 0 at the start of a turn
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

## Manual check
- [ ] Starving pop is visible (the log, and the territory's pop counter going down).

## Log
- 2026-09-28: spec'd with the user. Produce first, then eat; starve from the biggest territory; can reach 0.
