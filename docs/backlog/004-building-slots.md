---
id: 004
title: Buildings occupy territory slots
type: feature
status: ready
branch: feat/004-building-slots
---

## Goal
Each building is placed in a settled territory with a free slot, and the player picks which one.
Running out of slots pushes the player to explore and settle again.

## Acceptance criteria
In these criteria, Capital is on Grassland (2 slots) and Farm costs 2.

- [ ] AC1: Given only Grassland settled, with 0 buildings, when I play Farm with no target, then Farm is in
  the tableau, `territory_of(farm)` is Grassland, and `free_slots(grassland)` is 1. The Capital (a city)
  does not use a slot, so `free_slots` was 2 before.
- [ ] AC2: Given Grassland holding 2 buildings and no other settled territory, when I try to play Farm, then
  `play_error` is "No territory with a free slot.", the card stays in hand, and food is unchanged.
- [ ] AC3: Given Grassland and Hills both settled with free slots, when I play Farm with no target, then
  `play_error` is "Choose a territory for Farm." When I play it targeting Hills, then it is placed on Hills.
- [ ] AC4: Given a full Grassland and Hills with a free slot, `valid_targets(farm)` is [hills]. Playing Farm
  with no target auto-places it on Hills. Targeting Grassland gives "That target isn't valid."
- [ ] AC5: Territories in the frontier are never valid building targets.

## Out of scope
- Keyword requirements (005).
- Demolishing or moving buildings.

## Design notes
- **Engine API:** `free_slots(territory_uid) -> int` counts buildings whose `territory_uid` matches.
  Cities don't count.
- **Decided (user, 2026-09-28): territories are mandatory for building. There is no legacy mode.**
  - The default test config (`raw_config` in `tests/lib/test_case.gd`) gets
    `starting.territory: "homeland"`, a TEST_CARDS territory with 5 slots and no keywords.
  - `test_new_game_setup`'s tableau assertion changes from `["capital"]` to `["homeland", "capital"]`.
    This edit to an approved test is pre-approved by the user.
  - A Capital with no territory can't hold buildings ("No territory with a free slot.").
- **UI:**
  - each territory group shows used/total slots
  - a building with several valid territories uses the targeting flow from 003

## Test plan
| AC | Test |
|---|---|

## Manual check
- [ ] Slot counts show on each territory. A full territory isn't highlighted as a target.

## Log
