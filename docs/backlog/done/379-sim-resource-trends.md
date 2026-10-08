---
id: 379
title: Sim report shows food and wealth held every 10 turns
type: feature
status: done
branch: feat/379-sim-resource-trends
---

## Goal
A balance report shows how the bot's food and wealth stockpiles grow over a game, not just how the game ends.
Resources carry over with no cap, and raids grow with the hoard (374), so knowing when the bot starts hoarding (and
whether a change makes it hoard sooner) matters for tuning. Today the sim reports only end-of-game totals and what
raids took. After this, `scripts/sim.sh` prints a `food by turn` and a `wealth by turn` line per block, sampled every
10 turns, and `--compare` shows how each sample moved.

## Acceptance criteria
- [x] AC1: Given a config with turn limit 25, when `SimStats.metric_names` lists the metrics, then it ends (after the
  tier metrics) with `food_t10`, `food_t20`, `wealth_t10`, `wealth_t20`. With turn limit 100 it has `food_t10` …
  `food_t100` then `wealth_t10` … `wealth_t100` (10 each). With turn limit 9 it has none. The step is
  `SimStats.TREND_EVERY` (10). `--turns` changes the turn limit, so the samples too.
- [x] AC2: Given a fixture game on `TEST_CARDS` with 10 Caravans (free: +2 food per city) and turn limit 20, starting
  with 2 food and 3 wealth and only the Capital (⟳ +2 food), when `play_game` plays it, then `food_t10` and
  `food_t20` are the food held when turns 10 and 20 start (after that turn's upkeep, before the bot plays anything
  that turn), and `wealth_t10` and `wealth_t20` are 3. The test states the arithmetic, and it differs from the food
  held when those turns end.
- [x] AC3: Given trend means `{food_t10: 12.0, food_t20: 22.5}` (and other metrics), when `SimStats.trend_line("food",
  means)` builds the line, then it is `food by turn: 10 12.0, 20 22.5` (turns in order, means to 1 decimal). Given
  no `food_t<n>` metric, it is "".
- [x] AC4: Given a run (`SimStats.run_files`) of one strategy on fixture data with turn limit 20, when it reports,
  then after its metric lines come `food by turn: …` and `wealth by turn: …`, and no `food_t10`-style metric line.
  With strategy `all`, each strategy's block ends with its own two lines, over all its civilizations' games. With turn
  limit under 10, neither line prints.
- [x] AC5: Given two sides' trend means for a strategy, when `SimCompare.trend_change_line("wealth", main, this)` builds
  the comparison line, then it is `wealth by turn  Δ 10 +0.0, 20 -2.5` (every sample both sides have, signed, 1
  decimal) when any sample moved, and "" when none did. `--compare` prints it per strategy in place of a line per
  `wealth_t<n>` metric (and the same for food).

## Out of scope
- Other resources (insight, unrest), income per turn (`upkeep_forecast`), and per-civilization trend lines.
- A settable step (`--every n`): the step is a constant until someone needs another.
- Min/max per sample: the trend lines show means; the cached games keep every value if that's wanted later.
- Bot changes: the bot plays the same, only the report grows.

## Design notes
- `sim/sim_stats.gd`: `TREND_EVERY := 10`, `TREND_RESOURCES := [GameEngine.FOOD, GameEngine.WEALTH]`.
  `metric_names` appends `<resource>_t<n>` for each resource, then each n in `TREND_EVERY, 2×…` up to
  `config.turn_limit`. `play_game`'s `on_state` already sees each turn as it starts (the first `changed` with the new
  turn number, after `TurnLoop.start_turn`'s upkeep, feeding, raids and event): it records `engine.resources` there
  for the sampled turns.
- `trend_line(resource, means) -> String` is public and pure, so it is tested without a run. `run_files` drops the
  trend metrics from `_metric_lines` and appends the two lines per block.
- `sim/sim_compare.gd`: `trend_change_line(resource, main_means, this_means) -> String`; `_report` skips
  `<resource>_t<n>` in its per-metric loop and appends the trend lines.
- The metric names change the sim's source hash, so cached games replay once (292). Comparing against a `main` without
  this item: `--compare` reports only metrics both sides have, so the trend lines show once it merges.
- `.claude/skills/balance/SKILL.md`: add the trend metrics to its metric list and the lines to what the report shows.
- `docs/testing.md` is at its size cap: put the tests in existing sim test files.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_sim::test_379_metric_names_end_with_food_then_wealth_every_10_turns` |
| AC2 | `test_sim::test_379_a_game_samples_what_is_held_as_each_10th_turn_starts` |
| AC3 | `test_sim::test_379_trend_line_lists_each_sample_mean_by_turn` |
| AC4 | `test_sim::test_379_a_run_ends_each_block_with_the_trend_lines` (one strategy, `--turns` 10 and 9), `test_379_with_every_strategy_each_block_ends_with_its_trend_lines` |
| AC5 | `test_sim_compare::test_379_trend_change_line_shows_each_sample_moved` |

## Manual check
- [ ] User-run: `scripts/sim.sh --level 1` ends with the `food by turn` and `wealth by turn` lines, and the numbers
  look plausible next to `raid_food_lost` / `raid_wealth_lost`.

## Log
- Spec: the user chose the stockpile held (not income) and a fixed 10-turn step. The sample is taken when the turn
  starts, so it is what the turn's raids already took and what the bot has to spend.
- Red: the fixture game (10 Caravans, Capital) was checked first: the bot plays all 5 Caravans every turn, so food
  when turn n starts is 2 + 2n + 10(n − 1). Developed on the session branch `claude/zealous-hawking-irkils` (the cloud
  session's designated branch) in place of `feat/379-sim-resource-trends`.
- Green: `play_game` samples in `on_state`'s new-turn branch (turn 1 is called by hand; later turns on the first
  `changed` after `TurnLoop.start_turn`). `SimStats.trend_turns` and `is_trend_metric` are shared with `SimCompare`, so
  both reports drop the per-sample lines the same way. The balance skill and `scripts/sim.sh`'s header describe the
  lines.
- Follow-up (not this item's): `tests/balance/test_sim_reports.gd`'s `METRICS` still lists `cities`, renamed
  `settlements` by 328, so `test_sim_run_files_prints_one_line_per_metric` should fail in the balance suite already.
