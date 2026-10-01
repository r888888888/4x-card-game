---
id: 012
title: Workers gate buildings
type: feature
status: done
branch: feat/012-workers-gate-buildings
---

## Goal
Pop is the labor that works buildings. A territory can hold only as many working buildings as it has
pop, so slots limit space and pop limits labor. Depends on 009.

## Acceptance criteria
- [x] AC1: Given population on, Homeland (5 slots) with pop 1 and 1 Farm on it, then a Farm in hand has
  no valid target on Homeland, `play_error` is non-empty (no territory with a free worker), and playing it
  changes nothing.
- [x] AC2: Given Homeland with pop 2 and 1 Farm, then a Farm can be placed on Homeland (a free slot and a
  free worker).
- [x] AC3: Given a territory with 3 buildings and pop 2 (for example after starvation), when upkeep
  resolves, then only the 2 buildings placed first (earliest on the tableau) trigger their upkeep effects. The one placed last is idle:
  `is_idle(uid)` is true, it stays on the tableau, and its printed VP still counts in `score()`.
- [x] AC4: Given that territory's pop goes back to 3, then at the next upkeep all 3 buildings trigger and
  none is idle.
- [x] AC5: Idleness is decided by pop when upkeep starts, before pop eats (011). A building that is working
  at the start of upkeep produces that turn even if starvation later in the same upkeep lowers pop.
- [x] AC6: With no `population` block, placement ignores pop and no building is ever idle.

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
| AC1 | `test_workers::test_building_needs_a_free_worker` |
| AC2 | `test_workers::test_building_placed_with_a_free_worker` |
| AC3 | `test_workers::test_newest_buildings_go_idle_when_pop_drops`, `test_cities_never_idle` |
| AC4 | `test_workers::test_idle_buildings_work_again_when_pop_returns` |
| AC5 | `test_workers::test_starvation_during_upkeep_does_not_idle_a_building_that_turn` |
| AC6 | `test_workers::test_without_population_workers_are_ignored` |

## Manual check
Run `godot --path .` (real data: Capital on Grassland, 2 slots, start 2 pop, housing 4).
- [ ] Place 2 buildings on Grassland (e.g. Farms or Pastures). A third building in hand is greyed with
  "No territory with a free worker." if Grassland still had a free slot, or the slot message otherwise.
- [ ] With 2 buildings and 2 pop, let pop starve (spend all food before ending the turn with low production):
  the building placed last turns grey with "Idle: no worker", its tooltip explains why, and it produces nothing
  at the next upkeep.
- [ ] Grow the territory back (Grow button): the Idle marker disappears and the building produces again.

## Log
- 2026-09-28: spec'd with the user. Extra buildings go idle (newest first) instead of being destroyed.
- 2026-09-28 (from 011): "oldest (lowest uid)" doesn't mean placed first, because deck cards get uids at game
  start. Use tableau order (placed first) for which buildings stay working; update AC3 wording at the red checkpoint.
- 2026-09-28: red. 7 failing tests in the new `tests/test_workers.gd` (missing `free_workers` / `is_idle`). AC3 now
  says "placed first" (tableau order); the tests place buildings in reverse uid order so the two orders differ.
  The error text is "No territory with a free worker." `is_idle` reflects current pop (so after starvation the
  newest building shows idle at once), but upkeep uses the pop from before eating.
- 2026-09-28: green. Upkeep takes the working (non-idle) cards before resolving any effect, so later pop changes
  in the same upkeep (starvation, or 013's Granary) don't change who works that turn.
- Follow-up: `play_error(uid, target)` with a target that has a slot but no free worker says "That target isn't
  valid." (the generic target message). A worker-specific message there would help drag-and-drop.
