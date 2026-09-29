---
id: 045
title: Headless UI smoke test
type: feature
status: draft
branch: feat/045-ui-smoke-test
---

## Goal
`ui/` (about 2,100 lines) has no automated coverage. A smoke test that loads the real scene and plays a game
catches script errors in `main.gd` and `card_view.gd` before the UI refactors (049, 050, 052).

## Acceptance criteria
- [ ] AC1: Given `res://ui/main.tscn` added to the scene tree and the real data, when `Game.new_game(1)` runs and
  `ScriptedBot` (042) plays the game to the end through `Game.engine`, then no engine or script error is logged
  (the runner's error collector fails the test otherwise).
- [ ] AC2: After each `end_turn` in that game, the number of hand card views in the main scene equals
  `Game.engine.zone("hand").size()`.
- [ ] AC3: When the game is over, the game-over overlay is visible and its text includes the final `score()` and
  seed 1.
- [ ] AC4: After the test, the main scene is freed, and `user://settings.cfg` was not written (the test never
  changes a setting).

## Out of scope
- Rendering checks, animations, input simulation (drag, keyboard).

## Design notes
- Checked: with `--script`, the `Game` and `Settings` autoloads load, and `main.tscn` instantiates headlessly
  without errors.
- The runner calls tests synchronously, so no frames are processed; `_refresh` runs from the `changed` signal.
  If views only appear after a frame, the test calls the refresh path directly rather than making the runner async.
- Needs a small test hook to count hand views (e.g. a public `hand_view_count()` on main) rather than walking
  private nodes.

## Test plan
| AC | Test |
|---|---|

## Log
