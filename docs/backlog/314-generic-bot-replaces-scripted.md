---
id: 314
title: The generic bot replaces ScriptedBot; strategies generic, wide and tall
type: feature
status: ready
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
| AC1 | `test_generic_bot::test_…` |

## Manual check
- [ ] `scripts/sim.sh 10` (all strategies) for each civ: note scores, revolts and seconds per game in the Log. Balance
  numbers move; a balance item re-baselines them.

## Log
- 2026-10-05: specced from the generic-bot spike, with 309–313, 315. Supersedes 298, 303, 168. Follows 313.
