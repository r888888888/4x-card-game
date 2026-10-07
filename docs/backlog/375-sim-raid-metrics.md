---
id: 375
title: Sim report counts raids and what they cost, per civilization
type: feature
status: in-progress
branch: feat/375-sim-raid-metrics
---

## Goal
A balance report should show how often the bot is raided, how often it holds, and what raids take from it. Each
civilization starts on different land, and raids aim at terrain (Sea Raiders the coast, Hill Tribes the hills), so
the report breaks raids down by civilization too. Today the sim says nothing about raids. That leaves 374 (raids that
grow with the hoard) and any later raid tuning unmeasured.

## Acceptance criteria
- [ ] AC1: Given any sim data, when `SimStats.metric_names` lists the metrics, then it has, in this order after the
  existing `METRICS` entries: `raids`, `raids_repelled`, `raid_strength_max`, `raid_pop_lost`, `raid_units_lost`,
  `raid_food_lost`, `raid_wealth_lost`.
- [ ] AC2: Given a fixture game in which 3 raids strike (from `raid_resolved`), 1 repelled and 2 pillaged, at
  strengths 2, 3 and 5, when it ends, then its metrics have `raids` 3, `raids_repelled` 1, and `raid_strength_max` 5
  (the outcome's `strength`, so after 374 it is the scaled one).
- [ ] AC3: Given that game, where the two pillages report `pop_lost` 1 and 2, `units_lost` 1 and 0, and `lost`
  `{food: 4}` and `{food: 2, wealth: 3}`, then `raid_pop_lost` 3, `raid_units_lost` 1, `raid_food_lost` 6 and
  `raid_wealth_lost` 3. A repelled raid adds nothing to these, even if its repel effects take something.
- [ ] AC4: Given a game in which no raid strikes (none drawn, or one drawn that fizzles with no target, 372, or one
  still on its way when the game ends), then all seven are 0.
- [ ] AC5: Given a run with strategy `all` and 2+ civilizations, when it reports, then each strategy's block has a
  line `raids by civilization: <civ> <mean raids> (<mean repelled> repelled, <mean pop lost> pop lost), …` after the
  `score by civilization` line, in the same civ order, means to 1 decimal. Example:
  `raids by civilization: sumer 4.0 (1.5 repelled, 2.5 pop lost), egypt 3.0 (3.0 repelled, 0.0 pop lost)`.
- [ ] AC6: Given any run, then the seven metrics also print as ordinary metric lines (mean, min, max), and
  `--compare` lists them under a strategy when their mean moved, like every other metric.

## Out of scope
- Bot changes: the bot plays the same, only the report grows.
- Per-raid-card breakdowns (which raid hit how often), and per-civ lines for the other metrics.
- Mapping the new metrics when comparing against a `main` that predates this item. `--compare` reports only the
  metrics both sides have, so they show up once this merges.

## Design notes
- `sim/sim_stats.gd`: `METRICS` gains the seven names. `play_game` connects `engine.raid_resolved` like `revolted`
  (and disconnects it after) and adds each outcome to the tally: `raids`, `raids_repelled` when `repelled`, the max of
  `strength`; for pillages `pop_lost`, `units_lost.size()` and `lost.food` / `lost.wealth`.
- `run_files`' `all` branch builds the `raids by civilization` line next to the scores line, from the same per-civ
  `values` slice.
- No dependency on 374: `raid_resolved` already reports `strength` and `lost`. Built after 374, it measures the
  scaled strength and plunder. Either order works.
- `tests/test_sim.gd`'s `METRICS` constant grows. 328 renames `cities` in that same constant and in `METRICS`, so
  whichever merges second resolves a small conflict there.
- The new metrics change the sim's source hash, so cached games replay once (292). That is expected.
- `.claude/skills/balance/SKILL.md`: add the raid metrics to its metric list, and the per-civ raids line to what the
  report shows.
- `docs/testing.md` is at its size cap: a new test file means trimming rows there. Prefer adding the tests to
  `tests/test_sim.gd` or an existing sim test file.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_sim::test_375_metric_names_add_the_raid_metrics_after_the_others`, `test_sim_stats_reports_mean_min_max_per_metric` (its `METRICS` grows) |
| AC2, AC3 | `test_sim::test_375_raid_metrics_count_strikes_and_sum_what_pillages_took`, `test_375_a_sim_game_counts_the_raids_that_struck` |
| AC4 | `test_sim::test_375_with_no_raid_struck_the_raid_metrics_are_0`, `test_375_a_sim_game_counts_the_raids_that_struck` (the raid drawn on turn 6 never strikes) |
| AC5 | `test_sim::test_375_raids_by_civilization_line`; `tests/balance/test_sim_reports.gd::test_sim_run_files_reports_every_strategy_and_civilization` (balance, user-run) |
| AC6 | `test_sim::test_375_metric_names_add_the_raid_metrics_after_the_others` (every metric name gets a line and a compare cell) |

## Manual check
- [ ] User-run: `scripts/sim.sh` with strategy `all` prints the raids line per strategy, and the per-civ numbers look
  plausible (coastal civs raided by Sea Raiders more often).

## Log
- Red: AC2/AC3 are tested on `SimStats.raid_metrics(outcomes)`, a pure tally of `raid_resolved` outcomes, since a bot
  game can't be steered into exact pillages; one fixture bot game (Siege, strength 99) checks `play_game` feeds it. The
  per-civ line is `SimStats.raids_by_civilization([[civ, values]])`, so it is tested without a real-data run.
