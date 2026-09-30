---
id: 063
title: Start screen (new game and options)
type: feature
status: in-progress
branch: feat/063-start-screen
---

## Goal
The game opens on a start screen instead of dropping straight into a game (TODO 17). From there you start a new game
(with an optional seed) or change options. 064 adds the civilization picker to it.

## Acceptance criteria
<!-- UI smoke test (045) where possible. -->
- [ ] AC1: On launch the start screen shows the title, a "New game" button, a seed field (empty means random) and the
  Reduce motion toggle. No game has started: the engine has no turn yet, and the board is hidden.
- [ ] AC2: Pressing New game with the seed field at "42" starts a game with seed 42 and hides the start screen. With
  the field empty or not a whole number, it starts a game with a random seed.
- [ ] AC3: The Reduce motion toggle on the start screen and the one in the menu both show the same `Settings` value,
  and it is saved as today (018).
- [ ] AC4: The in-game menu's "New game" returns to the start screen, and the current game is abandoned. "Restart"
  keeps its behavior (the same seed, straight into play). The game-over overlay's replay behaves as today.
- [ ] AC5: Keyboard: New game has the focus when the start screen opens, Enter starts the game, and Tab reaches the
  seed field and the toggle.

## Out of scope
- Civilization choice (064), save/load, difficulty settings.

## Design notes
- After 052: a `ui/start_screen.gd` component. `Game.new_game(seed)` is unchanged. `main.gd` just doesn't call it
  until New game is pressed.
- The UI smoke test's `play_seed_1` starts the game directly (not through the screen), so it stays unchanged.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_start_screen::test_launch_shows_the_start_screen_and_starts_no_game`, `::test_start_screen_has_title_new_game_seed_field_and_motion_toggle` |
| AC2 | `test_start_screen::test_new_game_with_seed_42_starts_that_seed`, `::test_new_game_with_an_empty_or_bad_seed_uses_a_random_seed` |
| AC3 | `test_start_screen::test_start_screen_and_menu_toggles_share_the_setting` |
| AC4 | `test_start_screen::test_menu_new_game_returns_to_the_start_screen`, `::test_menu_restart_replays_the_seed_without_the_start_screen`, `::test_game_over_replay_starts_straight_away` |
| AC5 | `test_start_screen::test_new_game_has_the_focus_and_enter_starts`, `::test_tab_reaches_the_seed_field_and_the_toggle` |

## Manual check
- [ ] The screen looks intentional at the default window size and when resized.
- [ ] Menu → New game → start screen → New game works repeatedly without leftover cards on the board.

## Log
