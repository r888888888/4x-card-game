---
id: 063
title: Start screen (new game and options)
type: feature
status: ready
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
| AC1 | `test_ui_smoke::test_…` |

## Manual check
- [ ] The screen looks intentional at the default window size and when resized.
- [ ] Menu → New game → start screen → New game works repeatedly without leftover cards on the board.

## Log
