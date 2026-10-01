---
id: 130
title: Terrain keywords: every territory has exactly one terrain
type: feature
status: done
branch: feat/130-terrain-keywords
---

## Goal
Territories are one terrain (grassland, hills, desert, …) plus any number of features (fresh water, coastal, flood
plain). The loader enforces that, so the territory set stays orthogonal: a territory's name is its terrain plus its
features, and no two territory types blur into each other. Rolled resources follow the terrain, so every hills-type
territory can roll metals without a separate table for each.

## Acceptance criteria
Fixtures: TEST config with `keywords: ["mountain", "fresh_water", "flood_plain", "plain"]` and `terrains: ["mountain",
"plain"]` (only where a test opts in; with no `terrains` the existing fixtures load unchanged).

- [x] AC1 (loader, terrains list): config `terrains` is optional, an array of keyword ids, default `[]`. Each must be in
  `keywords`. Given `terrains: ["swamp"]` with no `swamp` keyword, loading fails with an error naming config.json,
  `terrains` and `'swamp'`. Given `terrains: "mountain"` (not an array), loading fails with an error naming config.json
  and `terrains`. The normalized config has `terrains`.
- [x] AC2 (loader, exactly one terrain): when `terrains` is non-empty, every territory card prints exactly one of them.
  A territory with keywords `["fresh_water"]` is a load error naming the card and `keywords` ("needs exactly one
  terrain"); one with `["mountain", "plain"]` is a load error naming the card and both terrains. A territory with
  `["mountain", "fresh_water", "flood_plain"]` loads. With `terrains` empty, a territory with no keywords still loads.
- [x] AC3 (terrain roll tables): a `territory_resources` key may be a terrain as well as a territory id. Given
  `territory_resources: {"mountain": [{"keywords": ["gold"], "weight": 1}]}`, every copy of each territory whose
  terrain is mountain (in the territory deck and the starting territory) has `gold`; a territory with another terrain
  rolls nothing. A key that is neither a territory card nor a terrain is still the error
  `territory_resources: unknown card '<key>'`. A key that names both a territory card and a terrain is a load error
  naming `territory_resources` and the key (it would be ambiguous).
- [x] AC4 (precedence): a territory with a table under its own id rolls only from that table, never also from its
  terrain's. Given tables for both `hills` (the TEST territory, terrain mountain) → `[tin]` and `mountain` → `[gold]`,
  each Hills copy has `tin` and not `gold`. A territory with no table of either kind uses no rng step, as today.
- [x] AC5 (keyword details): with `terrains` set, the generated detail text for a terrain keyword starts "A terrain."
  and for any other printed keyword starts "A territory feature."; resource keywords keep "A resource some territories
  have.". With `terrains` empty the text stays "A territory keyword.". The "Needed by" and "Bonus on it" parts are
  unchanged.

## Out of scope
- The real territory set, its keywords and numbers (131).
- Civilization home territories (111).
- Showing the terrain separately from features on the territory card or view.

## Design notes
- Data format: config `terrains: [keyword ids]`, a subset of `keywords`. `keywords` stays the full list of printable
  keywords, so `requires`, effect `keyword` and `gain_per_keyword` need no change.
- The exactly-one check needs both cards and config, so it lives in the config loader (it already validates
  `territory_resources` against cards); the message is prefixed with cards.json and the card id, like card errors.
- `Territories.make` looks up the territory's own table first, then its terrain's.
- `CardDetails._keyword_text` reads `config.terrains` to choose the opening sentence.
- PLAN.md: the territory section and `config.json` comment mention `terrains` and terrain-keyed roll tables.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_terrains::test_terrains_list_loads_into_the_config`, `test_terrains_default_to_empty`, `test_terrains_validation` |
| AC2 | `test_terrains::test_each_territory_needs_exactly_one_terrain`, `test_one_terrain_with_features_loads`, `test_without_terrains_a_territory_needs_none` |
| AC3 | `test_terrains::test_terrain_table_rolls_on_every_territory_of_that_terrain`, `test_starting_territory_rolls_from_its_terrain_table`, `test_terrain_table_key_validation` |
| AC4 | `test_terrains::test_own_table_overrides_the_terrain_table`, `test_territories_without_a_table_use_no_rng` |
| AC5 | `test_terrains::test_keyword_details_name_terrains_and_features`, `test_keyword_details_without_terrains_say_territory_keyword` |

## Log
- Red: a key that is both a territory id and a terrain (real data: the Hills card and the hills terrain) is ambiguous,
  so it's a load error (added to AC3); 131 renames the plain Hills card. Guard tests that pass before the change:
  `test_one_terrain_with_features_loads`, `test_without_terrains_a_territory_needs_none`,
  `test_keyword_details_without_terrains_say_territory_keyword`.
- The user approved building 130, 131 and 111 in one go ("approve and build all three"), so the red checkpoint was
  not a stop.
- Green: 878 → 891 tests. `ConfigLoader._check_terrains` and the terrain branch of `_parse_territory_resources`;
  `Territories.make` falls back to the terrain's table; `CardDetails._keyword_text` reads `config.terrains`.
