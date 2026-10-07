---
id: 394
title: Engine areas, first one: military actions and queries move to engine.military
type: chore
status: done
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
- [x] AC1: Given any engine, when `engine.military` is read, then it offers these methods with the same arguments and
  results as the `GameEngine` methods they replace:
  `move_error` / `move` (was `move_unit_error` / `move_unit`), `move_targets`, `move_block` (`unit_move_block`),
  `strength` (`unit_strength`), `veterancy` (`unit_veterancy`), `strength_tag` (`unit_strength_tag`), `realm_size`,
  `raid_turns_left`, `raid_strength`, `plunder_pct` (`raid_plunder_pct`), `disband_error` / `disband`,
  `upgrade_error` / `upgrade` (`upgrade_unit_error` / `upgrade_unit`), `origin` (`unit_origin`), `upgrade_line`,
  `upgrade_cost`, `raid_target`, `raid_forecast`, `outcome_text` (`raid_outcome_text`), `raid_line`, `raid_tag`,
  `raid_short`, `defense`, `defense_parts`, `raid_warning`. The existing military tests, renamed to call these, pass.
- [x] AC2: The 27 old names are gone from `GameEngine`, `EngineQueries` and `TerritoryQueries`
  (`has_method` is false for each), and no script in `engine/`, `ui/`, `sim/` or `tests/` calls them.
- [x] AC3: Given a `TEST_CARDS` game with a unit that can move and one that can upgrade, when `legal_actions()` runs,
  then it lists the move, the upgrade and the disband, `LegalActions.error` returns "" for each, and the bot's
  dispatch applies each (the unit is stationed on the target; the unit is the upgraded card; the unit is gone). Given
  the unit already moved this turn, then the move is not listed.
- [x] AC4: Given a game, when `fork()` and `sample_fork()` copy it, then the copy's `engine.military` acts on the
  copy, not the original: moving a unit on the fork leaves the original's unit where it was.
- [x] AC5: An area holds no game state: `engine.military` declares no script variables but its reference back to
  the engine, and freeing an engine frees its area (no reference cycle; checked with a `WeakRef` to the area going
  null once the engine's last reference is dropped).
- [x] AC6: Given `engine/game_engine.gd`, `engine_queries.gd` and `territory_queries.gd`, when the suite runs, then a
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
- **Action dispatch (AC3).** `LegalActions.error` and `GenericBot._do` call actions by name with `callv` on the
  engine (`["move_unit", uid, t]`, error query `entry[0] + "_error"`). Entries for area actions need a target: e.g.
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
| AC1 | `test_military_area::test_the_military_area_offers_the_moved_methods`; the existing military tests, renamed at green |
| AC2 | `test_military_area::test_the_old_names_are_gone_and_nothing_calls_them` |
| AC3 | `test_legal_actions::test_the_military_areas_actions_are_listed_checked_and_applied`, `test_the_bot_calls_actions_through_legal_actions`; updated: `test_units_and_sites_list_their_moves_contributions_disbands_and_abandons`, `test_166_an_upgradable_unit_lists_its_upgrade`, the coverage table and `test_every_action_with_an_error_query_has_a_coverage_row` (area actions as `military.<action>`) |
| AC4 | `test_military_area::test_a_forks_area_acts_on_the_fork` (fork and sample_fork) |
| AC5 | `test_military_area::test_an_area_holds_no_state_and_goes_with_its_engine` |
| AC6 | `test_engine_structure::test_no_engine_method_forwards_to_an_area` |

## Manual check
- [ ] `scripts/sim.sh --level 1` matches main (`--compare <main checkout>`), as the bot's moves now go through the
  area dispatch. Balance runs are manual: run it, or ask for it.

## Log
- 2026-10-07: specced from the review of the scripts that keep hitting the size limit (after 391). The user chose
  areas, moved one per item, over one big rename, a freeze, or skipping it. Named `military` rather than `units`
  since it holds raids and defence too, and matches the `Military` module.
- 2026-10-07: red. Decisions: an area action's legal entry is `["military.move", uid, t]`; `LegalActions.apply(e,
  entry)` is the one resolver (`LegalActions.error` resolves the error query the same way), and `GenericBot._do` calls
  it (checked by a source test: no `callv` in the bot). The existing military tests keep their old calls until green,
  where the ~150 renames land with the removal (renaming them now would only turn them into parse errors). The guard
  finds areas as GameEngine properties typed as a class named after them (`military: Military`), so later areas are
  covered without editing it. In the existing coverage test, the table's rows become `military.move`,
  `military.upgrade`, `military.disband`, and the expected list adds each Military method with an `_error` twin.
- 2026-10-07: green (2489, 0 failures). `Military` is the area: a `RefCounted` built in `GameEngine._init`
  (`military = Military.new(self)`), so `fork()` and `sample_fork()`, which build a new engine, get their own. Choice
  for AC5: the area is stored and holds a `WeakRef` to its engine (one script variable), rather than built per access,
  so the bot's hot loop makes no allocation per call; each method opens with `var e := _engine()`, which is why
  `military.gd` grew 483 → 534 lines (WARN past 500; the raid half is the boundary if it nears 700). Only the pure
  helpers (`is_raid`, `_when`) stay static. Renames per AC1 (`unit_strength` → `strength`, `unit_origin` → `origin`);
  `defense` moved over from `TerritoryQueries`. The 27 forwards are gone: `game_engine.gd` 497 → 420,
  `engine_queries.gd` 495 → 446, `territory_queries.gd` 216 → 201. Call sites renamed across 30 files (the other
  modules' `Military.x(e, …)` became `e.military.x(…)`). `LegalActions.apply` and `LegalActions.error` share one
  resolver (`_call`), and `GenericBot._do` and the tests' `play_first_legal` call `apply`. `military.move` sits beside
  `move_error` in `military.gd` now (`test_blocking` checks an area's actions beside their queries in its own file).
  Existing tests changed beyond the renames: `test_blocking`'s table rows and its two action-table tests learn area
  actions (`military.<action>`), and `play_first_legal` skips `military.disband`.
- Recommended order for the next areas (one item each): 1. sites (`contribute`, `abandon`, the site queries: small and
  self-contained, a second example before writing the recipe up as a skill); 2. research and supply (`buy`,
  `buy_tech`, the supply and research queries); 3. government and anarchy, after 385 and 386 settle its actions;
  4. events (choices, take); 5. the territory queries last (the most callers, and `TerritoryQueries` would go with
  them). Write the `add-area` skill after the second.
