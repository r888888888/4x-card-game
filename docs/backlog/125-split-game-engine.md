---
id: 125
title: Split the effect hooks and internals out of GameEngine
type: feature
status: ready
branch: feat/125-split-game-engine
---

## Goal
`engine/game_engine.gd` is 694 lines, 6 below the 700-line hard limit. The action economy (127, 128, 129) and the
civilization items (108–110) all add queries to it, so the next one breaks the suite. The file does two jobs: it's
the player-facing facade (actions, their `*_error` queries, read queries) and the host that effects and modules
call back into (`gain`, `lose`, `draw`, `create_card`, `trash`, `add_score`, … and the `_` internals). The split
follows that boundary. No behavior changes.

## Acceptance criteria
- [ ] AC1: A new `engine/engine_core.gd` (`class_name EngineCore`, `extends RefCounted`) holds the state the
  modules share: the signals, the `state` var and its property accessors (`resources`, `turn`, `zones`, …),
  `card_db`, `config`, `play_target`, `_outcome`, the "Helpers called by effects" section, and the internals
  `_resolve`, `_make_card`, `_log` and `_notice`. `GameEngine` `extends EngineCore`.
- [ ] AC2: `GameEngine` keeps every public action, `*_error` query and read query, `fork()`, the constants
  (`FOOD`, `WEALTH`, `ZONES`, `ALWAYS_ON_ZONES`, `PENDING_*`, `TECH_*`, …) and `_blocked_error` (it reads
  `pending()`). Every caller (effects, modules, `ui/`, `sim/`, tests) still types and calls `GameEngine` unchanged.
- [ ] AC3: Every existing test passes unedited.
- [ ] AC4: `scripts/sim.sh 20` output is identical before and after.
- [ ] AC5: Both files are at most 500 lines (no `WARN` for either in `scripts/test.sh`). `PLAN.md`'s layout and the
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

## Log
