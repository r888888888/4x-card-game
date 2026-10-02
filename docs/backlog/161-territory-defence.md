---
id: 161
title: Territory defence from units, walls, cities and terrain
type: feature
status: ready
branch: feat/161-territory-defence
---

## Goal
Each settled territory has a **defence**: the strength of the units stationed on it, plus walls, its city and its
terrain. Raids (162) are measured against it, so the player can see at a glance which land is weak. Follows 160.

## Acceptance criteria
- [ ] AC1 (loader): `defense` (int ≥ 1) loads on buildings and cities; below 1 or not an int is a load error naming
  file, card and field; on another type it is ignored with a warning. Config `terrain_defense` (optional) maps config
  `keywords` to ints ≥ 1, e.g. `{"mountain": 1}`; an unknown keyword or a bad value is a config error naming the key.
- [ ] AC2 (total): Given Hills (keyword mountain) settled with a City (defense 1), a working Palisade (building,
  defense 2), a working Levy (strength 2) stationed there and `terrain_defense` `{"mountain": 1}`, then
  `defense(Hills)` is 6 and `defense_parts(Hills)` is `{units: 2, buildings: 2, cities: 1, terrain: 1, total: 6}`.
- [ ] AC3 (idle): An idle Palisade and an idle Levy add nothing: with Hills' pop dropped so both are idle,
  `defense(Hills)` is 2 (city and terrain).
- [ ] AC4 (station): A unit counts on its station, not its home; units homed elsewhere but stationed on a territory
  count there (set up through `station_uid` once 163 exists; until then station is the home).
- [ ] AC5 (edges): Terrain sums every matching keyword of the territory copy, rolled ones included. Without
  `terrain_defense` terrain is 0. `defense(uid)` is 0 and `defense_parts(uid)` is `{}` for a uid that isn't a settled
  territory.
- [ ] AC6 (text): A building or city with defense 2 has "Defence 2" in its card text and tooltip.

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

## Manual check
- [ ] Shipped numbers: Capital defense 2, City 1, Palisade (wealth 3, defense 2, unlocked supply pile), terrain
  hills 1, mountain 2, marsh 1, forest 1.
- [ ] Each territory card in the Realm row shows its defence (a shield and a number); the territory view shows it
  with the breakdown in its tooltip.

## Log
