---
id: 051
title: GameState and engine modules; forecast on a copy
type: feature
status: draft
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
  `game_engine.gd` is 400 lines or fewer.

## Out of scope
- Undo and save/load themselves.
- Allowing more ops on upkeep (043's guard stays).

## Test plan
| AC | Test |
|---|---|

## Log
