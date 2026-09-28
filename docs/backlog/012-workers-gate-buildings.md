---
id: 012
title: Workers gate buildings
type: feature
status: ready
branch: feat/012-workers-gate-buildings
---

## Goal
Pop is the labor that works buildings. A territory can hold only as many working buildings as it has
pop, so slots limit space and pop limits labor. Depends on 009.

## Acceptance criteria
- [ ] AC1: Given population on, Homeland (5 slots) with pop 1 and 1 Farm on it, then a Farm in hand has
  no valid target on Homeland, `play_error` is non-empty (no territory with a free worker), and playing it
  changes nothing.
- [ ] AC2: Given Homeland with pop 2 and 1 Farm, then a Farm can be placed on Homeland (a free slot and a
  free worker).
- [ ] AC3: Given a territory with 3 buildings and pop 2 (for example after starvation), when upkeep
  resolves, then only the 2 oldest buildings (lowest uid) trigger their upkeep effects. The newest is idle:
  `is_idle(uid)` is true, it stays on the tableau, and its printed VP still counts in `score()`.
- [ ] AC4: Given that territory's pop goes back to 3, then at the next upkeep all 3 buildings trigger and
  none is idle.
- [ ] AC5: Idleness is decided by pop when upkeep starts, before pop eats (011). A building that is working
  at the start of upkeep produces that turn even if starvation later in the same upkeep lowers pop.
- [ ] AC6: With no `population` block, placement ignores pop and no building is ever idle.

## Out of scope
- Moving workers between buildings by hand (always oldest first).
- Cities: they don't use a worker and always produce.

## Design notes
- Engine API: `is_idle(uid) -> bool`; `free_workers(territory_uid) -> int` (pop − buildings, floored at 0).
  `valid_targets` for a building also requires a free worker when population is on.
- Error when the only problem is workers: "No territory with a free worker." (exact text to be settled in tdd).
- UI: idle buildings are greyed out with an "Idle" marker.

## Test plan
| AC | Test |
|---|---|

## Manual check
- [ ] Idle buildings look inactive and stop producing; they come back when pop grows.
- [ ] Dragging a building onto a territory with no free worker is refused with a clear message.

## Log
- 2026-09-28: spec'd with the user. Extra buildings go idle (newest first) instead of being destroyed.
