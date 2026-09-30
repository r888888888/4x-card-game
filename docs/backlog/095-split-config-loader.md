---
id: 095
title: Split config parsing out of DataLoader into ConfigLoader
type: feature
status: ready
branch: feat/095-split-config-loader
---

## Goal
`engine/data_loader.gd` is 677 lines, 23 below the 700-line hard limit. The next planned features both add config
parsing: 084 adds a famine relief price and 074 adds event decks by era, so either could break the suite. The file
holds two separate jobs, parsing cards and parsing the config, and the split follows that boundary. No behavior
changes.

## Acceptance criteria
- [ ] AC1: A new `engine/config_loader.gd` (`class_name ConfigLoader`) holds config parsing: `parse_config` and
  every helper only it uses. That covers `_parse_era_names`, `_parse_era_unlocks`, `_parse_population`,
  `_parse_famine`, `_parse_territory_resources`, `_parse_resource_option`, `_parse_supply`, `_check_unlocks`,
  `_parse_civilizations`, `_parse_starting_card` and `_parse_counts`, plus the config-only constants
  (`CONFIG_FIELDS`, `POPULATION_FIELDS`, `SUPPLY_TYPES`, `DECK_MODELS`, `SEPARATE_DECK_TYPES`).
- [ ] AC2: `DataLoader` keeps `load_all`, `read_json`, `parse_resources`, `parse_keywords`, card parsing and the
  card constants (`CARD_FIELDS`, `TYPE_FIELDS`, `TYPE_PLURALS`, `NO_TERRITORY_TYPES`, `DISCARD_CONDITIONS`).
  `DataLoader.parse_config(...)` stays as a one-line delegator with the same signature, so callers don't change.
- [ ] AC3: Every existing test passes unedited. Every loader error and warning message is byte-identical: all of
  them go through the existing table tests.
- [ ] AC4: `scripts/sim.sh 20` output is identical before and after.
- [ ] AC5: Both files are at most 500 lines (no `WARN` for either in `scripts/test.sh`). `PLAN.md`'s layout lists
  `config_loader.gd`, and the CLAUDE.md line on `DataLoader.TYPE_FIELDS` still holds.

## Out of scope
- Splitting `game_engine.gd` (609 lines, under the hard limit).
- New validation, and 084's and 074's config fields.

## Design notes
- `load_all` calls `ConfigLoader.parse_config` directly. The delegator exists for the ~39 test call sites (fewer
  after 091's `config_errors_for`). Removing it later is a rename-only change.
- If a helper is shared (for example `Fields` reads), it stays in `Fields`. Don't duplicate it.
- Commit the move as one step so `git log --follow` and the diff read as a move.

## Test plan
| AC | Test |
|---|---|
| AC1–2 | checked by the file list and `grep -n "^static func" engine/*loader.gd` |
| AC3 | the existing suite, unedited |
| AC4 | `scripts/sim.sh 20` diffed against `main` |
| AC5 | `wc -l`, `scripts/test.sh` output |

## Log
- 2026-09-30: Specced from the project review. Must land before 084 and 074 (review decision: refactors first).
