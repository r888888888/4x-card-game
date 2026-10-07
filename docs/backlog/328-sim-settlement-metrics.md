---
id: 328
title: Sim report names settlements and counts them by tier
type: feature
status: review
branch: feat/328-sim-settlement-metrics
---

## Goal
A balance report should say plainly how many settlements a strategy founds and how big they grow. Today the
count is there, but labelled `cities`, which doesn't read as settlements. Nothing shows whether a strategy builds many
hamlets or a few metropolises, and that is what tells wide and tall apart.

## Acceptance criteria
- [x] AC1: Given any sim data, when `SimStats.metric_names` lists the metrics, then it has `settlements` where
  `cities` was (same position, after `score`), and no `cities`.
- [x] AC2: Given a fixture game that starts with the Capital on its home territory and settles 2 more territories with
  Settlers, when it ends, then its metrics have `settlements` 2. This is the same count `cities` gave, the starting
  ones not counted. A game that settles none has `settlements` 0.
- [x] AC3: Given a config with population on and tiers `[hamlet 0, village 4, town 8]`, when `metric_names` lists
  the metrics, then it adds `tier_hamlet`, `tier_village`, `tier_town`, in the config's order. With tiers off (no
  `tiers` key) or population off, it adds no `tier_*` metric.
- [x] AC4: Given that config and a fixture game that ends with 3 settled territories at pop 2, 5 and 9, when it ends,
  then its metrics have `tier_hamlet` 1, `tier_village` 1, `tier_town` 1. Every settled territory counts, the home one
  included, so the `tier_*` values add up to the number of settled territories. A tier no territory reached is 0.
- [x] AC5: Given a run (`run_files`) with tiers on, when it reports, then it prints a `settlements` line and a line per
  `tier_*` metric with mean, min and max, like every other metric. `--compare` lists them under a strategy when their
  mean moved.

## Out of scope
- Mapping `cities` to `settlements` when comparing against a `main` that predates this item. Until it merges, a
  `--compare` against such a `main` just leaves the line out, since it only reports metrics both sides have.
- Tiers at any time other than game end, and a per-civ breakdown.

## Design notes
- `sim/sim_stats.gd`: `METRICS` renames `cities` → `settlements`. `metric_names` adds `tier_<id>` per
  `config.population.tiers` entry (only when population is on and tiers are set), as it already does for
  `<gov>_turns` and `era_<n>_*`. `game_metrics` counts settled territories per tier with `Population.tier` and
  `Territories.count_settled`, or iterates the tableau's territories.
- Renaming changes the sim's source hash, so cached games replay once (292). That is expected.
- Update `.claude/skills/balance/SKILL.md`: its metric list (`cities` → `settlements`, add `tier_<id>`), and while
  there, the strategy list (the sim now plays `generic`, `wide`, `tall`, not the five it names).
- `tests/test_sim.gd`'s `METRICS` constant changes from `cities` to `settlements`.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_sim::test_328_metric_names_have_settlements_where_cities_was`, `test_sim_stats_reports_mean_min_max_per_metric` (renamed key) |
| AC2 | `test_sim::test_328_territories_settled_with_settlers_count_as_settlements`, `test_sim_stats_counts_founded_settlements` (renamed) |
| AC3 | `test_sim::test_328_metric_names_add_a_tier_metric_per_config_tier_in_order`, `test_328_no_tier_metrics_with_tiers_or_population_off` |
| AC4 | `test_sim::test_328_every_settled_territory_counts_in_its_tier` |
| AC5 | `test_sim::test_328_a_run_reports_settlements_and_each_tier` (`--compare` takes its metrics from `metric_names`, so it needs no test of its own) |

## Manual check
- When you next run a balance comparison (manual: `/balance`), check that each strategy's block has a `settlements`
  line and, since `data/config.json` has tiers, a `tier_<id>` line per tier. The first run after this item replays
  every game once (the source hash changed, 292). Against a `main` from before 328, `--compare` leaves out
  `settlements` and the tier lines (see Out of scope).

## Log
- 2026-10-06: from a 20-seed run on main (generic 9.5 settlements a game, wide 11.8, tall exactly 1). The user asked
  for settlements in every future balance report.
- 2026-10-06: built. `SimStats._tiers` reads `config.population.tiers` ([] with population off, an empty dict).
  AC2's test settles with Pioneer, the fixture card that settles a territory (Settler only creates a city). The
  balance skill's metric and strategy lists are updated (`generic`, `wide`, `tall`; game count and time scaled to 3
  strategies, an estimate). The AC3 "off" test passed at red (nothing added tier metrics yet); it stays as a guard.
