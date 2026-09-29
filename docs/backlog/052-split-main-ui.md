---
id: 052
title: Split ui/main.gd into components
type: feature
status: review
branch: feat/052-split-main-ui
---

## Goal
`ui/main.gd` is 1,521 lines. After 049 and 050 remove its rules, split what's left into components so UI changes
touch one small file. No visible change.

## Acceptance criteria
- [x] AC1: The supply screen, choice overlays (explore and research), top bar, tableau view, drag controller and
  keyboard focus each live in their own script under `ui/`, and `main.gd` is 500 lines or fewer.
- [x] AC2: The UI smoke test (045) passes unchanged, and no component reads engine state that has an engine query.

## Out of scope
- Any visual or behavior change; scene files for layout (layout stays built in code).

## Test plan
| AC | Tests |
|---|---|
| AC1 | `test_ui_structure::test_main_script_is_at_most_500_lines`, `test_each_ui_component_has_its_own_script`, `test_main_uses_each_component` |
| AC2 | `test_ui_structure::test_ui_scripts_read_no_engine_internals` (a guard: passes already), the unchanged `test_ui_smoke`, `test_menu`, `test_event_panel` |

## Manual check
- [ ] Drag to play, double-click targeting, keyboard play (arrows, Enter, D, E, S, Esc), supply screen buying,
  explore and research choices, hand-limit discard, menu (seed, restart, reduce motion), game over and replay:
  all as before.

## Log
- 2026-09-29: main.gd had grown to 1,562 lines (event panel, menu Exit). Split into `MainScreen` (main.gd, 493 lines:
  card views, refresh, layout, test hooks) plus `TopBar`, `SidePanel`, `TableauView`, `ChoiceOverlays`, `SupplyScreen`,
  `GameMenu`, `GameOverOverlay`, `DragController` (drag and targeting), `CardFocus` (keyboard focus and keys) and
  `UIKit` (shared styles and effects). No behavior change; UI smoke, menu and event panel tests unchanged and green.
- Components that coordinate (DragController, CardFocus) hold the `MainScreen` and use its public members (`views`,
  `tableau`, `choices`, `supply`, `try_play`, …); the rest are self-contained and signal back (SupplyScreen `refused`/`closed`,
  GameMenu `*_requested`).
- Worked in a separate worktree (`../4x-card-game-052`) because main had other sessions' uncommitted backlog edits.
