---
id: 045
title: Headless UI smoke test
type: feature
status: red-review
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
| AC1 | `test_ui_smoke::test_main_scene_follows_a_whole_game_without_errors` |
| AC2 | `test_ui_smoke::test_hand_views_match_the_hand_after_every_turn` |
| AC3 | `test_ui_smoke::test_game_over_overlay_shows_score_and_seed` |
| AC4 | `test_ui_smoke::test_smoke_test_frees_the_scene_and_leaves_settings_alone` |

## Log
- 2026-09-29: Approved by the user ("do 045"). The design note's check doesn't hold under the test runner: during
  `_initialize` the autoloads exist but aren't in the tree, so `Game.engine` is null and an added scene gets no
  `_ready`. Fix: `tests/run_tests.gd` awaits one `process_frame` before running tests (all 373 existing tests
  still pass).
- The tests start the game with `main.start_game(1)` (the existing `_start_game` made public) rather than
  `Game.new_game(1)`: a bare `Game.new_game` keeps the random first game's views, and reused uids would leave
  views showing the wrong cards. Hooks on main: `start_game(seed)`, `hand_view_count()`, `game_over_text()`.
