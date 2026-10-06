---
id: 332
title: The upkeep forecast counts a government a declared revolution will have removed
type: bug
status: done
branch: fix/332-forecast-after-revolt
---

## Reproduction
- Seed: any. Real data: rule as Kingship (upkeep +1 wealth), then Revolt.
- Steps (scratch script, 2026-10-06):
  1. `anarchy_case`'s `anarchy_engine()` (Chiefs ruling, unrest on), with Chiefs given an upkeep `gain` of 3 wealth.
  2. `e.revolt()`.
  3. Compare `e.upkeep_forecast().wealth` with `e.turn_forecast().wealth`.
- Expected: both 0: Anarchy falls at the next turn's start *before* upkeep (155), so Chiefs' upkeep never runs.
- Actual: `upkeep_forecast().wealth` is 3, `turn_forecast().wealth` is 0. In the game the top bar shows "Wealth (+1)"
  after revolting under Kingship, and Theocracy's −1 insight per gain still lowers the insight forecast.

`EngineQueries.upkeep_forecast` (`engine/engine_queries.gd:105`) runs `TurnLoop.resolve_upkeep` on a fork without
`Anarchy.before_upkeep`, which `TurnLoop._settle_in` runs first. Size unrest (282) and admin unrest (319) also read the
ruling government, so they are forecast for a government that won't rule.

## Acceptance criteria
- [x] AC1: Given the anarchy fixture game with a ruling government that gains 3 wealth at upkeep and no drain, when a
  revolution is declared, then `upkeep_forecast().wealth` is 0, and after `end_turn()` wealth is unchanged by upkeep.
- [x] AC2: Given a ruling government with the modifier `insight_per_gain: -1` and a working building that gains 2
  insight at upkeep, when a revolution is declared, then `upkeep_forecast().insight` is 2 (it was 1 before the
  revolt).
- [x] AC3: Given a ruling government that tolerates territories up to the first tier and a territory one tier above it
  (1 crowded unrest next upkeep), when a revolution is declared, then `upkeep_forecast().unrest` counts no crowded
  unrest (0 from crowding).
- [x] AC4: Given a revolution declared, when `upkeep_forecast()` runs, then the game is unchanged: the same government
  rules, `revolt_pending` is still true, and the zones, resources and log are as before.
- [x] AC5: Without a revolution, every existing forecast test (`test_forecast`, `test_anarchy_drain`,
  `test_turn_forecast`, …) passes unedited.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_revolution::test_bug_332_forecast_leaves_out_the_upkeep_of_a_government_about_to_fall` |
| AC2 | `test_revolution::test_bug_332_forecast_leaves_out_the_modifiers_of_a_government_about_to_fall` |
| AC3 | `test_size_unrest::test_bug_332_the_forecast_counts_no_size_unrest_after_a_revolt` |
| AC4 | `test_revolution::test_bug_332_forecast_after_a_revolt_changes_nothing` (passes before the fix: a guard) |
| AC5 | the existing forecast tests, unedited |

## Root cause
`upkeep_forecast` ran `TurnLoop.resolve_upkeep` on a fork but skipped `Anarchy.before_upkeep`, which the real turn
start (`TurnLoop._settle_in`) runs first. With a revolution pending the fork still had the old government ruling, so its
upkeep effects, its modifiers and the size and admin unrest it reads were forecast. Fix: the forecast calls
`Anarchy.before_upkeep` on the fork first (`engine/engine_queries.gd`).

## Manual check
- [ ] Rule as Kingship, press Revolt: the top bar's wealth forecast drops Kingship's +1.

## Log
- 2026-10-06: found by the project review; reproduced with a scratch script (+3 vs 0).
- 2026-10-06: built test-first. AC4 passed before the fix (the fork already protects the game); kept as a guard.
  With a revolt pending the forecast now also counts the new Anarchy card's own upkeep (⟳ −1 pop), as the real turn does.
