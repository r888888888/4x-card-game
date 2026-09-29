---
id: 051
title: GameState and engine modules; forecast on a copy
type: feature
status: in-progress
branch: feat/051-game-state-split
---

## Goal
`GameEngine` (928 lines) mixes all state with every subsystem's rules. Pull the state into a `GameState` that can
copy itself and the rules into modules, behind the same public API. The forecast then runs on a copy instead of
a hand-made snapshot, and undo, save/load and bot lookahead become possible.

## Acceptance criteria
- [ ] AC1: `GameState.copy()` is a deep copy: after copying, drawing a card, gaining food and adding pop on the
  copy leaves the original's zones, resources and pop unchanged, and both produce the same next shuffle (the RNG
  state is copied).
- [ ] AC2: `upkeep_forecast()` runs on a copy: given a game where the discard will be reshuffled next turn, an
  engine that called `upkeep_forecast()` 3 times deals the same next hand as one that never did. `_quiet` and the
  manual snapshot are gone.
- [ ] AC3: The public `GameEngine` API is unchanged (`resources`, `zone()`, `turn`, signals, actions, queries),
  and every existing test passes without edits.
- [ ] AC4: The 20-seed sim (042) output is identical before and after.
- [ ] AC5: Population, research/techs, supply and territories each live in their own file under `engine/`, and
  `game_engine.gd` is 500 lines or fewer (raised from 400 at approval: the public API stays on GameEngine as delegators).

## Out of scope
- Undo and save/load themselves.
- Allowing more ops on upkeep (043's guard stays).

## Test plan
| AC | Test (`tests/test_game_state.gd` unless stated) |
|---|---|
| AC1 | `test_changing_a_fork_leaves_the_original_unchanged`, `test_a_fork_starts_equal_to_the_original`, `test_a_fork_shuffles_like_the_original_from_its_own_rng`, `test_a_fork_resolves_a_pending_choice_without_touching_the_original`, `test_game_state_copy_is_independent`, `test_a_fork_emits_and_logs_nothing_on_the_original` |
| AC2 | `test_forecasting_does_not_change_the_next_hand` (a guard: passes before and after); `_quiet` gone checked by grep |
| AC3 | the existing suite, unedited |
| AC4 | `scripts/sim.sh` and a per-seed log + forecast dump (scratch script) diffed against `main` |
| AC5 | checked by `wc -l` and the file list |

## Log
- 2026-09-29: spec approved with these readings: state in `e.state: GameState`; `e.fork()` is a silent GameEngine on
  `state.copy()` (card instances copied, `pending_choice.source` remapped, RNG state copied); the forecast runs on a
  fork; AC4 is a diff, not a suite test; AC5's limit is 500 lines.
