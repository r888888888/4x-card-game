---
id: 339
title: Split ConfigLoader: population, tiers and unrest in their own loader
type: feature
status: done
branch: feat/339-config-loader-split
---

## Goal
`engine/config_loader.gd` is at 680 of its 700 lines, so the next config field would fail the suite. It parses two
groups of config that share little: the decks, supply, build menu, civilizations and terrains, and the population
rules (population, famine, settlement tiers, unrest, governments' `tolerates`, the start buildings' homes). The second
group moves to its own class. No behaviour changes.

## Acceptance criteria
- [x] AC1: A new class `PopulationConfig` in `engine/population_config.gd` parses `population` (with famine and
  relief), settlement tiers, `unrest`, the tier checks on governments and buildings, and the civilizations' homes
  (start pop housed, start buildings fit); `ConfigLoader.parse_config` calls it, and `engine/config_loader.gd` declares
  none of `_parse_population`, `_parse_tiers`, `_parse_famine`, `_parse_relief`, `_parse_unrest`,
  `_check_homes_house_start`, `_check_tolerates`, `_check_building_tiers`, `_check_start_buildings`.
- [x] AC2: `engine/config_loader.gd` is at most 450 lines and the new file at most 350 (structure test).
- [x] AC3: `DataLoader.parse_config` stays the entry point: every caller and test calls it unchanged.
- [x] AC4: Behaviour is pinned: every existing test passes unedited (same errors, warnings and their order) and the
  real data loads without errors. Manual: `scripts/sim.sh 20` output is identical before and after.

## Out of scope
- Any new config field or message change.

## Design notes
- Functions that move today: `_parse_population`, `_parse_tiers`, `_check_homes_house_start`, `_check_tolerates`,
  `_check_building_tiers`, `_parse_famine`, `_parse_unrest`, `_parse_relief` (`config_loader.gd:217–454`); plus
  `_check_start_buildings` (needed to get under 450; it is about the civilizations' homes, like
  `_check_homes_house_start`). It stays called where it is today, so it becomes a public `check_start_buildings`. Keep the order checks run in, so error lists keep their order.
- After 338, so the loader tests it adds are in place.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_data_loader::test_population_rules_parse_in_population_config_not_config_loader` |
| AC2 | `test_data_loader::test_config_loader_under_450_lines_and_population_config_under_350` |
| AC3 | The whole suite, unedited (every test calls `DataLoader.parse_config` / `load_all`) |
| AC4 | The whole suite, unedited; `test_real_data_loads`; `scripts/sim.sh 20` before/after (Log) |

## Log
- 2026-10-06: specced from the project review.
- 2026-10-06: built. `engine/config_loader.gd` 681 → 433 lines, `engine/population_config.gd` 262. Public API:
  `PopulationConfig.parse(raw, config, cards, errs, warnings, src)` (the old population/famine/unrest/tier block, same
  order) and `PopulationConfig.check_start_buildings` (called where it was, so errors keep their order); the rest stay
  private. `POPULATION_FIELDS` moved with them. Suite 2298 → 2300, no existing test edited. The real data's
  `load_all` result (config with key order, errors, warnings, every card's `tolerates_name` and `tier_name`) dumped
  as JSON before and after: byte-identical.
- 2026-10-06: merged. The `scripts/sim.sh 20` comparison was cancelled at the user's request before it ran; the
  byte-identical `load_all` dump above stands in for it.
