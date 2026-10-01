---
id: 031
title: More Scouts and Settlers in the starting deck
type: feature
status: done
branch: feat/031-more-scouts-settlers
---

## Goal
Scouts show up too rarely, so the player gets few chances to expand. Raise the Scout and Settler
counts so exploring and settling come up more often, keeping the deck at 28 cards.

## Acceptance criteria
- [x] AC1: `data/config.json` deck has scout 4 (was 3) and settler 4 (was 3).
- [x] AC2: The deck stays at 28 cards: forage 2 (was 3), irrigation 1 (was 2).
- [x] AC3: The full suite stays green (rules tests use `TEST_CARDS`, not the real deck).

## Out of scope
- A paid Explore action, Settlers that explore, exploring techs or buildings (brainstormed, not chosen).
- Balance simulation.

## Design notes
- Data-only balance change: no engine, loader or effect changes, so no new test.
- Scout draw odds per card go from 3/28 (~11%) to 4/28 (~14%).
- Irrigation was cut because it needs Fresh Water and is often a dead draw. If food gets too tight
  for 5-food Settlers, cut Mine or Lumber Camp instead of Forage.

## Manual check
- [ ] Play a few games: a Scout turns up in the first few turns more often, and there is usually
  enough food to follow up with a Settler.

## Log
- 2026-09-29: Counts chosen from the expansion brainstorm (option 1, data-only tuning).
- 2026-09-29: Approved by the user.
