---
id: 347
title: Explain a build refused for want of a free worker
type: feature
status: red-review
branch: feat/347-explain-no-free-worker
---

## Goal
With population on, a building or unit needs a free worker (pop not yet working a building or unit) on its
territory. When a territory has room but no free worker, the Build modal's row for it (and a drop on it) reads only
"That target isn't valid.", and a card with no territory to go on reads "No territory with a free worker." Neither
says what a worker is. After this both say why: the territory's pop is all at work, and a building or unit needs one.

## Acceptance criteria
- [ ] AC1: Given a building and a settled territory named Homeland with a free slot, pop 2 and 2 buildings on it (no
  free worker), when the building is played or built on Homeland, then the error is "Homeland has no free worker: its
  2 pop all work buildings or units, and a building or unit needs one."
- [ ] AC2: Given pop 1 and 1 building, then the error reads "its 1 pop works a building or unit" in place of "its 2
  pop all work buildings or units"; given pop 0, it reads "it has no pop" in its place.
- [ ] AC3: Given a unit and a settled territory with no free worker, when it is recruited or played on it, then the
  error is the same message (a unit takes no slot, so a full territory gives it too).
- [ ] AC4: Given a territory renamed to a city name, then the message names the city name (`shown_name`).
- [ ] AC5: Given no territory the card could go on for want of a worker (no target given), then the error is "No
  territory with a free worker: every pop already works a building or unit."
- [ ] AC6: A territory with no free slot still refuses a building with "That target isn't valid." (unchanged; the
  slot message is out of scope).

## Out of scope
- The no-free-slot case's wording (follow-up item if wanted).
- How to get more pop (growth cards, housing): the message says what is happening, not the remedy.

## Design notes
- Engine only: `CardPlay` (the targeted refusal) and `Territories` (the untargeted one) call one
  `Population.no_worker_error(e, territory_uid)` / shared text. The Build modal and drops already show
  `build_error` / `play_error`.
- Existing expectations that change: `test_units::test_unit_refuses_invalid_targets` ("no free worker" case), and the
  "No territory with a free worker." asserts in `test_units` and `test_workers`.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_workers::test_no_free_worker_on_the_target_says_why` |
| AC2 | `test_workers::test_no_free_worker_with_one_pop_reads_in_the_singular`; pop 0 in `test_units::test_unit_refuses_invalid_targets` |
| AC3 | `test_units::test_unit_refuses_invalid_targets` |
| AC4 | `test_workers::test_no_free_worker_names_the_city_name` |
| AC5 | `test_workers::test_building_needs_a_free_worker`; `test_units::test_unit_uses_a_worker_on_its_home` |
| AC6 | `test_workers::test_a_full_territory_still_refuses_without_the_worker_reason` (passes already: a guard) |

## Manual check
- [ ] Fill a territory's workers (build until its pop is all at work, with a slot left), open its view and Build…:
  each building's row reads the new message.

## Log
