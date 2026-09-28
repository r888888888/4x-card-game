---
id: 010
title: Buy growth with food
type: feature
status: ready
branch: feat/010-buy-growth
---

## Goal
During the play phase, the player can spend food to grow a territory by 1 pop. Each step costs
more than the last, so growing tall gets expensive. Depends on 009.

## Acceptance criteria
- [ ] AC1: Given population on, Homeland with pop 2 and housing 7, and 5 food, when I call
  `grow(homeland_uid)`, then it returns true, Homeland has pop 3, food is 2 (cost = current pop + 1 = 3),
  and `changed` is emitted.
- [ ] AC2: Given the same, after that first growth, a second `grow(homeland_uid)` with 2 food is
  rejected: `grow_error` says it needs 4 food (you have 2), `grow` returns false, and pop and food are
  unchanged. With 4 food it succeeds (pop 4, food 0). There is no per-turn limit.
- [ ] AC3: Given a territory whose pop equals its housing, then `grow_error` is non-empty (it's at
  housing), and `grow` returns false and changes nothing.
- [ ] AC4: `grow` is rejected with no change, and `grow_error` gives a reason, when: the uid is not a
  settled territory (a frontier territory, a city, an unknown uid), a territory choice is pending, the
  game is over, or the config has no `population` block.
- [ ] AC5: Given a legal growth, then `grow_error(uid)` is "" before the call.

## Out of scope
- Growth from cards (013).

## Design notes
- Engine API: `grow_error(territory_uid) -> String` and `grow(territory_uid) -> bool`, modelled on
  `play_error` / `play_card`. This is a player action, not a card, so it emits no `card_played`.
- UI: a "Grow (N food)" button on each settled territory, disabled with `grow_error` as its tooltip.

## Test plan
| AC | Test |
|---|---|

## Manual check
- [ ] The Grow button on a territory shows the current cost, and clicking it adds 1 pop and spends the food.
- [ ] The button is disabled with a reason when you can't afford it or the territory is at housing.

## Log
- 2026-09-28: spec'd with the user. Cost = current pop + 1 food, no limit per turn.
