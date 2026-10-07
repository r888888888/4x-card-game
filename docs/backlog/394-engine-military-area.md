---
id: 394
title: Engine areas, first one: military actions and queries move to engine.military
type: chore
status: ready
branch: feat/394-engine-military-area
---

## Goal
`GameEngine`'s public API is a chain of facades, `EngineCore` → `TerritoryQueries` → `EngineQueries` → `GameEngine`,
and most of its methods only forward one call to a rules module: 54 of `GameEngine`'s 72, 33 of `EngineQueries`' 78,
30 of `TerritoryQueries`' 37. So every new action adds two forwarding methods to `game_engine.gd` (101 items touched it
since 2026-09-01, +2309 / −1784 lines). Three past splits (125, 249, 281) each added a layer to the chain without
stopping that growth. This item brings in **areas**: an object on the engine per rules area that callers use directly
(`engine.military.move(uid, t)`), so a new action in an area edits only that area's file. It moves the first area,
military (units and raids, 27 forwarding methods); later items move the others one at a time.

## Acceptance criteria
- [ ] AC1: Given any engine, when `engine.military` is read, then it offers these methods with the same arguments and
  results as the `GameEngine` methods they replace:
  `move_error` / `move` (was `move_unit_error` / `move_unit`), `move_targets`, `move_block` (`unit_move_block`),
  `strength` (`unit_strength`), `veterancy` (`unit_veterancy`), `strength_tag` (`unit_strength_tag`), `realm_size`,
  `raid_turns_left`, `raid_strength`, `plunder_pct` (`raid_plunder_pct`), `disband_error` / `disband`,
  `upgrade_error` / `upgrade` (`upgrade_unit_error` / `upgrade_unit`), `origin` (`unit_origin`), `upgrade_line`,
  `upgrade_cost`, `raid_target`, `raid_forecast`, `outcome_text` (`raid_outcome_text`), `raid_line`, `raid_tag`,
  `raid_short`, `defense`, `defense_parts`, `raid_warning`. The existing military tests, renamed to call these, pass.
- [ ] AC2: The 27 old names are gone from `GameEngine`, `EngineQueries` and `TerritoryQueries`
  (`has_method` is false for each), and no script in `engine/`, `ui/`, `sim/` or `tests/` calls them.
- [ ] AC3: Given a `TEST_CARDS` game with a unit that can move and one that can upgrade, when `legal_actions()` runs,
  then it lists the move, the upgrade and the disband, `LegalActions.error` returns "" for each, and GenericBot's
  `_do` applies each (the unit is stationed on the target; the unit is the upgraded card; the unit is gone). Given
  the unit already moved this turn, then the move is not listed.
- [ ] AC4: Given a game, when `fork()` and `sample_fork()` copy it, then the copy's `engine.military` acts on the
  copy, not the original: moving a unit on the fork leaves the original's unit where it was.
- [ ] AC5: An area holds no game state: `engine.military` declares no script variables but its reference back to
  the engine, and freeing an engine frees its area (no reference cycle; checked with a `WeakRef` to the area going
  null once the engine's last reference is dropped).
- [ ] AC6: Given `engine/game_engine.gd`, `engine_queries.gd` and `territory_queries.gd`, when the suite runs, then a
  test fails naming any public method there whose body is a single `return <Area module>.x(self, …)` forward to a
  module that has an area (today, `Military`). That's the guard: once an area exists, its forwards can't creep back.

## Out of scope
- The other areas (sites, government and anarchy, research and supply, the territory queries, events): one item each,
  in the order the Log of this item recommends after building it.
- `unit_station` and `units_at` (queries `EngineQueries` computes itself, not forwards): they move with a later item
  if they belong to the area.
- Any rule change, and the `_blocked_error` action names (`"move_unit"`, `"upgrade_unit"`, …), which stay as they
  are.

## Design notes
- **Shape.** Prefer turning the module into the area rather than adding a forwarding class: `Military` becomes a
  `RefCounted` with instance methods that get the engine from `self`, so there is no layer of one-liners anywhere.
  The other modules' static calls `Military.x(e, …)` (in `card_details`, `turn_loop`, `territories`, `events`) become
  `e.military.x(…)`.
- **No cycle, no state (AC5).** The engine owning the area and the area owning the engine is a `RefCounted` cycle
  and leaks. Options: the area holds a `WeakRef`; or the engine builds the area on access (a property getter
  returning `Military.new(self)`, nothing stored). Building it per access is simplest but runs on every bot call;
  measure it on a fixture loop and decide, and record the choice in the Log. Either way, `fork()` must give the copy
  its own area (AC4).
- **Action dispatch (AC3).** `LegalActions` and `GenericBot.take` call actions by name with `callv` on the engine (`LegalActions.error`, `GenericBot._do`;
  `["move_unit", uid, t]`, error query `entry[0] + "_error"`). Entries for area actions need a target: e.g.
  `["military.move", uid, t]` resolved by splitting on the dot, with the error query `military.move_error`. Keep one
  resolver both use. This is where a missed rename would fail silently, hence AC3's tests.
- **Renames.** About 150 call sites (11 in `ui/`, 8 in `engine/`, about 137 in `tests/`), mechanical per the AC1
  table. Grep each old name with a leading `.`, since tests name engines `e`, `engine`, `g`, ….
- **Docs.** CLAUDE.md's architecture rules: actions still come with an `_error` query, now on their area
  (`engine.military.move_error`); a new action or query in an area goes on the area, never on `GameEngine`. Update
  `game_engine.gd`'s class doc (the chain), PLAN.md's engine layout, the `add-decision` skill if it names the facade,
  and `tests/test_engine_structure.gd`'s header.
- **Sizes after.** About 15 forwards (~90 lines) leave `game_engine.gd`, 9 (~50) leave `engine_queries.gd`, 3 leave
  `territory_queries.gd`. `military.gd` (483 lines) grows only by what the instance form needs; if it nears 700, the
  raid half (raids, plunder, raid text) is the boundary for its own area.
- **Later areas** follow the same recipe; once two have moved, write it up as a skill (`add-area` or a section of
  `add-decision`).

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_units::…`, `test_raids::…`, … (renamed) |

## Manual check
- [ ] `scripts/sim.sh --level 1` matches main (`--compare <main checkout>`), as the bot's moves now go through the
  area dispatch. Balance runs are manual: run it, or ask for it.

## Log
- 2026-10-07: specced from the review of the scripts that keep hitting the size limit (after 391). The user chose
  areas, moved one per item, over one big rename, a freeze, or skipping it. Named `military` rather than `units`
  since it holds raids and defence too, and matches the `Military` module.
