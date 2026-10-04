---
id: 164
title: Barracks train the units stationed with them
type: feature
status: red-review
branch: feat/164-barracks-training
---

## Goal
Training as a placement decision: a building with `training` gives the units stationed on its territory more
strength. Introduces `unit_strength(uid)`, which defence uses from now on. Follows 161 and 163.

## Acceptance criteria
- [ ] AC1 (loader): `training` (int ≥ 1) loads on buildings; a bad value is a load error naming file, card and field;
  on another type it is ignored with a warning.
- [ ] AC2 (strength): Given a working Drill Yard (building, training 1) on Homeland and a Levy (strength 2) stationed
  there, `unit_strength(levy)` is 3 and `defense(Homeland)` counts 3 for it; a second training building there adds its
  training too.
- [ ] AC3 (where): The bonus follows the station, not the home: a Levy homed on Homeland and moved to Hills has
  strength 2; a Levy moved onto Homeland from elsewhere has 3. An idle Drill Yard trains nobody.
- [ ] AC4 (edges): `unit_strength(uid)` is the printed strength with no training building, and 0 for an idle unit or a
  uid that isn't a unit in the tableau.
- [ ] AC5 (text): The building's text and tooltip say "Units here have +1 strength".

## Out of scope
- Veterans (165) and upgrades (166).

## Design notes
- `training` in `DataLoader.TYPE_FIELDS` (`[CardDef.BUILDING]`). New API `unit_strength(uid)`; `defense_parts.units` sums
  it.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_training::test_training_loads_on_buildings`, `test_bad_training_is_a_load_error` |
| AC2 | `test_working_training_building_adds_to_units_stationed_there`, `test_training_buildings_on_a_territory_add_up` |
| AC3 | `test_a_unit_moved_away_loses_its_training`, `test_a_unit_moved_onto_a_training_territory_gains_it`, `test_an_idle_training_building_trains_nobody` |
| AC4 | `test_unit_strength_is_printed_strength_without_training`, `test_unit_strength_is_0_for_an_idle_unit_or_a_non_unit` |
| AC5 | `test_training_text` |

## Manual check
- [ ] Shipped Barracks: wealth 4, training 1, locked supply pile (price 3, count 6) opened by Bronze Working beside the
  Forge.
- [ ] Units in the territory view show their trained strength; the details explain the bonus.

## Log
