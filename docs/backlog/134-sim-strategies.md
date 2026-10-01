---
id: 134
title: The balance sim plays several strategies, per civilization
type: feature
status: in-progress
branch: feat/134-sim-strategies
---

## Goal
`scripts/sim.sh` plays one fixed policy (ScriptedBot) as the default civilization only, and that bot never grows
pop: over 100 turns it always ends at the same cities and pop (55 / 57), so the sim can't tell whether growth,
wealth, going wide or going tall pays off, nor how the civilizations compare. After this item the sim plays a set of
named strategies as every listed civilization and reports each, so a balance change shows which play styles it helps
or hurts.

## Acceptance criteria
- [ ] AC1: `ScriptedBot.STRATEGIES` is `["baseline", "growth", "wealth", "wide", "tall"]`. `ScriptedBot.play(engine)`
  plays "baseline", which is today's bot: for the same seed and data, `play(e)` and `play(e2, "baseline")` end with
  the same score, resources and tableau. An unknown strategy name plays nothing and returns false.
- [ ] AC2 (growth, safe): Given a strategy other than baseline, a settled territory with housing room and enough food
  to grow, when the bot is done playing cards for the turn, then it grows, one pop at a time, while the next upkeep
  would still feed everyone (`upkeep_forecast().starve` stays 0) — e.g. Homeland at 1 pop, 10 food, nobody's food
  upkeep: it grows to its housing. "baseline" never grows (pop stays at 1).
- [ ] AC3 (growth): the growth strategy plays a card whose upkeep makes food before other playable cards (Farm before
  Shrine in the same hand), and grows the territory with the lowest grow cost first.
- [ ] AC4 (wealth): the wealth strategy plays a card that makes wealth (on play or upkeep) before other playable
  cards, and after its plays buys the cheapest affordable open supply card that makes wealth, once a turn.
- [ ] AC5 (wide vs tall): the wide strategy plays a card that explores or settles before other playable cards and grows
  the lowest-pop territory first. The tall strategy never plays a settling card once it has 2 settled territories, plays
  food-upkeep cards first, and grows the territory with the most housing first.
- [ ] AC6 (report): `SimStats.run(cards, config, seeds, strategy := "baseline", civ := "")` plays each game with that
  strategy as that civilization (`new_game(seed, civ)`; "" is the default). `scripts/sim.sh [seeds] [strategy]` with no
  strategy prints, for each strategy, the mean score per listed civilization and the strategy's mean of every metric
  over all civilizations; with a strategy, the current one-table output for it. The balance skill still works on it.

## Out of scope
- Smart play (lookahead, choosing explore options, which tech to buy beyond today's cheapest-affordable rule).
- Changing `test_content`'s 20-seed smoke sweep: it keeps the baseline bot.
- New metrics beyond today's seven.

## Design notes
- Strategies are priorities, not card ids: "makes food on upkeep", "makes wealth", "explores or settles" are read from
  card effects (`op` / `resource` / `trigger`), so the bots follow content changes. sim/ never names a card.
- Safe growth uses `engine.fork()`: grow on a fork, keep it only if the fork's `upkeep_forecast().starve` is 0.
- `scripts/sim.sh` gains an optional second argument; `sim/run.gd` passes it through. Running every strategy for every
  civilization is 5 × 6 × seeds games, so the default stays at 20 seeds; say how long it takes in the balance skill.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_sim_strategies::test_bot_strategies_are_named`, `test_baseline_is_the_default_bot`, `test_unknown_strategy_plays_nothing` |
| AC2 | `test_strategies_grow_to_housing_when_nobody_eats`, `test_strategies_stop_growing_before_the_next_upkeep_would_starve` |
| AC3 | `test_growth_plays_food_upkeep_cards_first`, `test_growth_grows_the_cheapest_territory_first` |
| AC4 | `test_wealth_plays_wealth_cards_first`, `test_wealth_buys_the_cheapest_wealth_card_once_a_turn` |
| AC5 | `test_wide_plays_explore_and_settle_cards_first`, `test_wide_grows_the_lowest_pop_territory_first`, `test_tall_stops_settling_at_two_territories`, `test_tall_plays_food_cards_first_and_grows_the_roomiest_territory` |
| AC6 | `test_sim_stats_runs_a_strategy`, `test_sim_stats_plays_as_a_civilization`, `test_sim_run_files_reports_every_strategy_and_civilization` |

## Manual check
- [ ] `scripts/sim.sh` prints a block per strategy with a score per civilization; `scripts/sim.sh 20 baseline`
  matches the old output on `main`.
- [ ] The strategies differ in a sensible way on the real data (wide founds more cities than tall; growth ends with
  more pop than baseline; wealth buys more).

## Log
- Requested during 132/133: "try different strategies (maximizing growth, maximizing wealth, focusing on expansion
  versus focusing on a few high growth territories)".
- Red: tests drive the bot one turn at a time with a new `ScriptedBot.take_turn(engine, strategy)` (everything a turn
  does except discarding and ending it). `SimStats.run_files` keeps "baseline" as its default (the existing one-table
  test stays); `scripts/sim.sh` passes "all" when no strategy is given.
- Green: two approved tests miscounted turn 1's upkeep (it runs in new_game); with the user's OK their starting food
  changed (starve test 10 -> 9, tall test 2 -> 0), assertions unchanged. A strategy whose first-choice territory
  can't grow (too expensive, or the next upkeep would starve) grows its next choice instead (user confirmed).
