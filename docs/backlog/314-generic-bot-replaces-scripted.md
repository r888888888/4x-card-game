---
id: 314
title: The generic bot replaces ScriptedBot; strategies generic, wide and tall
type: feature
status: red-review
branch: feat/314-generic-bot-replaces-scripted
---

## Goal
After 313 the sim has two bots, and the scripted one still needs a rule for every mechanic. After this, `GenericBot`
is the only bot: the sim plays `generic`, `wide` and `tall`, revolts and governments are weighed by rollouts the
generic bot plays itself in a cheap mode, it defends against raids because a raid's loss is in its value, and the
per-mechanic bot items (298, 303, 168) are closed as superseded.

## Acceptance criteria
- [ ] AC1: `GenericBot.STRATEGIES` is `["generic", "wide", "tall"]`; `scripts/sim.sh` and `SimStats` play them (all of
  them when no strategy is given) and reject any other name with the current "unknown strategy" message.
- [ ] AC2: tall never settles past 2 territories: given 2 settled territories, a Pioneer in the hand, a frontier
  territory and food to pay, tall doesn't play the Pioneer and generic does. wide adds a weight per settled territory:
  given 1 action, a Pioneer and a Temple where generic plays the Temple, wide plays the Pioneer.
- [ ] AC3: Every `REVOLT_EVERY` (4) turns, outside a rollout and not in the last `ROLLOUT_TURNS` ÷ 2 turns, the bot
  revolts when a rollout that revolts and then chooses some government in the deck outscores one that doesn't
  (159's criteria, ported). When the government choice is owed it chooses by rollout; inside a rollout it chooses by
  value. Rollouts play `ROLLOUT_TURNS` (12) turns on a sample fork in cheap mode (no card values, no extra lookahead
  step) and leave the game untouched.
- [ ] AC4: Given an announced raid that strikes next turn with its target's defence 1 short and a unit stationed on a
  territory no raid targets, the bot moves the unit onto the target before ending its turn; it doesn't move a unit off
  a raided target when that would leave the target short (168's AC1 and AC3, met through `turn_forecast`).
- [ ] AC5: `sim/bot.gd` (`ScriptedBot`) and its tests are gone (`test_bot_lookahead.gd`, `test_bot_spending.gd`, the
  ScriptedBot cases elsewhere); `SimStats` plays `GenericBot`, still reports every metric, and `lookahead_turns` counts
  the rollout turns.
- [ ] AC6: 298, 303 and 168 move to `done/` as `wontfix`, each with a Log line naming this item; the backlog README's
  planned order and `PLAN.md` name `GenericBot` where they named ScriptedBot.

## Out of scope
- Speed (315) and tuning weights (a balance item after 315).
- Building and upgrades: when 295 and 300 land, `build` joins `legal_actions` (312's coverage table) and the bot uses
  it with no bot change. If 295 lands before this item, the sim misses buildings until then (accepted).

## Design notes
- The spike's weight profiles (growth, wealth) played alike (all ~275 mean score) and its tall (−4 per territory)
  collapsed to no cities, so tall is a constraint (a `settle` play onto a third territory is dropped from the
  candidates, read from effects, not ids) and wide a weight (spike: +3 per territory).
- Cheap mode is the rollout policy chosen over keeping ScriptedBot: no per-mechanic rules survive. 315 checks it's fast
  enough; if not, 315 says so in its Log rather than restoring ScriptedBot.
- Event choices keep 313's one-step value (no rollout); revisit in the balance item if the sim shows a choice event
  answered badly.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_generic_bot::test_the_bot_plays_generic_wide_and_tall`, `test_sim_stats_plays_every_strategy_for_all_and_refuses_others` |
| AC2 | `test_generic_bot::test_tall_never_settles_a_third_territory_and_generic_does`, `test_wide_settles_where_generic_builds_a_temple` |
| AC3 | `test_generic_rollouts` (all 11) |
| AC4 | `test_generic_raids::test_the_bot_moves_a_unit_onto_a_short_target`, `test_the_bot_keeps_a_unit_on_a_raided_target_it_holds` (pass already: 313's bot meets raids through `turn_forecast`) |
| AC5 | `test_generic_bot::test_scripted_bot_is_gone`; the ScriptedBot tests removed or ported (Log) |
| AC6 | docs (manual review) |

## Manual check
- [ ] `scripts/sim.sh 10` (all strategies) for each civ: note scores, revolts and seconds per game in the Log. Balance
  numbers move; a balance item re-baselines them.

## Log
- 2026-10-05: specced from the generic-bot spike, with 309–313, 315. Supersedes 298, 303, 168. Follows 313.
- 2026-10-05: red. AC4's two tests already pass on 313's bot: the raid's strike is in `turn_forecast`, so moving a
  Levy onto a short Hills values more with no raid rule. Rollouts' value is `value()` of the fork at the horizon (cheap
  mode), not score plus insight as 159/240 had. In green, the ScriptedBot tests go: `test_bot_lookahead.gd` (ported
  as `test_generic_rollouts.gd`), `test_bot_spending.gd`, the bot cases in `test_unrest`, `test_leaving_anarchy`,
  `test_renewal`, `test_wonder_sites`, `test_choice_events` and `test_sim`/`test_sim_anarchy`/`test_sim_strategies`
  (ported where they test SimStats rather than ScriptedBot's rules); `play_seed_1` (the UI smoke games) needs a driver.
