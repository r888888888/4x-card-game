---
id: 151
title: Let the bot pick a tech without building the tech tree
type: feature
status: done
branch: feat/151-bot-tech-pick-without-tree
---

## Goal
Faster sims. `ScriptedBot._learn_cheapest_tech` runs on every bot step and calls `tech_tree()`, which builds an entry
for every tech in the config (state, gives, eureka, costs). After 143 one call costs 0.6–1.4 ms late in a game, so it
is a large share of `main`'s sim time. The bot only needs the learnable techs in the research deck and their cost.
`spike/sim-speed` scanned the research deck instead, with the same choice, and got byte-identical sim output.

## Acceptance criteria
- [x] AC1: Given insight 2 and Writing (3), Pottery (2) and Bronze (5) learnable, when the bot takes a turn, then it
  learns Pottery (unchanged from 140).
- [x] AC2 (tie-break): Given two learnable techs that cost the same, one from era 2 listed first in `research_deck`
  and one from era 1 listed after it, when the bot takes a turn with insight for one, then it learns the era 1 tech;
  given two same-cost techs of the same era, it learns the one listed first in `research_deck` (the order `tech_tree()`
  gives, so picks don't change).
- [x] AC3: Given no tech it can afford, or a tech whose prereq isn't researched, then the bot learns nothing and goes on
  to play cards (unchanged).
- [x] AC4 (speed): Given a research deck of 20 learnable techs, when one bot tech pick (with not enough insight to learn
  any) is timed against one `tech_tree()` call (best of 5 runs of 20 calls), then the pick takes less than half as long.

## Out of scope
- Making `tech_tree()` itself faster (the UI calls it rarely).
- Changing which tech the bot prefers.

## Design notes
- Only `sim/bot.gd` changes: loop over `engine.zone("research_deck").cards`, skip ones with a `buy_tech_error`, keep the
  lowest `tech_cost`; ties go to the lower era, then the lower index in `config.research_deck`.
- Builds on 150 (cheaper `tech_cost`), but doesn't depend on it.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_sim::test_bot_learns_the_cheapest_tech_it_can_afford` (existing, unchanged) |
| AC2 | `test_sim::test_bot_breaks_a_cost_tie_by_the_lower_era`, `test_sim::test_bot_breaks_a_cost_tie_in_the_same_era_by_config_order` |
| AC3 | `test_sim::test_bot_learns_nothing_it_cant_afford_or_lacks_the_prereq_for_and_plays_cards` |
| AC4 | `test_sim::test_a_bot_tech_pick_costs_under_half_a_tech_tree` |

## Log
- 2026-10-01: from `spike/sim-speed`.
- 2026-10-01: built with 150 and 152 on the user's go-ahead (no separate red stop). The tie-break tests passed on
  the old code too (guards: `tech_tree()` already ordered by era, then config). Speed: the old pick cost 1.68× a
  `tech_tree()` call. Scanning the deck with `buy_tech_error` per tech still cost 0.63×, because each check recomputes the
  price. Checking the price against insight first, and calling `buy_tech_error` only for affordable techs, brings it to
  about 0.3×. `ScriptedBot.learn_cheapest_tech` is now public (it was `_learn_cheapest_tech`). Sim output identical to
  `main` (`scripts/sim.sh 2`).
