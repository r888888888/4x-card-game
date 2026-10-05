---
id: 264
title: New buildings for insight, housing, order and the desert
type: feature
status: red-review
branch: feat/264-new-buildings
---

## Goal
Fill the gaps in the building slate. Insight gets an era-1 building, and Library becomes a building you can own
several of instead of a single copy. Housing and unrest each get buildings across the eras, so growth (262) and a
wide realm have answers past Granary and Temple. The desert gets a building of its own. Era 3 gets its first
building. Content only: no engine change. Follows 263.

## Acceptance criteria
- [ ] AC1 (invariant): Some building with an `upkeep` insight gain is obtainable in era 1: it is in the starting
  `deck`, has an open supply pile, or a tech of era 1 in `research_deck` creates or unlocks it. Fails today: Library
  is era 2.
- [ ] AC2 (invariant): Every terrain in config `terrains` is in the `requires` of some reachable building. Fails
  today for desert.
- [ ] AC3 (invariant): Each era 1–3 has a tech in `research_deck` that unlocks a building no tech of an earlier era
  unlocks. Fails today for era 3: Engineering only re-unlocks Monument, which Masonry already unlocks.
- [ ] AC4 (invariant): At least 3 reachable non-wonder buildings set `housing`, and at least 3 reachable non-wonder
  buildings have an `upkeep` effect that loses unrest. Fails today: Granary and Temple are the only ones.

## Out of scope
- Wonders (265).
- Engine rules: "no fresh water" requirements, unrest from large territories (TODO).
- Balance tuning; the sim isn't run here.

## Design notes
Data changes only. New locked piles are `{"price": 3, "count": 6}` unless noted; every unlock is on a tech already in
`research_deck`.

| Building | Unlocked by | Needs | Cost | VP | Does |
|---|---|---|---|---|---|
| Stone Circle (new) | Mysticism (era 1) | anywhere | 3 wealth | 0 | ⟳ +1 insight |
| Library (changed) | Writing (era 2) | anywhere | 5 wealth (was 4) | 1 | ⟳ +2 insight; pile count 6 (was 1) |
| Mud-Brick Houses (new) | Pottery (era 1), pile price 2 | anywhere | 3 wealth | 0 | `housing` 2 |
| Bathhouse (new) | Priesthood (era 2) | fresh water | 4 wealth | 0 | `housing` 1, ⟳ −1 unrest |
| Courthouse (new) | Code of Laws (era 2) | anywhere | 5 wealth | 0 | ⟳ −1 unrest, unrest limit +1 |
| Aqueduct (new) | Engineering (era 3) | anywhere | 5 wealth | 0 | `housing` 2 |
| Caravanserai (new) | The Wheel (era 1), pile price 2 | desert | 3 wealth | 0 | ⟳ +1 wealth, ⟳ +1 more on fresh water; tag `trade` |

- Mysticism still creates and unlocks Temple; it now also unlocks Stone Circle (no free copy).
- Engineering creates and unlocks Aqueduct instead of Monument (Masonry still gives Monument).

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_content::test_a_building_making_insight_is_obtainable_in_era_1` |
| AC2 | `test_content::test_every_terrain_is_required_by_a_reachable_building` |
| AC3 | `test_content::test_every_era_unlocks_a_new_building` |
| AC4 | `test_content::test_several_buildings_add_housing_and_calm_unrest` |

## Manual check
- [ ] Review the table's numbers in `data/cards.json` and `data/config.json`.
- [ ] Learn Mysticism: the Stone Circle pile opens; build one and see ⟳ +1 insight in the top bar's forecast.
- [ ] With a desert territory, learn The Wheel and build a Caravanserai there.
- [ ] Card text reads well for Bathhouse (housing and unrest) and Courthouse (unrest and limit).

## Log
- Balance worries for a later balance item: Stone Circles may speed era 1 research a lot (5–8 insight techs against
  +1 each); several Libraries may run era 3 out early; Mud-Brick Houses at 3 wealth for 2 housing may outclass
  Granary.
