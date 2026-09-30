---
id: 110
title: Civilizations can add housing to every territory
type: feature
status: ready
branch: feat/110-civilization-housing
---

## Goal
A civilization can let every settled territory hold more pop. Sumer, which built the first cities, houses +1 pop
everywhere.

## Acceptance criteria
Fixtures: a test civilization with `housing_bonus: 1`.

- [ ] AC1 (loader): civilization field `housing_bonus` is an optional int ≥ 0 (default 0); a negative value is a load
  error naming the card and the field.
- [ ] AC2: with the bonus, `housing(t)` of a settled territory with printed housing 5 and no buildings is 6; with a
  building adding +2 it is 8. Without a civilization, or on an unsettled territory (0), nothing changes.
- [ ] AC3: growth stops at the raised cap: a territory at 5/6 pop grows to 6, and a territory at 6/6 does not grow.
- [ ] AC4 (loader): `population.start` is checked against the starting territory's printed housing, not the bonus
  (the bonus depends on the civilization chosen).

## Out of scope
- Housing from governments or techs.

## Design notes
- `Population.housing` adds the civilization's bonus. Card text: "Every territory houses 1 more pop."
- Content after this item: Sumer gets `housing_bonus: 1`.

## Test plan
| AC | Test |
|---|---|

## Manual check
- [ ] As Sumer, territory pop reads "/ 6" on the River Meadow.

## Log
