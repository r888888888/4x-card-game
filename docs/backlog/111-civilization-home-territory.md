---
id: 111
title: Civilizations can start on their own home territory
type: feature
status: ready
branch: feat/111-civilization-home-territory
---

## Goal
Each civilization starts where history put it: Egypt on the Nile (River Valley), Phoenicia on the coast (Bay),
Persia on the plains, Greece in the hills, Sumer and Babylon on the Mesopotamian floodplain.

## Acceptance criteria
Fixtures: a test civilization with `home: "<a second TEST territory>"`; TEST `starting.territory` is the default.

- [ ] AC1 (loader): civilization field `home` is optional: a territory card id. An unknown id or a non-territory is a
  load error naming the card and `home`. `population.start` must fit each listed civilization's home housing, else
  a load error naming config.json, `population.start` and the civilization.
- [ ] AC2: `new_game(seed, civ)` with a home settles that territory as the starting one (the capital on it, pop
  `population.start`); with no home it uses `starting.territory`, as today.
- [ ] AC3 (seed): the same seed deals the same deck order, supply and territory deck whatever the civilization; the
  home territory is not drawn from the territory deck (so it isn't removed from it either).
- [ ] AC4: the home territory's resource roll (if any) uses the same rng step as the default starting territory's, so
  the rolls after it don't shift between civilizations.

## Out of scope
- Choosing the starting territory separately from the civilization.

## Design notes
- New `CardDef` field `home` (civilization only). Card text: "Starts on: River Valley."
- Proposed homes: Egypt → River Valley, Sumer → Floodplain Delta, Babylon → River Valley, Phoenicia → Bay,
  Greece → Hills, Persia → Plains. Check `population.start` (2) fits each (all have housing ≥ 2).
- Egypt's per-fresh-water food bonus (107) grows with a River Valley home; revisit in balance.

## Test plan
| AC | Test |
|---|---|

## Manual check
- [ ] Each civilization's game starts on its listed home; the territory view shows it with the capital.

## Log
