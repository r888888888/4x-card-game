---
id: 067
title: Exit the game from the menu
type: feature
status: done
branch: feat/067-exit-from-menu
---

## Goal
The player can quit the game from the in-game menu. Today the only way out is closing the window, which is awkward
in fullscreen.

## Acceptance criteria
<!-- UI smoke test (045). -->
- [x] AC1: The menu has an "Exit" button, the last button in the menu (after the Reduce motion toggle and Close).
- [x] AC2: Pressing Exit quits the application right away, with no confirmation. In tests, pressing it calls the
  scene's quit hook exactly once and the test process keeps running.
- [x] AC3: Keyboard: with the menu open, Tab or the arrows reach Exit, and Enter on it quits (the same hook as AC2).
- [x] AC4: The game-over overlay is unchanged: it has no Exit button.

## Out of scope
- Confirmation dialog, saving the game before quitting, Exit on the game-over overlay or the start screen (063).
- A fullscreen toggle.

## Design notes
- UI-only; no engine change. `main.gd` gets a quit hook (for example a `quit_requested` callable that defaults to
  `get_tree().quit()`) so the smoke test can swap it and check it was called without ending the test run.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_menu::test_menu_ends_with_an_exit_button` |
| AC2 | `test_menu::test_pressing_exit_calls_the_quit_hook_once` |
| AC3 | `test_menu::test_tab_from_close_reaches_exit_then_wraps_to_the_seed_field`, `test_menu::test_enter_on_exit_calls_the_quit_hook` |
| AC4 | `test_menu::test_game_over_overlay_has_no_exit_button` |

## Manual check
- [ ] `godot --path .`, press Esc (or click "Menu (Esc)"): Exit is the last button, under Close.
- [ ] Click Exit: the game window closes at once, no prompt.
- [ ] Reopen, Esc, then Tab until Exit is highlighted (it wraps back to the seed box after Exit); Enter quits.
- [ ] Same with `godot --path . --fullscreen`.

## Log
- The Exit button calls `quit_hook` (default `get_tree().quit()`); tests swap it. `menu_buttons()` and `game_over_buttons()` are test hooks like `game_over_text()`.
- Built in a separate worktree (`../4x-card-game-067`) because a 068 session was mid-item in the main checkout.
