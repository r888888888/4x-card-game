---
id: 009
title: Population on territories, counted in the final score
type: feature
status: done
branch: feat/009-population
---

## Goal
Each settled territory holds population (pop), a resource that is kept, not spent. Pop has a
housing cap per territory and counts toward the final score. This is the foundation for buying
growth (010), food upkeep (011), workers gating buildings (012) and growth cards (013), and later
for mechanics triggered by total pop.

## Acceptance criteria
- [x] AC1: Loader. A territory's optional `housing` must be an int ≥ 1 and defaults to `slots + 2`
  (Grassland with 2 slots → 4). `"housing": 0` or `"housing": "x"` on territory `t` gives an error
  naming the file, card `t` and field `housing`. `housing` on a non-territory card is a warning.
- [x] AC2: Loader. Config may have a `population` object with optional ints `start` (≥ 1, default 2),
  `food_upkeep` (≥ 0, default 1) and `vp_per_pop` (≥ 0, default 1). A negative value or a wrong type
  is an error naming the field (e.g. `population.start`). An unknown key is a warning.
  `start` greater than the starting territory's housing is an error.
- [x] AC3: Given `population: {start: 2}` and starting territory Homeland, when a new game starts,
  then `pop(homeland_uid)` is 2 and `total_pop()` is 2. Territories in the territory deck, reveal
  and frontier have pop 0.
- [x] AC4: Given population on, when a Pioneer settles a frontier territory, then that territory has
  pop 1 and `total_pop()` goes from 2 to 3.
- [x] AC5: Given population on with `vp_per_pop: 1`, a Capital (2 VP) and total pop 3, then `score()`
  is 5, and the final score sent with `game_over` includes the pop VP.
- [x] AC6: Given a config with no `population` block, then every territory has pop 0 (including
  after a settle), `total_pop()` is 0, and `score()` is unchanged from today.

## Out of scope
- Changing pop in any other way: buying growth (010), starvation (011), growth cards (013).
- Mechanics triggered by total pop other than the final score (for example milestones or eras).

## Design notes
- Data: territory `housing` (int, optional, default `slots + 2`). Config `population`:
  `{ "start": 2, "food_upkeep": 1, "vp_per_pop": 1 }`. Its presence turns the population rules on;
  without it the game behaves exactly as it does today, so existing tests and fixtures don't change.
  `food_upkeep` is only read by 011; it's defined here so the whole block is validated in one place.
- Real data: add `population` with the defaults to `data/config.json`, and write `housing` (slots + 2)
  on every territory in `data/cards.json` so it's easy to tune.
- Engine API: `pop(territory_uid) -> int`, `housing(territory_uid) -> int`, `total_pop() -> int`.
  State lives on `CardInstance.pop` (0 by default).
- Settle sets the new territory's pop to 1, which is free (the Settler's food cost pays for it). Housing
  is ≥ 1, so the cap is never exceeded.
- UI: pop / housing shown on each settled territory; total pop in the stats bar.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_population::test_housing_defaults_to_slots_plus_2`, `test_housing_loads_when_given`, `test_housing_0_is_error`, `test_housing_not_int_is_error`, `test_housing_on_non_territory_is_warning` |
| AC2 | `test_population::test_population_block_defaults`, `test_population_block_values_load`, `test_no_population_block_leaves_population_off`, `test_population_start_0_is_error`, `test_population_negative_food_upkeep_is_error`, `test_population_vp_per_pop_wrong_type_is_error`, `test_population_not_an_object_is_error`, `test_population_unknown_key_is_warning`, `test_population_start_above_starting_housing_is_error` |
| AC3 | `test_population::test_new_game_gives_starting_territory_start_pop`, `test_unsettled_territories_have_no_pop` |
| AC4 | `test_population::test_settle_gives_new_territory_1_pop` |
| AC5 | `test_population::test_score_adds_vp_per_pop`, `test_score_uses_vp_per_pop_rate`, `test_final_score_includes_pop_vp` |
| AC6 | `test_population::test_without_population_block_pop_is_always_0` |
| Real data | `test_content::test_real_config_turns_population_on` |

## Manual check
Run `godot --path .` (real data has population on, start 2).
- [ ] The stats bar shows "Pop: 2" next to Score, and Score is 2 higher than the printed VP (Capital 2 + 2 pop = 4).
- [ ] The Capital's territory box reads "0 / 2 slots used  ·  Pop 2 / 4" (Grassland: 2 slots, housing 4).
- [ ] Territory cards in the frontier and choice panel show "2 slots · 4 housing · Grassland" style info.
- [ ] Play a Scout, keep a territory, then settle it with a Settler: its box shows "Pop 1 / N", the stats bar
  shows "Pop: 3", and Score goes up by 2 (City) + 1 (pop).

## Log
- 2026-09-28: spec'd with the user. Pop is per territory and held (not spent); a settle gives 1 free pop;
  for now total pop only counts toward the final score (+1 VP per pop).
- 2026-09-28: red. 22 failing tests (21 in the new `tests/test_population.gd`, 1 in `test_content`). Fixed the AC1 example:
  Grassland has 2 slots, so its default housing is 4, not 7.
- 2026-09-28: green. `data/config.json` turns population on with the defaults, and every territory in
  `data/cards.json` now states `housing` (slots + 2). Note: `food_upkeep` is already 1 in the real config but has
  no effect until 011. The UI shows pop / housing on each territory group, housing on territory cards,
  and total pop in the stats bar (hidden when population is off).
