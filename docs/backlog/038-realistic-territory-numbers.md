---
id: 038
title: Realistic territory slots and housing; Floodplain Delta gets fresh water
type: feature
status: red-review
branch: feat/038-realistic-territory-numbers
---

## Goal
Territory numbers follow the land. Housing is how many people it can feed: fertile river land is high;
desert, jungle and mountain are low. Slots are how much buildable ground there is: flat land has more;
rough or marshy land has less. Floodplain Delta, where a river meets the sea, also gets fresh water.
Rough terrain loses value for now; future keywords (e.g. tin and copper, 037) are meant to give it back.

## Acceptance criteria
<!-- On the real data (data/cards.json), in tests/test_content.gd. -->
- [ ] AC1: Given the shipped data, when it loads, then there are no errors or warnings, and each territory
  has these slots / housing:

  | Territory | Slots | Housing |
  |---|---|---|
  | Grassland | 3 | 5 |
  | Plains | 3 | 4 |
  | River Valley | 2 | 6 |
  | Lakeshore | 2 | 5 |
  | Floodplain Delta | 1 | 6 |
  | Bay | 2 | 4 |
  | Hills | 2 | 3 |
  | Highlands | 1 | 2 |
  | Woodland | 2 | 3 |
  | Rainforest | 1 | 2 |
  | Dunes | 1 | 2 |
- [ ] AC2: Given the shipped data, then Floodplain Delta has keywords `["fresh_water", "flood_plain", "coastal"]`,
  and every other territory keeps its printed keywords.
- [ ] AC3: Given the shipped data, then `population.start` (2) still fits the starting territory's housing (5), and
  the 20-seed scripted smoke games still run and found cities.

## Out of scope
- New keywords to make up for rough terrain (037 and later items).
- Territory deck counts and resource tables.
- Capital slots (stays +4).

## Design notes
- Data only: `slots` and `housing` in `cards.json`, plus the Delta's `keywords`. No engine change.
- Territory deck totals (Hills ×2): slots 24 → 19, housing 46 → 40. The game gets tighter; the starting
  Grassland goes up (2 / 4 → 3 / 5) to soften the early game.
- AC3 is covered by the existing tests `test_real_data_loads_without_warnings`, the population load check,
  and `test_scripted_games_run_and_found_cities`. They must stay green.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_content::test_real_territory_slots_and_housing_follow_the_land` |
| AC2 | `test_content::test_real_floodplain_delta_has_fresh_water_and_others_keep_keywords` |
| AC3 | existing: `test_content::test_real_data_loads_without_warnings`, `::test_real_config_turns_population_on`, `::test_scripted_games_run_and_found_cities` (plus the loader's population.start ≤ housing check) |

## Manual check
- [ ] Territory cards show the new ▢ / ⌂ numbers, and the Delta lists Fresh Water.
- [ ] Play a game to turn 20: note whether era 2 (8 pop or 15 wealth) is still reachable with the lower housing.

## Log
- Replaces the earlier draft of 038 (Delta: fresh water, 1 slot), which is now part of this item.
