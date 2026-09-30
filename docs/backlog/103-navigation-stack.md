---
id: 103
title: Navigation stack for screens (Back and Esc in one place)
type: feature
status: red-review
branch: feat/103-navigation-stack
---

## Goal
Every screen and modal handles Back, Esc, focus restore and "close on new game" its own way today (`main._input`,
`CardFocus.handle_key`, each modal's `_input`, `_menu_return`, `_hide_screens`, `_screen_open`). Add one small
navigation stack in `ui/`, the master–detail pattern: opening a screen pushes it and hides the one below, Back or
Esc pops it and gives the focus back to what had it. Move the title, new game and settings screens onto it (no
behaviour change), so the territory view (101) and later detail screens are one push each.

## Acceptance criteria
<!-- Unit tests of the Navigator on plain Controls (tests/test_navigator.gd), then the real main scene. -->
- [ ] AC1: Push. Given a navigator whose root is screen A (shown), when screen B is pushed, then B is shown, A is
  hidden, `top()` is B and `depth()` is 2. Pushing C on top hides B; `depth()` is 3.
- [ ] AC2: Back. `back()` hides the top screen, shows the one below and returns true. At the root (depth 1) or when
  empty, `back()` returns false and shows or hides nothing.
- [ ] AC3: Focus. `push(B, focus)` gives `focus` (a Control on B) the keyboard focus. `back()` gives the focus back
  to the Control that had it when B was pushed, if that Control is still in the tree and visible; otherwise no
  Control has the focus.
- [ ] AC4: Esc. `handle_key(event)` with an Esc press (not an echo, not a release) calls `back()` and returns true when
  `depth()` > 1; at the root, and for any other key, it returns false and changes nothing.
- [ ] AC5: Reset. `set_root(R)` hides every screen on the stack and leaves `[R]`, shown; `clear()` hides every screen
  and leaves the stack empty. The navigator emits `changed` once after each push, back, set_root and clear.
- [ ] AC6: The start screens use it. In the real main scene, `main.nav.top()` is the title screen's overlay on launch,
  the new game screen's after New game (title or menu), and the settings screen's after Settings; it is empty while
  a game is on the board. Every `test_start_screen` test passes unchanged.

## Out of scope
- Moving the menu, card details, Knowledge, Buy Cards and the event modal onto the stack. They move when an item
  next touches them (say so in their item's Log).
- Transitions or animation between screens.

## Design notes
- `ui/navigator.gd`: `class_name Navigator extends RefCounted`; `push(screen: Control, focus: Control = null)`,
  `back() -> bool`, `set_root(screen, focus = null)`, `clear()`, `top() -> Control`, `depth() -> int`,
  `handle_key(event: InputEvent) -> bool`, `signal changed`. It knows nothing about the game.
- `main.gd` keeps `var nav: Navigator`; `_input` asks `nav.handle_key` where it checks the start screens today, and
  `_hide_screens` / `_screen_open` go (`nav.depth() > 0` while a start screen is open). This should also bring
  `main.gd` down from 669 lines, making room for 101.
- 101 then pushes the territory view over the Realm section (the Realm as the root while a game is on).
- Add `Navigator` to `test_ui_structure`'s COMPONENTS.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_navigator::test_push_shows_the_new_screen_and_hides_the_one_below` |
| AC2 | `test_back_returns_to_the_screen_below`, `test_back_at_the_root_or_empty_does_nothing` |
| AC3 | `test_push_focuses_the_given_control_and_back_gives_the_focus_back`, `test_back_leaves_no_focus_when_the_old_focus_is_gone` |
| AC4 | `test_esc_goes_back_above_the_root_only` |
| AC5 | `test_set_root_and_clear_reset_the_stack`, `test_changed_is_emitted_once_per_step` |
| AC6 | `test_the_start_screens_are_on_the_navigator`; all of `test_start_screen` unchanged; `test_ui_structure` lists `Navigator` |

## Manual check
- [ ] Run `godot --path .`: title → New game → Back → Settings → Back → New game → Start behave exactly as before,
  with Esc going back from the new game and settings screens.

## Log
- 2026-09-30: Specced after the user asked for a pattern for detail screens (before 101). The user chose to build it
  first; 101's red tests wait on its branch.
