---
id: 249
title: Split GameEngine's read queries into EngineQueries
type: feature
status: red-review
branch: feat/249-split-engine-queries
---

## Goal
`engine/game_engine.gd` is at 699 lines, and 161's two defence queries take it past the 700-line limit the suite
enforces. GameEngine is a facade of read queries (~450 lines) and player actions with their `*_error` queries
(~250). Split it along that seam, with no behavior change, so engine work can keep adding queries.

## Acceptance criteria
- [ ] AC1: `engine/engine_queries.gd` declares `class_name EngineQueries` and extends `EngineCore`; `GameEngine` extends
  `EngineQueries`. Every method GameEngine had stays callable on a `GameEngine` with the same signature.
- [ ] AC2: The read queries (the methods under `# --- Queries ---` today: `turn_limit` through `supply_error`) are
  declared in `engine_queries.gd` and not in `game_engine.gd`; `game_engine.gd` keeps `fork`, the actions with their
  `*_error` queries, and the internals.
- [ ] AC3: Neither file reaches 500 lines (no `WARN` from the script-size test).

## Out of scope
- Any behavior change, renaming a method, or moving logic into or out of the rules modules.
- 161's defence queries: they land in `EngineQueries` when 161 resumes on top of this.

## Design notes
- Chain: `EngineCore` → `EngineQueries` → `GameEngine`. The queries only read state and call the modules, so they
  need nothing from GameEngine; where one calls an action-side method, it stays reachable through `self`.
- `fork()` returns a `GameEngine`, so it stays in `game_engine.gd`.
- Tests and UI keep typing engines as `GameEngine`.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_engine_structure::test_game_engine_extends_engine_queries_which_extends_engine_core`, `test_every_query_and_action_is_still_on_a_game_engine` |
| AC2 | `test_engine_structure::test_queries_are_declared_in_engine_queries_only` |
| AC3 | `test_engine_structure::test_both_files_are_under_the_soft_limit` |

## Log
