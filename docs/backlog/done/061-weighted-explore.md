---
id: 061
title: Explore favours territories like the ones you know
type: feature
status: wontfix
branch: feat/061-weighted-explore
---

## Goal
Exploring feels like finding the land around you (TODO 13). Territories that share terrain with what you've already
explored are more likely to be revealed. It's still random and seeded.

## Acceptance criteria
Explored = territories in the frontier and in the tableau (the Capital's included). Only printed terrain keywords
(`def.keywords`) count; rolled resource keywords (gold, tin, copper) don't.
Fixtures: a new TEST_CARDS territory `lake` ("Lake", slots 2, keywords ["fresh_water"]). The test
`territory_deck` is {grassland: 1, hills: 2, river: 1, lake: 1, jungle: 1}.

- [ ] AC1 (weights): New API `explore_weights() -> {uid: weight}` covers every territory-deck card, with weight 1 + the
  number of explored territories that share at least one printed keyword with it. At the start (only homeland, no
  keywords) every weight is 1. With one Hills settled, the other Hills weighs 2. With the river also in the frontier,
  the lake weighs 2, and grassland and jungle stay 1.
- [ ] AC2 (resources ignored): Two territories that only share a rolled resource keyword don't raise each other's
  weight.
- [ ] AC3 (draw): Explore reveals 2 different territory-deck cards, drawn by weight without replacement using the
  engine rng. The same seed and the same actions give the same reveal. The unpicked one goes back into the territory
  deck.
- [ ] AC4 (bias): Over seeds 1–300, with one Hills settled and the deck {hills: 1, grassland: 1, jungle: 1, lake: 1},
  the Hills is revealed more often than the lake.
- [ ] AC5 (edge cases unchanged): With 1 territory left it is taken automatically. With 0, nothing happens.

## Out of scope
- A neighbour table between terrains (rejected in favour of shared keywords).
- Weighting by territories you've seen and declined.

## Design notes
- `Territories.explore` picks by weight instead of `take_top`. Deck order no longer matters for exploring, but the
  deck is still shuffled at setup (same rng use, so other seeded results stay put).
- A declined territory goes to the bottom (or anywhere; position no longer matters).
- Sim before/after in the Log: how often a player's territories share terrain.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_explore::test_…` |

## Manual check
- [ ] Settle a Hills; later explores offer hills and highlands noticeably more often.

## Log
- 2026-09-29: Dropped at the user's request while writing the red tests; nothing was committed.
