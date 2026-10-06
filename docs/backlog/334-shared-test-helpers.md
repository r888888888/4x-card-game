---
id: 334
title: Share the UI test helpers that are copied across files, and split the two meanings of click
type: chore
status: draft
branch: feat/334-shared-test-helpers
---

## Goal
The UI tests copy the same helpers file to file: `shown_button` is identical in 6 files, `wait_seconds` in 6,
`open_game` in 5 (two variants). Worse, `click` means three things: in `test_territory_view.gd:13` and
`test_territory_cards.gd:18` it emits `details_requested` (no click at all), while `test_knowledge_screen.gd:163`,
`test_identity_cards.gd:21` and `test_era_sheet.gd:45` send a real mouse press. The shared ones move to
`tests/lib/test_case.gd`, so later items add tests on one set of helpers.

## Acceptance criteria
- [ ] AC1: `tests/lib/test_case.gd` holds `shown_button(root, prefix)`, `wait_seconds(s)` and one `open_game` covering
  today's variants (1920×1080 with the window size restored on close; the Sfx clock frozen when asked); no file under
  `tests/` other than `tests/lib/` defines a function with those names.
- [ ] AC2: `test_case.gd` holds `click_control(main, control, button := MOUSE_BUTTON_LEFT)` (a real press and release at
  the control's centre) and `click_point(main, at, button := MOUSE_BUTTON_LEFT)`; the details-emitting helper is named
  `open_details(main, uid)`; no test file defines `click(`.
- [ ] AC3: Given the test files, when the suite runs, then a test fails naming any function defined in two or more
  test files whose name is also defined in `tests/lib/` (a local copy of a shared helper).
- [ ] AC4: Behaviour is unchanged: every test passes with only its helper calls renamed, and the test count is
  unchanged.
- [ ] AC5: CLAUDE.md's Test conventions add: "A helper a second test file needs moves to `tests/lib/` (the suite
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

## Log
- 2026-10-06: specced from the project review.
