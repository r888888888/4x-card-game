---
id: 408
title: Work out the fallen-back cards in one pass, so score() stops dominating bot time
type: feature
status: red-review
branch: feat/408-score-in-one-pass
---

## Goal
The sim is slow, and the profile of GenericBot games on the real data (2026-10-08, seeds 1–3) shows why: `score()` is
31–42% of the bot's time, nearly all of it `Fallback.reason`, called about 70 times per `score()` (1.37M calls in
ten late-game turns). Each call finds the card's territory and works out its tier, and for an upgrade rebuilds its
territory's workers and slots (`Population.is_idle`, 18% on its own), so `score()` grows with the square of the
tableau. Work the fallen-back cards out once per query, as `Modifiers.working_cards` already does for the working
ones (150, 281), and make the sim faster without changing a single result.

Measured: checking a card's tier need before its territory's tier (most cards need none) cut turns 45–55 of seed 1
from 27.1 s to 23.4 s (−13.5%). The one-pass set is estimated at a further 15–25%.

## Acceptance criteria
<!-- No rule changes: every criterion is "the same answer as now". Fixtures as test_building_tiers (TIERS, Chapel →
Sanctum (village) → Cathedral (town), Bell on the Sanctum, Forum (town, 1 VP)) and test_wonder_sites (Colossus, a
project). -->
- [ ] AC1: Given positions covering each cause and none: a building below its tier, an upgrade whose base is idle, an
  upgrade whose base has fallen back, an upgrade two levels up (Bell on a fallen Sanctum), an idle building that is
  not fallen back, tiers off, population off; when `Fallback.fallen_uids(e)` is called, then it holds exactly the
  tableau uids whose `fallen_back_reason(uid)` is non-empty, and each card's `fallen_back_reason` is unchanged.
- [ ] AC2: Given the same positions plus an unfinished site with VP and a card with negative VP, when `score()` and
  `score_breakdown()` are called, then `score()` equals both the sum of the breakdown's amounts and printed VP of every
  tableau and always-on card that is neither fallen back nor an unfinished site, plus bonus score, plus pop ×
  vp_per_pop. An idle card still scores; a fallen-back one doesn't.
- [ ] AC3: Given those positions, when `housing(t)` and `smallest_with_room()` are called for each settled territory,
  then they return what they return now (the fallen-back buildings' housing left out).
- [ ] AC4: `score()`, `score_breakdown()` and `Fallback.fallen_uids()` change nothing: resources, zones, log and
  signals are the same before and after.

## Out of scope
- `fork()` (409) and the forecasts' other costs (`Modifiers.total`, 379's per-step bookkeeping in the UI forecast).
- Why bot turns get about 20 times slower after turn 40: that is the bot doing more work, a GenericBot question.
- Any change to scores, rules or what the bot decides: the sim must play the same games.

## Design notes
- `Fallback.below_tier`: check `need(e, def)` first and return false at −1, before `Population.tier` (the measured
  13.5%).
- `Fallback.fallen_uids(e) -> Dictionary` (uid → true): one pass over the tableau, with each territory's tier read
  once and idle worked out as `working_cards` does; an upgrade is fallen when its base is idle or fallen (the base
  comes before it in the tableau, 300). Consider having `working_cards` and it share that pass.
- Callers that test every tableau card use the set: `ScoreBreakdown.score_rows`, `Population.housing`,
  `smallest_with_room`, `Fallback.fallen_on`. `Fallback.reason` stays for the one-card questions (details, tooltips).
- `score()`: sum directly over the same cards (no `Ledger`, no row dictionaries) and keep `score_breakdown()` for the
  popover; AC2's shared check keeps them from drifting. Recovers 380's +8–20% on `score()`.
- Bench and profiler from the analysis: a scratch GDScript that plays GenericBot to turns 20/40/60 and times queries,
  and a wrapper that times chosen functions (`Prof`); rebuild them in the scratchpad if needed, never in the repo.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_fallen_back_pass::test_the_positions_cover_every_cause`, `test_fallen_uids_is_the_cards_with_a_reason`, `test_fallen_uids_with_tiers_off_holds_only_the_idle_bases_upgrades`, `test_fallen_uids_is_empty_with_population_off` |
| AC2 | `test_score_counts_what_the_rule_counts`, `test_score_in_the_mixed_position` (guards: pass now) |
| AC3 | `test_housing_and_room_count_what_the_rule_counts`, `test_a_fallen_buildings_housing_returns_with_its_tier` (guards: pass now) |
| AC4 | `test_the_queries_change_nothing` |

## Manual check
- [ ] Sim speed against main, same games: `scripts/sim.sh --level 1 --compare <main checkout>`. Every metric should
  match exactly (same decisions), and the run should be faster; the analysis expects 30–40% less bot time late in
  the game.

## Log
- Red: the loader refuses negative VP (`vp` must be ≥ 0), so AC2's "a card with negative VP" is dropped. AC2 and AC3
  are behavior-preserving, so their tests pass already and guard the refactor; AC3 compares with the rule computed card
  by card (territories have a default housing of their own), plus the Hut's housing returning at a Town.
