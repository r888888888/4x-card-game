---
id: 299
title: Preview what building an entry on a territory would change
type: feature
status: in-progress
branch: feat/299-build-preview
---

## Goal
The Build modal (297) shows, for the entry you have selected, what building it on this territory would change: food at
the next upkeep, free slots and workers, what you pay, actions left. The UI can't work that out itself (it holds no
rules), so the engine answers it: `build_preview(card_id, territory)` builds the entry on a fork and reports the
differences. Follows 296; 297 uses it.

## Acceptance criteria
- [ ] AC1: Given `build_menu` `{"paddy": {}}` (fixture Paddy: cost 2 food; ⟳ +1 food, +1 more on a flood plain), a
  settled River (fresh water, flood plain) with 2 free slots and 2 free workers, 4 food and 2 actions left, and an upkeep
  forecast of +1 food, when `build_preview("paddy", river)` is asked, then it returns `{"cost": {"food": 2}, "lines":
  [["food", 1, 3], ["free_slots", 2, 1], ["free_workers", 2, 1], ["actions_left", 2, 1]]}`: each line is
  `[key, before, after]`; resource keys compare `upkeep_forecast()` before and on a fork after building; `cost` is
  what `build` would pay (after discounts).
- [ ] AC2: Only what changes is listed, in this order: the resources in config order, then `free_slots`,
  `free_workers`, `defense`, `housing`, `actions_left`. A building that changes no forecast (fixture Well: no effects)
  lists no resource line; a unit lists no `free_slots` line and lists `defense` when its strength raises the
  territory's defence (Warriors, strength 2: `["defense", d, d + 2]`). With unlimited actions (no government) there is
  no `actions_left` line.
- [ ] AC3: When `build_error(card_id, territory)` is not "", `build_preview` returns `{}`. The game itself is untouched
  by a preview: resources, zones, actions used, the log and the RNG state are the same before and after, and no signal
  is emitted (the fork is discarded, as `upkeep_forecast` does).

## Out of scope
- The modal that shows it (297).
- A per-source breakdown of a resource line ("Farm +2, Flood Plain +1"); only before → after.

## Design notes
- New query in `engine/engine_queries.gd` (or beside `build_error` in the build-menu code): `build_preview(card_id:
  String, territory_uid: int) -> Dictionary`. Implementation: `fork()`, `build` on the fork, compare
  `upkeep_forecast()`, `free_slots`, `free_workers`, `defense`, `housing` and `actions_left` before and after. Add it to
  `test_engine_structure`'s query list.
- The keys are fixed strings the UI maps to labels ("Food at next upkeep", "Free slots", …); resource keys are the
  `GameEngine` resource constants.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_build_menu::test_a_preview_lists_the_cost_and_what_building_would_change` |
| AC2 | `test_build_menu::test_a_preview_lists_only_what_changes`; `test_engine_structure` (`build_preview` in the query list) |
| AC3 | `test_build_menu::test_a_refused_preview_is_empty_and_a_preview_changes_nothing` |

## Log
