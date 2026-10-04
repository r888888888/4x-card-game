---
id: 164
title: Barracks train the units stationed with them
type: feature
status: review
branch: feat/164-barracks-training
---

## Goal
Training as a placement decision: a building with `training` gives the units stationed on its territory more
strength. Introduces `unit_strength(uid)`, which defence uses from now on. Follows 161 and 163.

## Acceptance criteria
- [x] AC1 (loader): `training` (int ≥ 1) loads on buildings; a bad value is a load error naming file, card and field;
  on another type it is ignored with a warning.
- [x] AC2 (strength): Given a working Drill Yard (building, training 1) on Homeland and a Levy (strength 2) stationed
  there, `unit_strength(levy)` is 3 and `defense(Homeland)` counts 3 for it; a second training building there adds its
  training too.
- [x] AC3 (where): The bonus follows the station, not the home: a Levy homed on Homeland and moved to Hills has
  strength 2; a Levy moved onto Homeland from elsewhere has 3. An idle Drill Yard trains nobody.
- [x] AC4 (edges): `unit_strength(uid)` is the printed strength with no training building, and 0 for an idle unit or a
  uid that isn't a unit in the tableau.
- [x] AC5 (text): The building's text and tooltip say "Units here have +1 strength".

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
| Manual check | `test_trained_unit_details_explain_its_strength`, `test_strength_tag_shows_only_on_a_trained_unit` (added after the first red review) |

## Manual check
- [ ] Shipped Barracks: wealth 4, training 1, locked supply pile (price 3, count 6) opened by Bronze Working beside the
  Forge.
- [ ] Units in the territory view show their trained strength; the details explain the bonus.
- [ ] Steps: `godot --path . -- --turns 20 --seed 5`. Research Bronze Working; the Supply screen shows Barracks
  (Units here have +1 strength) open beside the Forge. Recruit a Warriors on a territory, buy and build a Barracks
  there: the Warriors' card shows "Strength N+1" on its info line, and its details (I) list "Strength N+1 (printed N,
  +1 training)". Its territory's tooltip defence counts the trained strength. Move the unit to another territory: the
  tag goes away and the defences shift. Drop the territory's pop so the Barracks idles: no tag.

## Log
- 2026-10-04: `unit_strength` went in `game_engine.gd`, not `engine_queries.gd`: that file's own structure test caps it
  at 500 lines and it was at 500. `ui/card_view.gd` is at 501 lines (WARN, not a failure).
- 2026-10-04: The details line and face tag (`unit_strength_tag`) were added after the first red review, with their own
  red checkpoint, to serve the Manual check.
- Balance: Barracks (4 wealth, +1 strength for every unit on its territory) not tuned; check it against Palisade's
  flat Defence 2 in a balance item.
