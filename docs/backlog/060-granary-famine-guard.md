---
id: 060
title: Granary stores grain — +1 housing and a famine guard
type: feature
status: ready
branch: feat/060-granary-famine-guard
---

## Goal
Give the Granary a storage theme (TODO 16). A Granary adds 1 housing to its territory, and each upkeep it saves the
first pop on its territory that would starve. It no longer grows pop by itself (Harvest Festival and buying growth
still do).

## Acceptance criteria
Fixture added to TEST_CARDS: `silo`, "Silo", building, cost 1 food, `housing: 1`, `famine_guard: 1`, no effects.
Population is on (`population: {start: 3, food_upkeep: 1, vp_per_pop: 1}`), and homeland has 5 slots, so housing is 7.

- [ ] AC1 (loader): buildings may set `housing` and `famine_guard` (integers ≥ 1). A bad value is a load error naming
  the card and the field. `famine_guard` on a non-building is an "only applies to buildings" warning. `housing` stays
  valid on territories.
- [ ] AC2 (housing): With a Silo on homeland, `housing(home)` is 8 and homeland can grow to 8 pop. An idle Silo still
  adds housing.
- [ ] AC3 (guard): Homeland has 4 pop and a working Silo, and food is 0 when the turn ends. At the next upkeep the
  Capital gives +2, and the 4 pop need 4, so the shortfall is 2. The first starving pop is saved and the second dies:
  pop 3, food 0. Without the Silo: pop 2.
- [ ] AC4 (per territory): Homeland has 3 pop, a river territory has 1 pop and a working Silo, and food is 0 when the
  turn ends (Capital +2, need 4, shortfall 2). Both deaths hit homeland (the biggest, as today): homeland 1, river 1.
  The Silo on the river doesn't help homeland.
- [ ] AC5 (limits): Two working Silos on one territory save 2 pop per upkeep. An idle Silo saves none.
- [ ] AC6 (forecast): `upkeep_forecast().starve` counts only the pop that would actually die after guards (1 in AC3's
  state, 2 without the Silo).
- [ ] AC7 (text): The short card text is "+1 housing\nSaves 1 pop from famine". The tooltip reads "+1 housing on its
  territory" and "Each upkeep, 1 pop here that would starve survives".

## Out of scope
- Food spoilage or a food cap (rejected for now).
- Redirecting saved starvation to other territories.

## Design notes
- `TYPE_FIELDS`: `housing` → [TERRITORY, BUILDING], `famine_guard` → [BUILDING]. `CardDef.famine_guard`.
  `Population.housing` adds the housing of buildings on the territory. `Population.feed` keeps a guard count per
  territory for this feeding: the working buildings' `famine_guard`. Idleness is decided before pop eats, as today.
- `upkeep_forecast` computes `starve` with the same guard rule (share the helper).
- Real data: the Granary drops its `grow` effect and gets `housing: 1`, `famine_guard: 1`; the price is reviewed with
  the sim. `test_real_deck_has_growth_cards` must still pass (Harvest Festival). If it counts the Granary, flag it at
  the red checkpoint.
- The card details terms (056) gain "Famine guard".

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_population::test_…` |

## Manual check
- [ ] A Granary's territory shows the higher housing, and the Granary's face reads well.
- [ ] Starving with a Granary: the log says a pop was saved on that territory.

## Log
