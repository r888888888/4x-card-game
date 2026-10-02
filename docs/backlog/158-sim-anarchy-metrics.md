---
id: 158
title: Sim metrics for Anarchy, governments and famine
type: feature
status: red-review
branch: feat/158-sim-anarchy-metrics
---

## Goal
The balance simulator reports how often Anarchy happens, how long it lasts and which governments rule, so unrest and
government changes can be balanced with numbers. From `spike/revolution`.

## Acceptance criteria
- [ ] AC1: `SimStats.METRICS` adds, per game: `anarchies` (times Anarchy began), `revolts` (revolutions declared),
  `anarchy_turns` (turns that started under Anarchy), `restored` (times order was bought), `gov_changes` (times the
  ruling government's id changed, Anarchy not counted), `famine_turns` (turns that started with a Famine) and
  `trashed` (cards in `trashed` at the end).
- [ ] AC2: Per government in config order (any government a card can create, Anarchy excepted), `<id>_turns`: the
  turns that started with it ruling.
- [ ] AC3: Given a fixture game with a known script (one forced Anarchy of 2 turns, then a chosen Kings), the metrics
  are anarchies 1, anarchy_turns 2, gov_changes 1, `kings_turns` = the turns after it.
- [ ] AC4: The metrics come through a parallel run (152) unchanged.

## Design notes
- Tracked from the engine's `changed` and `noticed` signals in `SimStats._play_one`, as `explored` is; no engine
  changes beyond public queries. Counting revolts needs a signal or query the engine offers (not log text).
- Build after 154–155 so the events exist.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_the_new_metrics_and_one_per_government_in_order`, `test_a_revolution_counts_as_a_revolt_and_an_anarchy`, `test_buying_order_counts_as_restored`, `test_trashed_and_famine_turns`, `test_revolting_emits_revolted_once`, `test_restoring_order_emits_order_restored_once`; test_sim: `test_sim_stats_reports_mean_min_max_per_metric` (its metric list) |
| AC2 | `test_the_new_metrics_and_one_per_government_in_order` |
| AC3 | `test_a_forced_anarchy_of_2_turns_then_kings` |
| AC4 | `test_the_metrics_come_through_a_parallel_run` |

## Log
- 2026-10-01: Specced from `spike/revolution` (`sim/sim_stats.gd` at commit d8b7a75 has a working version; the branch is deleted: `git show d8b7a75:sim/sim_stats.gd`).
