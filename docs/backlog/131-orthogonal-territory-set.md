---
id: 131
title: A realistic, orthogonal territory set (terrain × features)
type: content
status: in-progress
branch: feat/131-orthogonal-territory-set
---

## Goal
The territory deck reads like real land: each territory is one terrain plus its features, every keyword appears on
several territory types, and the set covers the lands the shipped civilizations came from (so 111 can start each one
at home). Jungle and Rainforest go: no shipped civilization is tropical.

Depends on 130 (`terrains`, terrain-keyed roll tables).

## Acceptance criteria
Invariants of the real data in `tests/test_content.gd` (no card or keyword ids in the tests):

- [ ] AC1: the real config sets `terrains` (at least 5) and the real data loads without errors or warnings (so every
  territory card prints exactly one terrain, by 130).
- [ ] AC2: every keyword in config `keywords` (terrain or feature) is printed on at least 2 different territory types
  in play (the starting territory or a `territory_deck` entry).
- [ ] AC3: the existing keyword invariants still hold on the new set: every keyword is on a territory and used by a
  card; every resource keyword is rolled and used; every territory can take a starting-deck or open-supply building;
  every building requirement and `gain_per_keyword` keyword is met by a territory in play.

## Out of scope
- Engine changes (130). Civilization homes (111).
- Balancing slots, housing and deck counts beyond the provisional rule below (a later balance item).
- New rolled resources (cedar, salt, …) and a steppe terrain.

## Design notes
Keywords:
- `terrains`: `grassland`, `forest`, `hills`, `mountain`, `desert`, `marsh` (new). `jungle` is removed.
- Features: `fresh_water`, `coastal`, `flood_plain` (only alongside `fresh_water`).
- `keywords` = terrains + features; `resource_keywords` unchanged (gold, tin, copper).

Territory types (id: name, keywords):

| Terrain | Plain | + Fresh water | + Flood plain | + Coastal |
|---|---|---|---|---|
| Grassland | `plains` Plains | `river_meadow` River Meadow | `alluvial_plain` Alluvial Plain (fw, fp) | `coastal_plain` Coastal Plain |
| Desert | `dunes` Dunes | `oasis` Oasis | `desert_floodplain` Desert Floodplain (fw, fp) | |
| Marsh | | `reed_marsh` Reed Marsh (fw) | `delta_marsh` Delta Marsh (fw, fp, coastal) | |
| Forest | `woodland` Woodland | `lakeside_woods` Lakeside Woods | | `cedar_coast` Cedar Coast (coastal, fw) |
| Hills | `hill_country` Hill Country | `highland_valley` Highland Valley | | `coastal_hills` Coastal Hills (coastal, fw) |
| Mountain | `mountains` Mountains | `mountain_lake` Mountain Lake | | |

Marsh has no plain version: marsh is wet by definition, so both marsh types carry `fresh_water`. Retired ids: `grassland` (→ `river_meadow`), `river_valley`, `lakeshore`,
`floodplain_delta`, `bay`, `highlands`, `rainforest`.

Card changes:
- Lumber Camp `requires: ["forest"]` (was forest or jungle).
- Fishing Huts `requires: ["coastal", "marsh"]` (reed fishing; gives marsh a use).
- Farm, Irrigation, Pasture, Harbor, Quarry, Mine, Hunt, Temple, Pyramids, Egypt, Phoenicia unchanged.

Config changes:
- `starting.territory`: `river_meadow` (default for a civilization with no home).
- `territory_resources` keyed by terrain: `hills` → gold / tin+copper / nothing (1/1/2), `mountain` → tin / copper /
  tin+copper / nothing (1/1/1/1), the current tables moved onto terrains.

Provisional slots/housing (038's rule, made mechanical; balance later): terrain base slots/housing grassland 3/4,
forest 2/3, hills 2/3, mountain 1/2, desert 1/2, marsh 1/3; `fresh_water` +1 housing; `flood_plain` +1 housing and −1
slot (min 1); `coastal` +1 housing. Every type then has housing ≥ 2 (`population.start`).

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_content::test_real_config_names_at_least_5_terrains`, `test_real_data_loads_without_warnings` |
| AC2 | `test_content::test_every_keyword_is_on_at_least_2_territory_types` |
| AC3 | `test_content::test_every_keyword_is_on_a_territory_and_a_card`, `test_every_resource_keyword_is_rolled_and_used`, `test_every_territory_can_take_a_building_from_the_start`, `test_every_building_requirement_is_met_by_a_territory_in_play`, `test_every_gain_per_keyword_keyword_is_on_a_territory_in_play` |

## Manual check
- [ ] Territory table above matches `data/cards.json` (ids, names, keywords); no `jungle` anywhere in `data/`.
- [ ] Slots/housing follow the provisional rule: Plains 3/4, River Meadow 3/5, Alluvial Plain 2/6, Coastal Plain 3/5,
  Dunes 1/2, Oasis 1/3, Desert Floodplain 1/4, Reed Marsh 1/4, Delta Marsh 1/6, Woodland 2/3, Lakeside Woods 2/4, Cedar
  Coast 2/5, Hill Country 2/3, Highland Valley 2/4, Coastal Hills 2/5, Mountains 1/2, Mountain Lake 1/3.
- [ ] Territory deck: 3 of each type, 4 of Plains, Woodland, Hill Country and Mountains (52 cards).
- [ ] Every hills- and mountain-terrain copy in a game can roll metals; other terrains never do.
- [ ] Explore still offers a mix: play a few games and note in the Log whether shared-terrain weighting (061) now
  clusters reveals too strongly.

## Log
- Red: ids that equal a terrain are an ambiguous `territory_resources` key (130), so the plain Hills card is
  `hill_country` (Hill Country) and the Marsh card `reed_marsh` (Reed Marsh).
- `keywords_in_play` and the resource-keyword content test read roll tables through the new public
  `Territories.resource_table(config, def)` (extracted from `make`, no behavior change) so terrain-keyed tables count.
- Balance worry: Egypt's per-fresh-water food bonus and Phoenicia's per-coastal wealth bonus count more territory
  types than before (fresh water is on 9 types, coastal on 4). Leave for the balance item.
