---
id: 161
title: Territory defence from units, walls, cities and terrain
type: feature
status: review
branch: feat/161-territory-defence
---

## Goal
Each settled territory has a **defence**: the strength of the units stationed on it, plus walls, its city and its
terrain. Raids (162) are measured against it, so the player can see at a glance which land is weak. Follows 160.

## Acceptance criteria
- [x] AC1 (loader): `defense` (int ≥ 1) loads on buildings and cities; below 1 or not an int is a load error naming
  file, card and field; on another type it is ignored with a warning. Config `terrain_defense` (optional) maps config
  `keywords` to ints ≥ 1, e.g. `{"mountain": 1}`; an unknown keyword or a bad value is a config error naming the key.
- [x] AC2 (total): Given Hills (keyword mountain) settled with a City (defense 1), a working Palisade (building,
  defense 2), a working Levy (strength 2) stationed there and `terrain_defense` `{"mountain": 1}`, then
  `defense(Hills)` is 6 and `defense_parts(Hills)` is `{units: 2, buildings: 2, cities: 1, terrain: 1, total: 6}`.
- [x] AC3 (idle): An idle Palisade and an idle Levy add nothing: with Hills' pop dropped so both are idle,
  `defense(Hills)` is 2 (city and terrain).
- [x] AC4 (station): A unit counts on its station, not its home; units homed elsewhere but stationed on a territory
  count there (set up through `station_uid` once 163 exists; until then station is the home).
- [x] AC5 (edges): Terrain sums every matching keyword of the territory copy, rolled ones included. Without
  `terrain_defense` terrain is 0. `defense(uid)` is 0 and `defense_parts(uid)` is `{}` for a uid that isn't a settled
  territory.
- [x] AC6 (text): A building or city with defense 2 has "Defence 2" in its card text and tooltip.
- [x] AC7 (added at green, for the Manual check): a settled territory's tooltip has a line "Defence 6: units 2, walls
  2, cities 1, terrain 1" (AC2's Hills); its live line ends "   ⛨ D" (also with population off).

## Out of scope
- Raids that test defence (162); training bonuses to strength (164) and veterans (165) feed `defense` later through a
  per-unit strength query.

## Design notes
- `defense` in `DataLoader.TYPE_FIELDS` (`[CardDef.BUILDING, CardDef.CITY]`); `CardDef.defense`.
- Config `terrain_defense`, checked by `ConfigLoader` against `keywords`.
- New API: `defense(territory_uid) -> int`, `defense_parts(territory_uid) -> Dictionary`; probably a new
  `engine/military.gd` (`Military`) holding units' and defence rules, so `territories.gd` and `population.gd` stay
  focused.
- The spelling in code and data is `defense` (like the other identifiers); player-facing text says "Defence".

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_defence::test_defense_loads_on_buildings_and_cities`, `test_bad_defense_is_a_load_error`, `test_terrain_defense_config` |
| AC2 | `test_defence::test_defense_adds_units_buildings_cities_and_terrain` |
| AC3 | `test_defence::test_idle_walls_and_units_add_no_defense` |
| AC4 | `test_defence::test_unit_counts_on_its_station_not_its_home` |
| AC5 | `test_defence::test_terrain_sums_every_matching_keyword_rolled_ones_included`, `test_no_terrain_defense_without_the_config`, `test_defense_is_0_for_anything_but_a_settled_territory` |
| AC6 | `test_defence::test_defense_text` |
| AC7 | `test_defence::test_territory_tooltip_breaks_down_its_defence`; changed: `test_territory_cards::live_line`, `test_without_population_the_live_line_is_free_slots_and_defence`, `test_the_worker_glyph_is_an_icon`, `test_territory_view::test_the_view_shows_slots_and_pop_and_grow`, `test_without_population_there_is_no_pop_stat_or_grow`, `test_workers::test_territory_tooltip_spells_out_slots_pop_and_workers`, `test_territory_tooltip_without_population_names_slots_and_defence` |

## Manual check
Run `godot --path . -- --seed 5` and hover each territory card; open one to see the stats line.
- [ ] Shipped numbers: Capital defense 2, City 1, Palisade (wealth 3, defense 2, unlocked supply pile), terrain
  hills 1, mountain 2, marsh 1, forest 1.
- [ ] Each territory card in the Realm row shows its defence (a shield and a number); the territory view shows it
  with the breakdown in its tooltip.

## Log
- 2026-10-03: Paused at green when the two queries took game_engine.gd past 700 lines; 249 split the read queries
  into `EngineQueries`, and 161 resumed on top of it with `defense` / `defense_parts` there. Rules in the new
  `engine/military.gd`. `terrain_defense` accepts resource keywords too, since AC5 counts rolled keywords.
- UI: a shield glyph (`assets/icons/shield.svg`, ⛨) ends each territory's live line; the territory tooltip adds a
  "Defence N: units, walls, cities, terrain" line. Seven existing UI and tooltip tests pinned the old exact text and
  were updated to the new line (listed under AC7).
- Shipped: Capital 2, City 1, Palisade (building, 3 wealth, defense 2, unlocked supply pile price 3 count 6), terrain
  hills 1, mountain 2, marsh 1, forest 1.
- Balance: the Palisade does nothing until raids (162); the sim bot may buy it.
