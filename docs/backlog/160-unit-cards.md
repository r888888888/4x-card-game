---
id: 160
title: Unit cards garrisoned on a home territory
type: feature
status: review
branch: feat/160-unit-cards
---

## Goal
A first step toward barbarians and war: soldiers. A new `unit` card type is recruited by playing it from hand onto a
settled territory, its **home**. It takes no building slot but uses one of the home's workers, so pop can be farmers,
builders or soldiers. A unit has a **station** (where it stands, the home for now; 163 lets it move) and a
**strength**, which later items count as defence (161) and pit against raids (162).

## Acceptance criteria
- [x] AC1 (loader): A card with `"type": "unit"` and `"strength": 2` loads with strength 2 (`CardDef.UNIT`). A unit
  without `strength`, or with strength below 1 or not an int, is a load error naming the file, card and field.
  `strength` on any other type is ignored with a warning. A unit with `requires`, or with an effect that sets `keyword`
  or uses `grow` with `"where": "here"`, is a load error (its station can change, so it has no fixed land). A unit in
  `territory_deck`, `research_deck` or `event_deck` is a config error; in `deck` and `supply` it is allowed.
- [x] AC2 (recruit): Given a Levy (unit, cost 1 food, strength 2, ⟳ −1 food) in hand, 3 food and Homeland settled with
  2 pop and a Farm, when I play the Levy, then it is in the tableau with Homeland as its home (`territory_uid`),
  `unit_station(uid)` is Homeland, food is 2, one action is used, and `free_slots(Homeland)` is unchanged.
- [x] AC3 (workers): A unit uses a worker on its home: after AC2, `free_workers(Homeland)` is 0 (2 pop, a Farm and the
  Levy), so another Levy has no target and `play_error` is `"No territory with a free worker."`, and a Farm can't be
  placed there either. With population off, units need no worker.
- [x] AC4 (targets): With two settled territories that each have a free worker, a unit in hand needs a target choice
  (`needs_target_choice` is true) and either is valid. A frontier territory, a territory with no free worker or a
  non-territory as the target gives `"That target isn't valid."`.
- [x] AC5 (idle): Buildings and units on a home share its workers in placement order. Given Homeland with 2 pop, a
  Farm placed before a Levy, when pop drops to 1, then `is_idle(Levy)` is true and `is_idle(Farm)` is false; the
  next upkeep skips the Levy's −1 food, and so does `upkeep_forecast`. At 2 pop again the Levy works.
- [x] AC6 (text and score): A unit's card text and tooltip include "Strength 2", and it scores its printed VP like a
  building.
- [x] AC7 (content invariant): every unit in the real data can be had: it has a supply pile or a tech creates it.
- [x] AC8 (added at green, for the Manual check): `units_at(t)` lists the units stationed on territory t in the order
  recruited ([] for anything else); a territory's tooltip reads "Free workers: N (each building or unit needs one)";
  an idle unit's details say "Idle: no free worker (skips upkeep)" and explain Workers.

## Out of scope
- Defence totals, walls and terrain (161); raids (162); moving and disbanding (163); training, veterans, upgrades
  (164–166); the sim bot (168).
- A global `strength` modifier.

## Design notes
- `CardDef.UNIT := "unit"` in `CardDef.TYPES`; permanent, so a played unit joins the tableau.
- `strength` in `DataLoader.TYPE_FIELDS` (`[CardDef.UNIT]`).
- Home is `CardInstance.territory_uid` (so workers and idle logic stay on it); `CardInstance.station_uid` is new, set to
  the home when played, copied by `copy()`. `unit_station(uid)` returns it (-1 if uid isn't a unit in the tableau).
- Targets: `Territories.building_targets` without the slot check (`unit_targets`); `CardPlay.needs_target` is true for
  units. `Population.free_workers` and `is_idle` count units homed on the territory with its buildings, in tableau
  order; `Modifiers.working_cards` must skip idle units the same way (it walks the tableau once).
- Content: Warriors (unlocked supply pile). Decided: units take no slot; a unit's worker is always on its home,
  wherever it is stationed, so moving never needs a worker at the destination and disbanding moves no pop.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_units::test_unit_loads_with_its_strength`, `test_bad_unit_strength_is_a_load_error`, `test_unit_with_fixed_land_is_a_load_error`, `test_unit_decks_in_config` |
| AC2 | `test_units::test_playing_a_unit_puts_it_on_its_home`, `test_unit_station_is_minus_1_for_anything_else`, `test_station_survives_a_state_copy` |
| AC3 | `test_units::test_unit_uses_a_worker_on_its_home`, `test_units_need_no_worker_without_population` |
| AC4 | `test_units::test_unit_chooses_between_territories_with_a_free_worker`, `test_unit_refuses_invalid_targets` |
| AC5 | `test_units::test_units_go_idle_after_earlier_buildings`, `test_idle_unit_works_again_when_pop_returns` |
| AC6 | `test_units::test_unit_text_shows_strength`, `test_unit_scores_its_printed_vp` |
| AC7 | `test_content::test_every_unit_has_a_supply_pile_or_a_tech_that_creates_it` |
| AC8 | `test_units::test_units_at_lists_the_units_stationed_on_a_territory`, `test_details_and_tooltip_count_units_as_workers` |

## Manual check
Run `godot --path ../4x-160 -- --seed 5`, buy Warriors (Buy Cards), play it when drawn, open its territory.
- [ ] Warriors in the shipped data: cost 2 food, strength 2, ⟳ −1 food; supply pile price 2, count 6, unlocked.
- [ ] The territory view lists the units stationed there (name, strength), separate from the buildings; an idle unit
  looks idle like an idle building. The territory's tooltip counts units in its free workers.
- [ ] Playing Warriors from hand flies it to its territory like a building.

## Log
- 2026-10-03: Built in a worktree. `CardDef.uses_worker()` (buildings and units) drives workers, idle and
  `working_cards`; `Territories.workers_on` replaces `buildings_on` for pop, which still counts slots. Units target
  through `Territories.unit_targets` (no slot, no requires). Warriors shipped (cost 2 food, strength 2, ⟳ −1 food;
  unlocked supply pile, price 2, count 6). UI: a bronze `Palette.UNIT` (Night bc8f72, Day a97f63), units in their
  own row under a "Units" caption in the territory view (keyboard focus walks both rows); no type mark yet (no icon).
- AC8 added during green to back the Manual check; `test_workers`' tooltip test changed with the new wording.
- Balance: Warriors only cost food each turn until 161/162 give strength a use; the sim bot may buy them for nothing
  (168).
