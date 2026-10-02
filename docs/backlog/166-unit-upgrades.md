---
id: 166
title: Upgrade units in place once a tech opens the better one
type: feature
status: ready
branch: feat/166-unit-upgrades
---

## Goal
Old soldiers re-equip instead of being replaced: once a tech unlocks a better unit, a unit can be upgraded in place by
paying the difference in cost. Keeps garrisons relevant into later eras. Follows 165.

## Acceptance criteria
- [ ] AC1 (loader): A unit may set `upgrades_to`, another unit's id; an unknown id or a non-unit is a load error naming
  file, card and field; on another type it is ignored with a warning.
- [ ] AC2 (upgrade): Given a Levy (cost 1 food, upgrades_to Pikes) on Homeland, Pikes (unit, cost 3 food, strength 3)
  with an unlocked supply pile and 2 food, when `upgrade_unit(levy)`, then food is 0, the Levy is in `removed`, and a
  Pikes in the tableau has the Levy's home, station and veteran counters. No action is used and the supply pile is not
  lowered.
- [ ] AC3 (cost): The price per resource is max(0, new cost − old cost); a resource the old unit cost more of costs 0.
  `upgrade_cost(uid)` returns it.
- [ ] AC4 (errors): `upgrade_unit_error` is `"Levy can't be upgraded."` without `upgrades_to`, `"Pikes isn't unlocked
  yet."` while its pile is locked (or it has no pile), names the price when short ("Upgrading Levy needs 2 food (you
  have 1)."), refuses under Anarchy with the build message, and covers a non-unit, a pending decision and game over;
  `upgrade_unit` then changes nothing.
- [ ] AC5 (idle): An idle unit can be upgraded and stays idle (the new card takes its place in placement order).

## Out of scope
- Upgrade chains in one step; discounts on upgrades.

## Design notes
- `upgrades_to` in `DataLoader.TYPE_FIELDS` (`[CardDef.UNIT]`). New API `upgrade_unit(uid)`, `upgrade_unit_error(uid)`,
  `upgrade_cost(uid)`. The new card takes the old one's tableau index so workers and idle order are unchanged.

## Test plan
| AC | Test |
|---|---|

## Manual check
- [ ] Shipped: Warriors upgrades to Swordsmen (167); an Upgrade button in a unit's details, disabled with the error as
  its tooltip.

## Log
