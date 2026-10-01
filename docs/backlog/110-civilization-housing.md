---
id: 110
title: Modifiers can add housing to every territory (Sumer houses +1 pop everywhere)
type: feature
status: ready
branch: feat/110-modifier-housing
---

## Goal
A civilization (or later a tech, building, government or event) can let every settled territory hold more pop.
Sumer, which built the first cities, houses +1 pop everywhere. Builds on 129's `modifiers` field as the key
`housing`, instead of a civilization-only `housing_bonus`.

Growing never uses an action (127), so this bonus is pure food-for-VP headroom and doesn't compete with card plays.

## Acceptance criteria
Fixtures: a test civilization with `modifiers: {"housing": 1}`; a test building (no cost) with
`modifiers: {"housing": 1}`.

- [ ] AC1 (loader): `housing` is a valid key in `DataLoader.MODIFIER_KEYS`.
- [ ] AC2: with the civilization, `housing(t)` of a settled territory with printed housing 5 and no buildings is 6;
  with a building whose own `housing` field adds +2 it is 8. Without it, or on an unsettled territory (0), nothing
  changes. The total is never below 1 on a settled territory.
- [ ] AC3: growth stops at the raised cap: a territory at 5/6 pop grows to 6, and a territory at 6/6 does not grow.
- [ ] AC4: the +1 building raises every settled territory's housing while it works; when it goes idle, each drops
  back by 1 (pop above the new cap stays, but can't grow). Its own `housing` field, if any, is unaffected.
- [ ] AC5 (loader): `population.start` is checked against the starting territory's printed housing, not modifiers
  (they depend on the civilization chosen).
- [ ] AC6 (text): a card with `modifiers: {"housing": 1}` has the text "Every territory houses 1 more pop".

## Out of scope
- Removing a building's own `housing` field (its own territory only, counted idle or not).

## Design notes
- Needs 129. `Population.housing` adds `e.modifier("housing")` for a settled territory.
- Content after this item: Sumer gets `modifiers: {"housing": 1}`.

## Test plan
| AC | Test |
|---|---|

## Manual check
- [ ] As Sumer, territory pop reads "/ 6" on the starting territory.

## Log
- 2026-09-30: reworked onto 129's shared `modifiers` field (was a civilization-only `housing_bonus`); added the idle
  building case (AC4) that the shared lookup brings.
