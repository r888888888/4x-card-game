---
id: 176
title: Split main.gd along the view-sync and layout boundaries
type: feature
status: ready
branch: feat/176-split-main-gd
---

## Goal
`ui/main.gd` is at 694 of its 700 allowed lines, so the next UI change that touches it fails the suite. Its view
syncing and its layout building are separate jobs and move to their own scripts, leaving room for 155's and the
military items' UI. From the 2026-10-01 project review.

## Acceptance criteria
- [ ] AC1: Syncing card views with the engine (`_refresh`'s placing, `_place`, `_remove_view`, `_leave_point`,
  `_new_slot`, `_free_slot`, `_reset_views`) lives in its own component (e.g. `ui/board_views.gd`, `BoardViews`), and
  building the layout (`_build_layout`) in another; `test_ui_structure` requires both and that `main.gd` uses them.
- [ ] AC2: `main.gd` is under 500 lines (no `WARN` line from `scripts/test.sh`).
- [ ] AC3: `zone_of(uid)` returns the name of the zone holding card uid, or "" when none does. `_leave_point` and
  `TableauView.leading_zone` use it instead of looking in zones themselves. Given a card in `trashed`, `zone_of` is
  "trashed"; given an unknown uid, "".
- [ ] AC4: `main`'s public fields and test hooks (`views`, `tableau`, `drag`, `focus`, `modals`, `relieve_button()`, …)
  keep working, and every existing test passes unedited.

## Design notes
- Follows 175, so no rule moves while the code moves.
- `game_engine.gd` (583) and `config_loader.gd` (532) stay as they are: past the warning but not near the limit.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|

## Manual check
- [ ] Seed 1: dealing, playing onto a territory, a card flying to the Log button, a trashed card leaving, opening and
  closing a territory view and an explore choice all animate as before (and with Reduce motion).

## Log
- 2026-10-01: Specced from the project review.
