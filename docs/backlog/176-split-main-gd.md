---
id: 176
title: Split main.gd along the view-sync and layout boundaries
type: feature
status: review
branch: feat/176-split-main-gd
---

## Goal
`ui/main.gd` is at 694 of its 700 allowed lines, so the next UI change that touches it fails the suite. Its view
syncing and its layout building are separate jobs and move to their own scripts, leaving room for 155's and the
military items' UI. From the 2026-10-01 project review.

## Acceptance criteria
- [x] AC1: Syncing card views with the engine (`_refresh`'s placing, `_place`, `_remove_view`, `_leave_point`,
  `_new_slot`, `_free_slot`, `_reset_views`) lives in its own component (e.g. `ui/board_views.gd`, `BoardViews`), and
  building the layout (`_build_layout`) in another; `test_ui_structure` requires both and that `main.gd` uses them.
- [x] AC2: `main.gd` is under 500 lines (no `WARN` line from `scripts/test.sh`).
- [x] AC3: `zone_of(uid)` returns the name of the zone holding card uid, or "" when none does. `_leave_point` and
  `TableauView.leading_zone` use it instead of looking in zones themselves. Given a card in `trashed`, `zone_of` is
  "trashed"; given an unknown uid, "".
- [x] AC4: `main`'s public fields and test hooks (`views`, `tableau`, `drag`, `focus`, `modals`, `relieve_button()`, …)
  keep working, and every existing test passes unedited.

## Design notes
- Follows 175, so no rule moves while the code moves.
- `game_engine.gd` (583) and `config_loader.gd` (532) stay as they are: past the warning but not near the limit.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_ui_structure::test_each_ui_component_has_its_own_script` / `test_main_uses_each_component` (`BoardViews` in `ui/board_views.gd`, `BoardLayout` in `ui/board_layout.gd` added to `COMPONENTS`) |
| AC2 | `test_ui_structure::test_main_is_under_the_soft_limit` |
| AC3 | `test_ui_queries::test_zone_of_names_the_zone_holding_a_card`, `test_ui_structure::test_the_ui_asks_the_engine_which_zone_holds_a_card` |
| AC4 | Every existing test unedited (main's hooks: test_board_row, test_territory_view, test_modal_stack, …) |

## Manual check
- [ ] Seed 1: dealing, playing onto a territory, a card flying to the Log button, a trashed card leaving, opening and
  closing a territory view and an explore choice all animate as before (and with Reduce motion).

## Log
- 2026-10-01: Specced from the project review.
- 2026-10-01: Red. Names: `BoardViews` (`ui/board_views.gd`) and `BoardLayout` (`ui/board_layout.gd`); `zone_of(uid) ->
  String` on `GameEngine`. AC2 is a test of its own (main.gd at most 500 lines, counted as `wc -l` does), so the
  limit holds after the WARN line scrolls by.
- 2026-10-01: Green. `BoardViews` (193 lines) owns `views`, the last outcome and the quiet flag; main's `views` is a
  property reading it, so every hook works as before. `BoardLayout` (131 lines) builds the board, the hand, the effects
  layer and the components, wiring them to main through public methods plus the three private callables it is
  given (restart, close the menu, open the new game screen); main keeps the theme and background (test_theme and
  test_ui_structure require main.gd to build its theme with GameTheme and Palette). `_on_clicked` and
  `_on_drag_requested` became `on_clicked` / `on_drag_requested`, as BoardViews connects them. main.gd: 696 → 444
  lines. `zone_of` also replaced 175's zone lookups in `on_picked`.
- Follow-up: `engine/game_engine.gd` is at 618 lines (583 before 172–176 added `pending()`'s work, `_owed_error`,
  `hand_input_error`, `hand_limit`, `research_on`, `zone_of`); still under 700, past the 500 warning.
