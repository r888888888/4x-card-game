---
id: 125
title: Split the effect hooks and internals out of GameEngine
type: feature
status: review
branch: feat/125-split-game-engine
---

## Goal
`engine/game_engine.gd` is 694 lines, 6 below the 700-line hard limit. The action economy (127, 128, 129) and the
civilization items (108–110) all add queries to it, so the next one breaks the suite. The file does two jobs: it's
the player-facing facade (actions, their `*_error` queries, read queries) and the host that effects and modules
call back into (`gain`, `lose`, `draw`, `create_card`, `trash`, `add_score`, … and the `_` internals). The split
follows that boundary. No behavior changes.

## Acceptance criteria
- [x] AC1: A new `engine/engine_core.gd` (`class_name EngineCore`, `extends RefCounted`) holds the state the
  modules share: the signals, the `state` var and its property accessors (`resources`, `turn`, `zones`, …),
  `card_db`, `config`, `play_target`, `_outcome`, the "Helpers called by effects" section, and the internals
  `_resolve`, `_make_card`, `_log` and `_notice`. `GameEngine` `extends EngineCore`.
- [x] AC2: `GameEngine` keeps every public action, `*_error` query and read query, `fork()`, the constants
  (`FOOD`, `WEALTH`, `ZONES`, `ALWAYS_ON_ZONES`, `PENDING_*`, `TECH_*`, …) and `_blocked_error` (it reads
  `pending()`). Every caller (effects, modules, `ui/`, `sim/`, tests) still types and calls `GameEngine` unchanged.
- [x] AC3: Every existing test passes unedited.
- [x] AC4: `scripts/sim.sh 20` output is identical before and after.
- [x] AC5: Both files are at most 500 lines (no `WARN` for either in `scripts/test.sh`). `PLAN.md`'s layout and the
  class comment at the top of `game_engine.gd` name `engine_core.gd`.

## Out of scope
- New behavior, including the action economy's queries (127).
- Moving the delegating queries into their modules' callers (the facade stays the one public API).

## Design notes
- If a moved function needs a constant that must stay in `GameEngine` (for example `_blocked_error` and
  `PENDING_*`), it stays in `GameEngine` rather than duplicating the constant. Check early that a subclass
  constant reference such as `GameEngine.FOOD` still resolves for code that only sees `EngineCore`; if a moved
  helper needs one, move that constant to `EngineCore` and keep `GameEngine.FOOD` working through inheritance.
- Commit the move as one step so the diff reads as a move.
- 108's design note ("game_engine.gd is at 675/700") is superseded by this item.

## Test plan
| AC | Test |
|---|---|
| AC1–2 | checked by `grep -n "^func\|^const\|^signal\|^var" engine/engine_core.gd engine/game_engine.gd` |
| AC3 | the existing suite, unedited (822 tests, 0 failures) |
| AC4 | `scripts/sim.sh 20` diffed against `main`: identical |
| AC5 | `wc -l` (game_engine.gd 500, engine_core.gd 204), no `WARN` for either in `scripts/test.sh` |

## Log
- `FOOD` and `WEALTH` moved to `EngineCore` too (AC2 listed them under `GameEngine`): they describe the state, and
  `GameEngine.FOOD` still resolves through inheritance, so no caller changed. The other constants stay.
- `_resolve` in `EngineCore` calls `Territories.territory_of` directly, since `territory_of` is a `GameEngine` query.
- The delegating hooks (`lose_pop`, `explore`, `settle`, `add_pop`, `add_era`) pass `self` from `EngineCore` to
  modules typed `GameEngine`; Godot accepts it (every engine is a `GameEngine` at run time).
- `game_engine.gd` lands at exactly 500 lines, so 127's queries will bring back the `WARN` (not a failure; 200 lines
  below the hard limit).
