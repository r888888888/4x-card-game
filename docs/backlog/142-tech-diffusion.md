---
id: 142
title: Diffusion: techs of earlier eras get cheaper
type: feature
status: red-review
branch: feat/142-tech-diffusion
---

## Goal
Once the world has moved on, catching up is cheaper: a tech costs 1 Insight less for each era the game has advanced
past it. Skipping a tech to push ahead is a real choice, and leftovers don't stall a player in an old era. This
replaces the old passes. Follows 140; tried on `spike/research-insight`.

## Acceptance criteria
- [ ] AC1: Given an era-1 tech Loom (4 insight) in the research deck, then its `tech_cost` is 4 in era 1, 3 once era
  2 is added and 2 once era 3 is added.
- [ ] AC2: Given an era-2 tech (5 insight) in the research deck once era 2 is added, then its cost is 5 (no
  diffusion in its own era); once era 3 is added, it is 4.
- [ ] AC3: Given Salt (era 1, 4 insight) with a civilization tech discount of 1 and a met eureka of 2, then in era 3
  its cost is max(1, 4 − 1 − 2 − 2) = 1 (never below 1).
- [ ] AC4: A tech whose era hasn't been added keeps its printed cost in `tech_tree()` (no diffusion). A revealed or
  available tech's details list it: `"Costs 2 insight now (printed 4, −2 older era)"`.

## Out of scope
- Diffusion by anything other than era (other civilizations, trade or events teaching techs).
- Pacing: 143.

## Design notes
- `Research.diffusion(def)` = max(0, `era()` − `def.era`), subtracted in `Research.cost` with the civilization
  discount and the eureka, then floored at 1. With 140's hard prereqs, an era-1 tech can still be locked in a later
  era; diffusion lowers its price, not its prereq.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_diffusion::test_an_era_1_tech_costs_1_less_per_later_era` |
| AC2 | `test_diffusion::test_a_tech_has_no_diffusion_in_its_own_era` |
| AC3 | `test_diffusion::test_diffusion_stacks_with_discounts_and_eurekas_but_never_below_1` (passes already: the floor holds) |
| AC4 | `test_diffusion::test_a_future_tech_keeps_its_printed_cost_in_the_tree` (passes already), `test_the_details_list_the_older_era_discount` |

## Manual check
- [ ] `godot --path . -- --seed 5 --turns 30`: once the Bronze Age arrives, an unlearned Stone Age tech's price drops
  by 1 in the tech tree, and its details say "−1 older era".

## Log
