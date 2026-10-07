---
id: 167
title: Era units and era 2–3 raids
type: feature
status: red-review
branch: feat/167-military-content
---

## Goal
Fill the military out across the eras: units opened by techs and harsher raids in later eras, so defence keeps pace
with the threat. Content only; numbers are a first guess until a balance item. Follows 166.

## Acceptance criteria
- [ ] AC1 (invariant): Every unit in the real data can be had: a build-menu entry open from the start, or unlocked by
  a research-deck tech (units are recruited from the build menu since 296, not dealt or bought).
- [ ] AC2 (invariant): Every `upgrades_to` in the real data names a unit with a strictly higher strength whose entry
  opens no earlier; there are at least 2 unit upgrades, and every unit open on turn 1 has one.
- [ ] AC3 (invariant): Every era the research deck reaches opens a unit stronger than any unit of the eras before, and
  each era that has raids has a unit open by that era.
- [ ] AC4 (invariant): Every era the research deck reaches has a raid whose strength beats every earlier era's
  raids, and every raid's `targets` keywords appear on some territory a game can hold.

## Out of scope
- New rules; the bot (168); balance tuning.

## Design notes
- New techs: Archery (era 1) and Chariot (era 2, prereq The Wheel, eureka 1 Pasture; replaces the first spec's era-1
  Horseback Riding, see Log). Bronze Working also unlocks Spearmen; Iron Working (era 3) unlocks Swordsmen. Each new
  tech gets flavor and a real quote (style guide §18), and the new raids flavor.
- Unit entries go in `build_menu` locked, opened by the techs' `unlock` effects.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_content::test_every_era_opens_a_stronger_unit` (its "can be had" check); also the existing `test_units_are_in_the_build_menu_not_the_deck_or_supply`, `test_every_locked_build_menu_entry_is_unlocked_by_a_tech_and_back` |
| AC2 | `test_every_unit_upgrade_is_stronger_and_opens_no_earlier`, `test_every_unit_open_on_turn_1_has_an_upgrade` |
| AC3 | `test_every_era_opens_a_stronger_unit`, `test_every_raid_era_has_a_unit_open_by_then` |
| AC4 | `test_every_era_has_a_raid_stronger_than_the_eras_before`, `test_every_raid_target_is_on_some_territory` |

## Manual check
- [ ] Units: Spearmen (Bronze Working; 2 food 1 wealth, strength 3, ⟳ −1 food), Archers (Archery; 1 food 1 wealth,
  strength 2, ⟳ −1 wealth: a cheap garrison that doesn't eat), Chariots (Chariot; 2 food 2 wealth, strength 4,
  ⟳ −1 food), Swordsmen (Iron Working; 2 food 3 wealth, strength 5, ⟳ −1 food −1 wealth).
  Upgrades: Warriors → Spearmen → Swordsmen.
- [ ] Raids: era 2 Horse Raiders (5, grassland/desert), Pirates (5, coastal), era 3 Barbarian Horde (8, no targets).
- [ ] Each new tech appears in the tech tree with what it gives; each unit's details show its Upgrade once 166's
  button applies (Warriors: "Upgrade to Spearmen for 1 wealth (no action).").
- [ ] Balance worry: raids of 5 and 8 against era garrisons; run `scripts/sim.sh --level 2 --compare <main checkout>`.

## Log
- 2026-10-04, tech review (272–275): for realism, consider replacing era-1 Horseback Riding with the **Chariot** (era
  2, needs The Wheel, eureka 1 Pasture): chariots ruled Bronze Age warfare from about 1700 BCE, and war-horses
  carrying riders came only around 900 BCE. Horsemen could then come with an era-3 Cavalry tech. 274 and 275 leave
  the Chariot to this item.
- 2026-10-06, red: the user chose the era-2 Chariot over Horseback Riding (Chariots strength 4, so era 2's best unit
  beats era 1's). The first spec predated the build menu (296) and era-1 raids (Raiders, Sea Raiders, Hill Tribes
  exist), so its four invariants already held; the user approved goal-shaped invariants that fail until the content
  lands (each era opens a stronger unit and a stronger raid; turn-1 units have upgrades).
