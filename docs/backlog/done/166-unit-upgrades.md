---
id: 166
title: Upgrade units in place once a tech opens the better one
type: feature
status: done
branch: feat/166-unit-upgrades
---

## Goal
Old soldiers re-equip instead of being replaced: once a tech unlocks a better unit, a unit can be upgraded in place by
paying the difference in cost. Keeps garrisons relevant into later eras. Follows 165.

## Acceptance criteria
- [x] AC1 (loader): A unit may set `upgrades_to`, another unit's id; an unknown id or a non-unit is a load error naming
  file, card and field; on another type it is ignored with a warning. Its card text reads "Upgrades to Pikes.".
- [x] AC2 (upgrade): Given a Levy (cost 1 food, upgrades_to Pikes) on Homeland, Pikes (unit, cost 3 food 1 wealth,
  strength 3) with an unlocked build-menu entry, and 2 food and 1 wealth, when `upgrade_unit(levy)`, then food and
  wealth are 0, the Levy is in `removed`, and a Pikes in the tableau has the Levy's home, station and veteran counters
  and its tableau place. No action is used and the build menu is unchanged.
- [x] AC3 (cost): The price per resource is max(0, new cost − old cost); a resource the old unit cost more of costs 0.
  `upgrade_cost(uid)` returns it.
- [x] AC4 (errors): `upgrade_unit_error` is `"Levy can't be upgraded."` without `upgrades_to`, `"Pikes isn't unlocked
  yet."` while its build-menu entry is locked (or it has none), names the price when short ("Upgrading Levy needs 2 food (you
  have 1)."), refuses under Anarchy with the build message, and covers a non-unit, a pending decision and game over;
  `upgrade_unit` then changes nothing.
- [x] AC5 (idle): An idle unit can be upgraded and stays idle (the new card takes its place in placement order).
- [x] AC6 (bots): `legal_actions` lists `["upgrade_unit", uid]` for each unit `upgrade_unit_error` allows (after
  `move_unit`), and the blocking and coverage tables have a row for it.

## Out of scope
- Upgrade chains in one step; discounts on upgrades.

## Design notes
- `upgrades_to` in `DataLoader.TYPE_FIELDS` (`[CardDef.UNIT]`). New API `upgrade_unit(uid)`, `upgrade_unit_error(uid)`,
  `upgrade_cost(uid)`. The new card takes the old one's tableau index so workers and idle order are unchanged.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_unit_upgrades::test_upgrades_to_loads_on_units`, `test_bad_upgrades_to_is_a_load_error`, `test_upgrades_to_text` |
| AC2 | `test_upgrading_a_unit_replaces_it_in_place_for_the_difference` |
| AC3 | `test_upgrade_cost_is_the_printed_difference_never_below_0` |
| AC4 | `test_upgrade_unit_errors`, `test_a_locked_or_missing_entry_cant_be_upgraded_to`, `test_no_upgrade_under_anarchy`, `test_no_upgrade_while_a_decision_is_owed_or_after_the_game`, `test_a_refused_upgrade_changes_nothing` |
| AC5 | `test_an_upgraded_unit_keeps_its_place_among_the_workers` |
| AC6 | `test_legal_actions::test_166_an_upgradable_unit_lists_its_upgrade`, its coverage row; `test_blocking`'s action row |
| Manual check | `test_upgrade_line_names_the_upgrade_and_its_price`, `test_details_upgrade_a_unit` (added in green, test-first) |

## Manual check
- [ ] No shipped unit has `upgrades_to` yet (Warriors → Swordsmen is 167), so try it once 167 lands, or with a
  local `upgrades_to` on Warriors: open a recruited unit's details. Upgrade shows beside Move… and Disband, disabled
  with the reason as its tooltip ("Swordsmen isn't unlocked yet."), enabled with "Upgrade to … for … (no action)."
  once its entry is open; pressing it swaps the card in place in the territory view, same station, no action used.
- [ ] A unit with no upgrade shows no Upgrade button.

## Log
- Red: the spec predated the build menu (295, 296), where units are recruited; "supply pile" became the unit's
  build-menu entry. Added AC6 (legal_actions, the guard tables) and the card text line to AC1.
- Green: the upgrade resolves no play effects and emits no card_played/built (it re-equips, it isn't played). The
  shortfall loop is shared as `CardPlay.short_of` (place_error and upgrade_unit_error).
- `game_engine.gd` crossed its 500-line limit (test_engine_structure): `upgrade_cost` and the new `upgrade_line` went
  to `EngineQueries`, which made room by moving `defense`, `defense_parts` and `raid_warning` (territory queries) down
  to `TerritoryQueries`.
- The Manual check's Upgrade button was built here, with an `upgrade_line(uid)` query written test-first.
- Follow-ups: GenericBot sees `upgrade_unit` through legal_actions; no balance run done (worth `scripts/sim.sh --level 2`
  once 167 ships an upgrade).
