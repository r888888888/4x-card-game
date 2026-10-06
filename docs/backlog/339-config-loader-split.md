---
id: 339
title: Split ConfigLoader: population, tiers and unrest in their own loader
type: feature
status: draft
branch: feat/339-config-loader-split
---

## Goal
`engine/config_loader.gd` is at 680 of its 700 lines, so the next config field would fail the suite. It parses two
groups of config that share little: the decks, supply, build menu, civilizations and terrains, and the population
rules (population, famine, settlement tiers, unrest, governments' `tolerates`, the start buildings' homes). The second
group moves to its own class. No behaviour changes.

## Acceptance criteria
- [ ] AC1: A new class (e.g. `PopulationConfig` in `engine/population_config.gd`) parses `population` (with famine and
  relief), settlement tiers, `unrest`, and the tier checks on governments and buildings; `ConfigLoader.parse_config`
  calls it and declares none of those parse functions.
- [ ] AC2: `engine/config_loader.gd` is at most 450 lines and the new file at most 350 (structure test).
- [ ] AC3: `DataLoader.parse_config` stays the entry point: every caller and test calls it unchanged.
- [ ] AC4: Behaviour is pinned: every existing loader test passes unedited (same errors, warnings and their order),
  the real data loads to the same config, and `scripts/sim.sh 20` output is identical before and after.

## Out of scope
- Any new config field or message change.

## Design notes
- Functions that move today: `_parse_population`, `_parse_tiers`, `_check_homes_house_start`, `_check_tolerates`,
  `_check_building_tiers`, `_parse_famine`, `_parse_unrest`, `_parse_relief` (`config_loader.gd:217–454`); check
  `_check_start_buildings` too. Keep the order checks run in, so error lists keep their order.
- After 338, so the loader tests it adds are in place.

## Test plan
| AC | Test |
|---|---|

## Log
- 2026-10-06: specced from the project review.
