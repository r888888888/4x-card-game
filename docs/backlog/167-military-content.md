---
id: 167
title: Era units and era 2–3 raids
type: feature
status: ready
branch: feat/167-military-content
---

## Goal
Fill the military out across the eras: units opened by techs and harsher raids in later eras, so defence keeps pace
with the threat. Content only; numbers are a first guess until a balance item. Follows 166.

## Acceptance criteria
- [ ] AC1 (invariant): Every unit in the real data can be had (a supply pile, or a tech creates it), and every locked
  unit pile is unlocked by some tech.
- [ ] AC2 (invariant): Every `upgrades_to` in the real data names a unit with a strictly higher strength.
- [ ] AC3 (invariant): Each era that has raids has at least one unit whose pile is open by that era (unlocked from the
  start, or unlocked by a tech of that era or earlier).
- [ ] AC4 (invariant): Every raid's `targets` keywords appear on at least one territory in the territory deck or a
  home.

## Out of scope
- New rules; the bot (168); balance tuning.

## Design notes
- New techs: Archery (era 1) and Horseback Riding (era 1, after Animal Husbandry). Bronze Working also unlocks
  Spearmen; Iron Working unlocks Swordsmen.

## Test plan
| AC | Test |
|---|---|

## Manual check
- [ ] Units: Spearmen (Bronze Working; 2 food 1 wealth, strength 3, ⟳ −1 food), Archers (Archery; 1 food 1 wealth,
  strength 2, ⟳ −1 wealth: a cheap garrison that doesn't eat), Horsemen (Horseback Riding; 2 food 2 wealth,
  strength 3, ⟳ −1 food), Swordsmen (Iron Working; 2 food 3 wealth, strength 5, ⟳ −1 food −1 wealth).
  Upgrades: Warriors → Spearmen → Swordsmen.
- [ ] Raids: era 2 Horse Raiders (5, grassland/desert), Pirates (5, coastal), era 3 Barbarian Horde (8, no targets).
- [ ] Each new tech appears in the tech tree with what it gives.

## Log
- 2026-10-04, tech review (272–275): for realism, consider replacing era-1 Horseback Riding with the **Chariot** (era
  2, needs The Wheel, eureka 1 Pasture): chariots ruled Bronze Age warfare from about 1700 BCE, and war-horses
  carrying riders came only around 900 BCE. Horsemen could then come with an era-3 Cavalry tech. 274 and 275 leave
  the Chariot to this item.
