---
id: 347
title: Explain a build refused for want of a free worker
type: feature
status: in-progress
branch: feat/347-explain-no-free-worker
---

## Goal
With population on, a building or unit needs a free worker (pop not yet working a building or unit) on its
territory. When a territory has room but no free worker, the Build modal's row for it (and a drop on it) reads only
"That target isn't valid.", and a card with no territory to go on reads "No territory with a free worker." Neither
says what a worker is. After this the refusal is a short "No free worker." everywhere, and a tooltip (the Build
modal's row, the hand card) gives the full explanation.

## Acceptance criteria
- [ ] AC1: Given a building and a settled territory Homeland with a free slot, pop 2 and 2 buildings on it (no free
  worker), when the building is played or built on Homeland, then the error is "No free worker." and
  `play_error_detail` / `build_error_detail` is "Each building and unit needs a worker: one pop on its territory.
  Homeland's pop is all at work."
- [ ] AC2: Given a unit and a settled territory Grassland at pop 0, when it is played on Grassland, then the error is
  "No free worker." and the detail ends "Grassland has no pop yet."
- [ ] AC3: Given a territory renamed Memphis, then the detail names Memphis (`shown_name`).
- [ ] AC4: Given no territory the card could go on for want of a worker (no target given), then the error is "No free
  worker." and the detail ends "Every territory's pop is at work."
- [ ] AC5: Given a legal play or build, or any other refusal (a territory with no free slot still reads "That target
  isn't valid."), then the detail is "".
- [ ] AC6: Given the Build modal on a territory with no free worker, then a building's row reads "No free worker." and
  its tooltip is `build_error_detail`; given a hand card refused for want of a worker, its tooltip holds the reason and
  `play_error_detail`.

## Out of scope
- The no-free-slot case's wording (follow-up item if wanted).
- How to get more pop (growth cards, housing).

## Design notes
- New engine API: `play_error_detail(uid, target_uid := -1) -> String` and
  `build_error_detail(card_id, territory_uid := -1) -> String`: a longer explanation of the refusal, "" when there is
  none beyond the error (only "No free worker." has one for now).
- The Build modal sets its row's tooltip to the detail; the hand card's tooltip adds it after the error.
- Existing expectations that change: `test_units::test_unit_refuses_invalid_targets` ("no free worker" case), and the
  "No territory with a free worker." asserts in `test_units` and `test_workers`.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_workers::test_no_free_worker_on_the_target_is_short_with_a_detail` |
| AC2 | `test_units::test_unit_refuses_invalid_targets` |
| AC3 | `test_workers::test_the_detail_names_the_city_name` |
| AC4 | `test_workers::test_with_no_territory_free_the_detail_says_every_pop_is_at_work`; `test_workers::test_building_needs_a_free_worker`; `test_units::test_unit_uses_a_worker_on_its_home` |
| AC5 | `test_workers::test_other_refusals_and_legal_plays_have_no_detail` |
| AC6 | `test_build_modal::test_a_row_refused_for_want_of_a_worker_explains_in_its_tooltip`; `test_build_modal::test_a_hand_card_with_no_free_worker_explains_in_its_tooltip` |

## Manual check
- [ ] Fill a territory's workers (build until its pop is all at work, with a slot left), open its view and Build…:
  each building's row reads the new message.

## Log
- Red review: the user asked for a short "No free worker." with the full explanation in a tooltip.
