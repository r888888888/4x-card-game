---
id: 150
title: Make working cards and eureka checks scale linearly with the tableau
type: feature
status: review
branch: feat/150-linear-modifiers-and-eurekas
---

## Goal
Simulating games fast enough to iterate on balance. `spike/sim-speed` found two engine hot spots that grow with the
tableau: `Modifiers.working_cards` calls `is_idle` per tableau card, and each call rescans the tableau (quadratic).
Every `play_error` (via `actions_left`), `housing` and upkeep pays for it. Separately, `Research.eureka_met` filters
the whole tableau through a lambda per tech; since 143 put a eureka on every tech, it is most of `tech_cost` and
`tech_tree()`. The spike made both linear/early-exit with byte-identical sim output: a 4-seed all-strategy sim went
57s → 27s on the working cards fix alone, and `tech_cost` 2–6× faster. Nothing the player sees changes.

## Acceptance criteria
- [x] AC1 (behavior kept): Given population on, territories A (pop 1) and B (pop 2) settled, and buildings placed
  in the order A1, B1, A2, B2, B3 (interleaved in the tableau), when the modifiers and upkeep apply, then A1, B1 and B2
  work and A2 and B3 are idle: `is_idle` says so, `modifier()` counts only A1, B1, B2's modifiers, and the upkeep
  forecast counts only their upkeep.
- [x] AC2 (behavior kept): Given population off, then no building is idle and every tableau card's modifiers count.
- [x] AC3 (scaling): Given a tableau of N settled territories, each with pop 1 and one building, when `modifier("actions")`
  is timed (best of 5 runs of 20 calls) at N = 50 and N = 400, then time(400) / time(50) < 16 (linear is ~8, the
  current quadratic ~64).
- [x] AC4 (scaling): Given a tech whose eureka needs 1 Farm and a tableau whose first card is a Farm, when
  `tech_cost` is timed (best of 5 runs of 20 calls) with 50 and with 400 more tableau cards after it, then
  time(400) / time(50) < 3 (the check stops at the count it needs).
- [x] AC5: The existing eureka tests (card and tag eurekas, idle cards counting, the floor at 1) still pass unchanged.

## Out of scope
- `tech_tree()`'s other costs (its per-zone `find_custom` lookups and sort): only the UI calls it once 151 lands.
- `housing` calling `Modifiers.total` per territory, `fork`/`GameState.copy` cost: the next hot spots, not yet worth it.
- Parallel sims (152) and the bot's tech pick (151).

## Design notes
- `working_cards`: one pass over the tableau counting buildings per `territory_uid`; a building is idle when its index
  among its territory's buildings is ≥ that territory's pop (what `is_idle` does via `buildings_on(...).find`). The
  spike's version is in `engine/modifiers.gd` on `spike/sim-speed`.
- `eureka_met`: a plain loop that returns true once the count is reached; no lambda, no array.
- No API or data change. Scaling tests compare ratios, not absolute times, so they hold on any machine; keep N small
  enough that the file runs in well under a second.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_engine_scaling::test_buildings_past_their_territorys_pop_are_idle_when_interleaved` (guard: passes before and after) |
| AC2 | `test_engine_scaling::test_with_population_off_every_building_works` (guard) |
| AC3 | `test_engine_scaling::test_modifiers_scale_linearly_with_the_tableau` |
| AC4 | `test_engine_scaling::test_a_met_eureka_check_does_not_grow_with_the_tableau` |
| AC5 | `test_eurekas` (unchanged) |

## Log
- 2026-10-01: from `spike/sim-speed` (profiling and micro-benchmarks in `sim/spike/`).
- 2026-10-01: the user approved the specs and asked to build and merge 150–152 in one go, so the red checkpoint
  wasn't a separate stop. AC1 and AC2 passed before the change: they are guards for the rewrite. Red: 8× the tableau
  cost 51× the time in `modifier()`, and a met eureka 6.3× in `tech_cost`; both now well under the limits.
- Follow-up candidates from the spike profile: `housing` calls `Modifiers.total` per territory (the growth bot's
  biggest cost), and `tech_tree()`'s per-zone `find_custom` lookups.
