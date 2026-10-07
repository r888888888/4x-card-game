---
id: 392
title: Move main.gd's test hooks into a test-side probe
type: chore
status: done
branch: feat/392-main-probe
---

## Goal
`ui/main.gd` is the most-edited UI script (127 commits since 2026-09-01; split twice already, 052 and 176). About a
quarter of it (lines ~181–285) is 19 methods that only tests call: `## Test hook` methods such as `event_modal()`,
`raid_modal_verdict()` and `menu_buttons()`, plus top-bar passthroughs like `counter()`. Each UI item that tests a new
modal or control adds another one, so `main.gd` grows with the test suite rather than with the game. After this item
those methods live on the test side, and a check keeps new ones from coming back.

## Acceptance criteria
- [x] AC1: Given `ui/main.gd`, when the suite runs, then a test fails naming each method in it whose doc comment says
  `Test hook`, and each public method that no script under `ui/`, `sim/`, `engine/` or `autoload/` calls (only
  `tests/` do). Lifecycle and signal callbacks (`_ready`, `_input`, …) and `quit_hook` don't count.
- [x] AC2: These 19 methods are gone from `main.gd` and live in `tests/lib/main_probe.gd`, each taking `main` as its
  first argument with the same return value: `board_shown`, `hand_view_count`, `game_over_text`, `event_panel`,
  `relieve_button`, `restore_order_button`, `event_modal`, `event_modal_ok_button`, `event_option_buttons`,
  `raid_modal`, `raid_modal_verdict`, `raid_modal_ok_button`, `section_headings`, `menu_buttons`, `locked_tip`,
  `game_over_buttons`, `counter`, `forecast_text`, `counter_text`. Example: `main.event_modal()` becomes
  `MainProbe.event_modal(main)`.
- [x] AC3: Given the probe, when it reads one of main's components, then it reads a public member of `main` or of the
  component (no `_` names, the rule CLAUDE.md sets for the engine). The components the hooks reached through `_`
  names (`_board`, `_game_over`, `_relief`, `_restore`, `_news`, `_menu`, `_top_bar`, `_play_area`) become public vars on
  `main`, documented like the existing ones.
- [x] AC4: `main.gd` loses at least 90 lines (434 before this item).
- [x] AC5: No test changes behaviour: every test passes with the same count plus AC1's new checks, and the only edits
  to existing tests are the call-site renames from AC2 (about 220 of them).

## Out of scope
- Test hooks on other components (`card_details_modal.gd` has 12, `identity_modal.gd` 7, …). A hook on its own
  component reads that component's own state and grows with it, so it's fine where it is. Only main, the hub, gets
  hooks for other components.
- `pending_kind`, `views_in` and `log_note`: `ui/` scripts call them, so they stay.
- Splitting main.gd further.

## Design notes
- `MainProbe` is a `RefCounted` of static functions in `tests/lib/`, preloaded as a const in `test_case.gd` so every
  test file can call `MainProbe.x(main)` without its own preload. Each function's `##` doc keeps the hook's backlog
  ids (`(079)`, `(389)`, …).
- The AC1 check belongs in `tests/test_ui_structure.gd` (it already checks `ui/` structure). Finding callers can be a
  text search for `.name(` outside `ui/main.gd` and `tests/`, like `helper_checks.gd` does for test helpers.
- The renames are mechanical: `main\.name\(\)` → `MainProbe.name(main)` and `main\.name\(` → `MainProbe.name(main, `.
  A few tests may name main something else; grep for each hook name, not just `main.`.
- New convention for `docs/testing.md` (helper section) and the `tdd` skill: a UI test that needs to reach a control
  inside one of main's components adds a probe function, not a method on main. Add the row for `tests/lib/main_probe.gd`
  to `docs/testing.md`'s helper table.
- Merge order: every open UI branch that calls `main.event_modal()` etc. will fail after this merges; the fix is the
  same rename. Say so in the merge commit.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_ui_structure::test_main_has_no_test_hooks` (fails naming the 21 methods) |
| AC2, AC3 | the renamed call sites in the existing tests (`MainProbe.x(main)`), which must keep passing |
| AC4 | the line count, checked by hand at the end (434 before) |
| AC5 | the whole suite: same count plus the new check |

## Log
- 2026-10-07: specced from the review of the scripts that keep hitting the size limit (after 391).
- 2026-10-07: red. The check finds 21 methods, not 19: `build_ceremonies` (357) and `background_box` (183, 341) are
  `Test hook`s too, so they move with the rest (AC1 governs). Finding callers is a text search for `.name(`, which
  can't tell main's `forecast_text` from `Counter.forecast_text()` that `top_bar.gd` calls; so a script that defines a
  method of the same name doesn't count as a caller.
- 2026-10-07: green (2479 + 1 = 2480, no other test changed beyond the renames). 232 call sites renamed (230 `main.`,
  2 `m.` in `play_seed_1` callbacks; `main.supply.counter(` is SupplyScreen's own and stays). `main.gd` 434 → 318 lines.
  The probe is preloaded as `MainProbe` in `test_case.gd` (no `class_name`, so it stays out of the game's namespace).
  main's own two `board_shown()` calls read `board.visible`. The public components sit in main's documented block.
- Merge note: open branches calling `main.event_modal()` etc. (379's and 384's red tests among them) need the same
  rename: `main.x(` → `MainProbe.x(main, `.
