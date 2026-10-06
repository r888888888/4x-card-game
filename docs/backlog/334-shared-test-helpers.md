---
id: 334
title: Share the UI test helpers that are copied across files, and split the two meanings of click
type: chore
status: review
branch: feat/334-shared-test-helpers
---

## Goal
The UI tests copy the same helpers file to file: `shown_button` is identical in 6 files, `wait_seconds` in 6,
`open_game` in 5 (two variants). Worse, `click` means three things: in `test_territory_view.gd:13` and
`test_territory_cards.gd:18` it emits `details_requested` (no click at all), while `test_knowledge_screen.gd:163`,
`test_identity_cards.gd:21` and `test_era_sheet.gd:45` send a real mouse press. The shared ones move to
`tests/lib/test_case.gd`, so later items add tests on one set of helpers.

## Acceptance criteria
- [x] AC1: `tests/lib/test_case.gd` holds `shown_button(root, prefix)`, `wait_seconds(s)` and one `open_game` covering
  today's variants (1920×1080 with the window size restored on close; the Sfx clock frozen when asked); no file under
  `tests/` other than `tests/lib/` defines a function with those names.
- [x] AC2: `test_case.gd` holds `click_control(main, control, button := MOUSE_BUTTON_LEFT)` (a real press and release at
  the control's centre) and `click_point(main, at, button := MOUSE_BUTTON_LEFT)`; the details-emitting helper is named
  `open_details(main, uid)`; no test file defines `click(`.
- [x] AC3: Given the test files, when the suite runs, then a test fails naming any function defined in two or more
  test files whose name is also defined in `tests/lib/` (a local copy of a shared helper).
- [x] AC4: Behaviour is unchanged: every test passes with only its helper calls renamed, and the test count is
  unchanged.
- [x] AC5: CLAUDE.md's Test conventions add: "A helper a second test file needs moves to `tests/lib/` (the suite
  checks copies of shared helpers)."

## Out of scope
- Table-driving the loader-validation tests (`load_x` and its variants).
- Helpers with the same name that differ on purpose and aren't shared (`snapshot`, `assert_refused`).

## Design notes
- AC3 replaces `scan.sh`'s "Helpers in test files that already exist in tests/lib/" section; it also catches today's
  `choice_engine` in `test_ui_queries.gd` and `hills_of` in `test_training.gd` / `test_unit_moves.gd`, which go.

## Test plan
| AC | Test |
|---|---|
| AC1, AC2 | `test_shared_helpers::test_test_case_defines_the_shared_ui_helpers`, `test_definitions_names_the_files_that_define_a_function`, `test_no_test_file_defines_a_shared_ui_helper_or_click` |
| AC1 | `test_open_game_starts_seed_1_and_close_game_frees_main`, `test_open_game_big_is_1920_by_1080_and_close_game_restores_the_window`, `test_open_game_freezes_the_sound_clock_when_asked` |
| AC2 | `test_click_control_presses_and_releases_at_the_controls_centre`, `test_click_point_presses_and_releases_at_a_point`, `test_open_details_sends_a_cards_details_requested` |
| AC3 | `test_copies_names_a_lib_helper_defined_in_two_test_files`, `test_no_test_file_copies_a_shared_helper` |
| AC4 | the full suite green; test count unchanged apart from these 11 |
| AC5 | doc wording |

## Log
- 2026-10-06: specced from the project review.
- 2026-10-06: built. `test_case.gd` gained `open_game(big, freeze_sfx)` / `close_game`, `shown_button`, `wait_seconds`,
  `click_control`, `click_point`, `open_details` and `hills_of` (from `raid_case.gd`; the copies in `test_training.gd`
  and `test_unit_moves.gd` went). The check is `tests/lib/helper_checks.gd` (`copies`, `definitions`); it replaces
  scan.sh's "Helpers in test files that already exist in tests/lib/" section.
- Beyond the listed copies: the 4 real-press `click_at` helpers (test_modal_stack, test_log_drawer, test_vellum,
  test_supply_screen) are `click_point` now (`test_log_drawer`'s pushed without local coordinates; its tests pass
  either way). `test_modal_sheets` closes with `close_game`, so it now puts the window size back. The three identical
  `forecast(main, key)` wrappers (333's follow-up) became direct `main.forecast_text(key)` calls.
  `test_ui_queries.gd`'s `choice_engine` (a different helper with anarchy_case's name) went: it uses test_case's
  `explore_engine()`, which opens the same choice.
- AC3 as written flags a lib name defined in 2+ test files, so a single local copy (the design note's `choice_engine`)
  isn't caught; it was removed by hand.
- Test count: 2182 → 2193 (the 11 new tests); no test removed.
- Follow-up: more big-window helpers under other names keep their own `_old_window_size` (test_board_layout,
  test_button_widths, test_modal_stack, test_sidebar, test_title_screen); they could use `open_game(true)` /
  `close_game`. Other names copied across 3+ test files and not in lib (`entry`, `card_messages`, `tokens`,
  `open_home`, `levy_of`, `shown_label`, `face_of`, `era_engine`, `step_tweens`, `focus_owner`) were left (some differ).
  docs/testing.md sits at its 25 KB cap: the next helper row needs room made.
