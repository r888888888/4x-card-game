---
id: 166
title: Upgrade units in place once a tech opens the better one
type: feature
status: red-review
branch: feat/166-unit-upgrades
---

## Goal
Old soldiers re-equip instead of being replaced: once a tech unlocks a better unit, a unit can be upgraded in place by
paying the difference in cost. Keeps garrisons relevant into later eras. Follows 165.

## Acceptance criteria
- [ ] AC1 (loader): A unit may set `upgrades_to`, another unit's id; an unknown id or a non-unit is a load error naming
  file, card and field; on another type it is ignored with a warning. Its card text reads "Upgrades to Pikes.".
- [ ] AC2 (upgrade): Given a Levy (cost 1 food, upgrades_to Pikes) on Homeland, Pikes (unit, cost 3 food 1 wealth,
  strength 3) with an unlocked build-menu entry, and 2 food and 1 wealth, when `upgrade_unit(levy)`, then food and
  wealth are 0, the Levy is in `removed`, and a Pikes in the tableau has the Levy's home, station and veteran counters
  and its tableau place. No action is used and the build menu is unchanged.
- [ ] AC3 (cost): The price per resource is max(0, new cost − old cost); a resource the old unit cost more of costs 0.
  `upgrade_cost(uid)` returns it.
- [ ] AC4 (errors): `upgrade_unit_error` is `"Levy can't be upgraded."` without `upgrades_to`, `"Pikes isn't unlocked
  yet."` while its build-menu entry is locked (or it has none), names the price when short ("Upgrading Levy needs 2 food (you
  have 1)."), refuses under Anarchy with the build message, and covers a non-unit, a pending decision and game over;
  `upgrade_unit` then changes nothing.
- [ ] AC5 (idle): An idle unit can be upgraded and stays idle (the new card takes its place in placement order).
- [ ] AC6 (bots): `legal_actions` lists `["upgrade_unit", uid]` for each unit `upgrade_unit_error` allows (after
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

## Manual check
- [ ] Shipped: Warriors upgrades to Swordsmen (167); an Upgrade button in a unit's details, disabled with the error as
  its tooltip.

## Log
- Red: the spec predated the build menu (295, 296), where units are recruited; "supply pile" became the unit's
  build-menu entry. Added AC6 (legal_actions, the guard tables) and the card text line to AC1.
