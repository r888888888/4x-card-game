---
id: 035
title: Show next turn's food and wealth change in the top bar
type: feature
status: done
branch: feat/035-upkeep-forecast
---

## Goal
The player sees, next to Food and Wealth in the top bar, how much each will change at the next
upkeep ("Food: 3 (+1)  Wealth: 5 (+2)"), so they can plan plays, growth and buys without adding up
every card by hand, and see a coming starvation before it happens.

## Acceptance criteria
<!-- Setup unless stated: TEST_CARDS, population {start 2, food_upkeep 1, vp_per_pop 0}; Capital makes
+2 food at upkeep, Farm +1 food, Stall +1 wealth, Granary +1 pop here. Homeland housing is 7. -->
- [x] AC1: Given Capital, and Farm and Stall on Homeland with 2 pop, when `upkeep_forecast()` is
  called, then it returns `{food: 1, wealth: 1, starve: 0}` (2 + 1 made, 2 eaten; 1 wealth made).
  Resources, pop, score, log lines and zones are unchanged, and `changed` is not emitted.
- [x] AC2: Given Farm then Stall on Homeland with 1 pop (Stall idle), when forecast, then
  `{food: 2, wealth: 0, starve: 0}`: idle buildings don't count (2 + 1 made, 1 eaten).
- [x] AC3: Given Granary on Homeland with 2 pop, when forecast, then food is -1 (2 made, 3 eaten after
  Granary adds a pop). With Homeland at its housing (7 pop) instead, food is -5 (2 made, 7 eaten: no pop
  is added).
- [x] AC4: Given food_upkeep 2, Capital, 2 pop and 0 food on hand, when forecast, then
  `{food: -2, wealth: 0, starve: 2}` (2 made, 4 needed, 2 short → 2 pop would starve). With 1 food on
  hand, starve is 1 and food is still -2.
- [x] AC5: Given population rules off (no population block), Capital and a Farm, when forecast, then
  food is +3 (production only) and starve is 0.
- [x] AC6: Given the forecast from AC1, when the player ends the turn, then food and wealth on hand
  change by exactly the forecast's food and wealth, clamped so food doesn't go below 0. On the last
  turn (turn == turn_limit) or after game over, `upkeep_forecast()` returns `{}`.

## Out of scope
- Era unlocks, draws or other non-resource effects at upkeep.
- Forecasting VP/score from upkeep `score` effects.
- A breakdown of where the numbers come from (tooltip listing each card).

## Design notes
- New engine query `upkeep_forecast() -> Dictionary` `{food, wealth, starve}` (one key per config
  resource, plus `starve`). It must predict exactly what `_start_turn` does to resources: same working
  cards (non-idle tableau + researched techs), same effect resolution (keywords, gain_per_tag, grow
  capped by housing), then the pop-eating step. Food is net of what pop eats and may be negative;
  `starve` is how many pop the shortfall would kill.
- Likely approach: run the upkeep steps against a snapshot (resources, territory pop, bonus_score) with
  logging and the outcome off, then restore. Sharing the upkeep code with `_start_turn` keeps the two
  from drifting.
- UI: `_refresh` shows "Food: 3 (+1)" / "Wealth: 5 (+0)"; the food label turns a warning color when
  `starve > 0`. Hidden on the last turn and after game over (forecast is `{}`).

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_forecast::test_forecast_is_production_minus_upkeep`, `test_forecast_changes_nothing` |
| AC2 | `test_forecast::test_forecast_skips_idle_buildings` |
| AC3 | `test_forecast::test_forecast_counts_pop_grown_at_upkeep`, `test_forecast_no_growth_at_housing_cap` |
| AC4 | `test_forecast::test_forecast_starve_with_no_food`, `test_forecast_starve_with_some_food` |
| AC5 | `test_forecast::test_forecast_without_population_is_production` |
| AC6 | `test_forecast::test_forecast_matches_next_upkeep`, `test_forecast_shortfall_matches_next_upkeep`, `test_forecast_empty_on_last_turn`, `test_forecast_empty_after_game_over` |

## Manual check
- [ ] New game: top bar reads "Food: 2 (+0)  Wealth: 1 (+1)" on turn 1 (Capital +2 food +1 wealth, 2 pop eat 2).
- [ ] Play a Farm on your territory: food forecast goes up by 1 at once (+2 on a Flood Plain).
- [ ] Hover Food / Wealth: tooltip explains the bracketed number.
- [ ] Grow pop until food can't feed it: the food stat turns red and its tooltip says how many pop will starve.
- [ ] On turn 20 the brackets disappear.

## Log
- `upkeep_forecast` shares `_resolve_upkeep()` with `_start_turn` and snapshots resources, bonus score and
  territory pop; `_quiet` suppresses logging. Only resources/score/pop-changing ops (gain, gain_per_tag, grow,
  score) are used at upkeep today; an upkeep op that moves cards (draw, create, explore) would need adding to the
  snapshot.
