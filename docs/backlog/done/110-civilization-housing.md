---
id: 110
title: Modifiers can add housing to every territory (Sumer houses +1 pop everywhere)
type: feature
status: done
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

- [x] AC1 (loader): `housing` is a valid key in `DataLoader.MODIFIER_KEYS`.
- [x] AC2: with the civilization, `housing(t)` of a settled territory with printed housing 5 and no buildings is 6;
  with a building whose own `housing` field adds +2 it is 8. Without it, or on an unsettled territory (0), nothing
  changes. The total is never below 1 on a settled territory.
- [x] AC3: growth stops at the raised cap: a territory at 5/6 pop grows to 6, and a territory at 6/6 does not grow.
- [x] AC4: the +1 building raises every settled territory's housing while it works; when it goes idle, each drops
  back by 1 (pop above the new cap stays, but can't grow). Its own `housing` field, if any, is unaffected.
- [x] AC5 (loader): `population.start` is checked against the starting territory's printed housing, not modifiers
  (they depend on the civilization chosen).
- [x] AC6 (text): a card with `modifiers: {"housing": 1}` has the text "Every territory houses 1 more pop".

## Out of scope
- Removing a building's own `housing` field (its own territory only, counted idle or not).

## Design notes
- Needs 129. `Population.housing` adds `e.modifier("housing")` for a settled territory.
- Content after this item: Sumer gets `modifiers: {"housing": 1}`.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_housing_modifier::test_housing_is_a_modifier_key` |
| AC2 | `test_housing_modifier::test_a_housing_modifier_adds_to_every_settled_territory`, `test_housing_never_drops_below_1_on_a_settled_territory` |
| AC3 | `test_housing_modifier::test_growth_stops_at_the_raised_cap` |
| AC4 | `test_housing_modifier::test_an_idle_buildings_housing_modifier_stops_but_its_own_housing_doesnt` |
| AC5 | `test_housing_modifier::test_population_start_is_checked_against_printed_housing` (a guard: passes already) |
| AC6 | `test_housing_modifier::test_housing_modifier_text` |

## Manual check
- [ ] As Sumer (seed 1), the starting territory's pop meter in the territory view has one more pip than as Egypt
  (printed housing + 1), and Grow works up to it. Sumer's card reads "Every territory houses 1 more pop".

## Log
- AC4's "pop above the new cap stays" can't happen through idling: a building only goes idle when pop drops below the
  building count, so pop is already low. It can happen when a housing modifier from an event or a replaced card ends;
  `housing` never removes pop, so it holds there too. Not separately tested.
- 2026-09-30: reworked onto 129's shared `modifiers` field (was a civilization-only `housing_bonus`); added the idle
  building case (AC4) that the shared lookup brings.
