---
id: 060
title: Granary stores grain — +1 housing and a famine guard
type: feature
status: review
branch: feat/060-granary-famine-guard
---

## Goal
Give the Granary a storage theme (TODO 16). A Granary adds 1 housing to its territory, and each upkeep it saves the
first pop on its territory that would starve. It no longer grows pop by itself (Harvest Festival and buying growth
still do).

## Acceptance criteria
Fixture added to TEST_CARDS: `silo`, "Silo", building, cost 1 food, `housing: 1`, `famine_guard: 1`, no effects.
Population is on (`population: {start: 3, food_upkeep: 1, vp_per_pop: 1}`), and homeland has 5 slots, so housing is 7.

- [x] AC1 (loader): buildings may set `housing` and `famine_guard` (integers ≥ 1). A bad value is a load error naming
  the card and the field. `famine_guard` on a non-building is an "only applies to buildings" warning. `housing` stays
  valid on territories.
- [x] AC2 (housing): With a Silo on homeland, `housing(home)` is 8 and homeland can grow to 8 pop. An idle Silo still
  adds housing.
- [x] AC3 (guard): Homeland has 4 pop and a working Silo, and food is 0 when the turn ends. At the next upkeep the
  Capital gives +2, and the 4 pop need 4, so the shortfall is 2. The first starving pop is saved and the second dies:
  pop 3, food 0. Without the Silo: pop 2.
- [x] AC4 (per territory): Homeland has 3 pop, a river territory has 1 pop and a working Silo, and food is 0 when the
  turn ends (Capital +2, need 4, shortfall 2). Both deaths hit homeland (the biggest, as today): homeland 1, river 1.
  The Silo on the river doesn't help homeland.
- [x] AC5 (limits): Two working Silos on one territory save 2 pop per upkeep. An idle Silo saves none.
- [x] AC6 (forecast): `upkeep_forecast().starve` counts only the pop that would actually die after guards (1 in AC3's
  state, 2 without the Silo).
- [x] AC7 (text): The short card text is "+1 housing\nSaves 1 pop from famine". The tooltip reads "+1 housing on its
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
| AC1 | `test_famine_guard::test_building_housing_and_famine_guard_load`, `::test_building_housing_and_famine_guard_validation`; `test_population::test_housing_validation` (row changed: housing on an *action* warns) |
| AC2 | `test_famine_guard::test_silo_adds_1_housing_to_its_territory`, `::test_silo_lets_homeland_grow_to_8`, `::test_silo_housing_caps_card_growth_at_8`, `::test_idle_silo_still_adds_housing` |
| AC3 | `test_famine_guard::test_silo_saves_the_first_starving_pop`, `::test_without_silo_both_starve` |
| AC4 | `test_famine_guard::test_silo_on_another_territory_does_not_save_homeland` |
| AC5 | `test_famine_guard::test_two_silos_save_2_pop`, `::test_idle_silo_saves_none` |
| AC6 | `test_famine_guard::test_forecast_starve_counts_the_guard`, `::test_forecast_starve_without_guard` |
| AC7 | `test_famine_guard::test_silo_short_text`, `::test_silo_tooltip`, `::test_silo_details_explain_housing_and_famine_guard` |

## Manual check
Run `godot --path .`. The Granary pile starts locked; its unlocking tech also puts a Granary in the discard.
- [ ] Once a Granary is on a territory, the Realm row reads "Pop n / h" with h one higher than the territory's printed ⌂.
- [ ] The Granary's face reads "+1 housing / Saves 1 pop from famine"; its tooltip and details (I) show the long lines
  and the Housing and Famine Guard terms.
- [ ] Let food run out with a working Granary: the log says "<Territory>: 1 pop saved from famine." and the food
  forecast's starve count is 1 lower than without it.

## Log
- 2026-09-29: Built in a worktree off `main` (the main checkout was on 059). Red at 862561f, 463 tests (was 447).
- Approved at red: `test_population::test_housing_validation`'s "housing on a building" row became "housing on an
  action" (AC1 makes building housing valid). `test_content::test_real_deck_has_growth_cards` now counts famine-guard
  cards too: since 069 Harvest Festival has no `grow`, so the Granary was the only growth card.
- `upkeep_forecast` runs `Population.feed` on its fork to get `starve`, so the guard rule is shared.
- Detail term is "Famine Guard" (`capitalize()`).
- Real Granary: 2 wealth, `housing: 1`, `famine_guard: 1`, no effects. Price kept after the sim (20 seeds; the bot
  never buys from the supply, so this reflects created Granaries):

  | metric | main | this | Δ |
  |---|---|---|---|
  | score | 61.70 (33–89) | 64.30 (47–87) | +2.60 |
  | cities | 10.35 (4–11) | 11.00 (11–11) | +0.65 |
  | pop | 14.15 (11–16) | 13.00 (13–13) | −1.15 |
  | techs | 8.75 (3–13) | 9.15 (2–13) | +0.40 |
  | bought | 0 | 0 | 0 |
  | era | 2 | 2 | 0 |
