---
id: 111
title: Civilizations can start on their own home territory
type: feature
status: ready
branch: feat/111-civilization-home-territory
---

## Goal
Each civilization starts where history put it: Egypt on the Nile's flood strip in the desert, Sumer in the southern
Mesopotamian marshes at the head of the Gulf, Babylon on the alluvial plain upriver, Phoenicia on the cedar coast of
Lebanon, Greece in the Aegean coastal hills, Persia in the Zagros upland valleys.

Depends on 131 (the territory set these homes come from).

## Acceptance criteria
Fixtures: a test civilization with `home: "<a second TEST territory>"`; TEST `starting.territory` is the default.

- [ ] AC1 (loader): civilization field `home` is optional: a territory card id. An unknown id or a non-territory is a
  load error naming the card and `home`. `population.start` must fit each listed civilization's home housing, else
  a load error naming config.json, `population.start` and the civilization.
- [ ] AC2: `new_game(seed, civ)` with a home settles that territory as the starting one (the capital on it, pop
  `population.start`); with no home it uses `starting.territory`, as today.
- [ ] AC3 (seed): the same seed deals the same deck order, supply and territory deck whatever the civilization; the
  home territory is not drawn from the territory deck (so it isn't removed from it either).
- [ ] AC5 (content): in the real data every listed civilization has a `home`, the listed homes are all different, and
  each home can take more than half of the starting deck's building copies (its keywords meet their `requires`), so a
  civilization never starts with mostly dead buildings.
- [ ] AC4: the home territory's resource roll (if any) uses the same rng step as the default starting territory's, so
  the rolls after it don't shift between civilizations.

## Out of scope
- Choosing the starting territory separately from the civilization.

## Design notes
- New `CardDef` field `home` (civilization only). Card text: "Starts on: River Valley."
- Homes (territory ids from 131): Egypt → `desert_floodplain`, Sumer → `delta_marsh`, Babylon → `alluvial_plain`,
  Phoenicia → `cedar_coast`, Greece → `coastal_hills`, Persia → `highland_valley`. All have housing ≥ 2, so
  `population.start` (2) fits.
- Every home has `fresh_water` (true of every early civilization, and the starting deck's Farms and Irrigation need it).
  AC5 checks the effect (most starting buildings fit) without naming the keyword.
- Homes are ordinary territory types that also appear in the territory deck, so players learn one set of cards.
- Egypt's per-fresh-water food bonus (107) counts its home; revisit in balance.

## Test plan
| AC | Test |
|---|---|

## Manual check
- [ ] Each civilization's game starts on its listed home; the territory view shows it with the capital.

## Log
