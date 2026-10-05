---
id: 308
title: Fill the building roster's gaps: Palace, Shipyard, Terraced Fields, Reed Works, Cistern, Dye Works, Kiln
type: feature
status: ready
branch: feat/308-gap-buildings
---

## Goal
The realism pass found buildings the ancient world depended on that the game lacks, and terrains with too little to
build: mountains have no food building, marshes only Fishing Huts, Pottery opens no craft, and the Bronze Age's
central building, the palace, is missing. After this the roster covers them, including one Metropolis-only building
per realm (the Palace) for the tall end. Content only. Follows 307.

## Acceptance criteria
Content tests, naming no card id:
- [ ] AC1: Every territory card in the territory deck (and every civilization's home) can hold a non-upgrade building
  that makes food on upkeep (its `requires` met by the territory's keywords, or empty). Fails today: Mountains has none.
- [ ] AC2: Every non-wonder building with `once` has a tier: a one-per-realm building is the reward of a large
  settlement.

## Out of scope
- Buildings only one civilization can build (Dye Works stays open to all; a civ-only rule would need an engine item).
- A building that adds a keyword to its territory (an Aqueduct or Cistern counting as fresh water).
- Tuning: the balance item after this.

## Design notes
- New buildings (first-pass numbers):
  - **Palace**: Metropolis, `once`, Code of Laws: 3 VP, +1 action each turn (`modifiers.actions`). Every Bronze Age city
    of note (Mari, Ugarit, Knossos) centred on one.
  - **Shipyard**: requires coastal, Sailing: ⟳ +1 wealth, +1 more on forest (timber; Cedar Coast). The Phoenicians'
    core industry.
  - **Terraced Fields**: requires hills or mountain, Masonry: ⟳ +1 food, +1 more on fresh water. Levantine hill farming
    ran on dry-stone terraces. Gives Mountains a food building (AC1).
  - **Reed Works**: requires marsh, open from turn 1: housing 1, ⟳ +1 wealth. Reeds gave the Mesopotamian marshes boats,
    mats and houses.
  - **Cistern**: requires hills or desert, Engineering: housing 2. Plastered cisterns let Iron Age people settle hills
    with no river.
  - **Dye Works**: requires coastal, Weaving: ⟳ +2 wealth. Tyrian purple, the Phoenician luxury dye.
  - **Kiln**: anywhere, Pottery: ⟳ +1 wealth. Pottery's first craft.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_content::test_…` |

## Manual check
- [ ] Palace: Code of Laws, 10 wealth, tier Metropolis, once, 3 VP, +1 action.
- [ ] Shipyard: Sailing, coastal, 4 wealth, ⟳ +1 wealth, +1 more on forest.
- [ ] Terraced Fields: Masonry, hills or mountain, 1 food + 3 wealth, ⟳ +1 food, +1 more on fresh water.
- [ ] Reed Works: turn 1, marsh, 2 wealth, housing 1, ⟳ +1 wealth.
- [ ] Cistern: Engineering, hills or desert, 4 wealth, housing 2.
- [ ] Dye Works: Weaving, coastal, 4 wealth, ⟳ +2 wealth.
- [ ] Kiln: Pottery, anywhere, 3 wealth, ⟳ +1 wealth.

## Log
- 2026-10-05: specced from the realism pass of the tall-buildings design.
