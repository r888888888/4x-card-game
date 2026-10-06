---
id: 314
title: The generic bot replaces ScriptedBot; strategies generic, wide and tall
type: feature
status: review
branch: feat/314-generic-bot-replaces-scripted
---

## Goal
After 313 the sim has two bots, and the scripted one still needs a rule for every mechanic. After this, `GenericBot`
is the only bot: the sim plays `generic`, `wide` and `tall`, revolts and governments are weighed by rollouts the
generic bot plays itself in a cheap mode, it defends against raids because a raid's loss is in its value, and the
per-mechanic bot items (298, 303, 168) are closed as superseded.

## Acceptance criteria
- [x] AC1: `GenericBot.STRATEGIES` is `["generic", "wide", "tall"]`; `scripts/sim.sh` and `SimStats` play them (all of
  them when no strategy is given) and reject any other name with the current "unknown strategy" message.
- [x] AC2: tall never settles past 2 territories: given 2 settled territories, a Pioneer in the hand, a frontier
  territory and food to pay, tall doesn't play the Pioneer and generic does. wide adds a weight per settled territory:
  given 1 action, a Pioneer and a Temple where generic plays the Temple, wide plays the Pioneer.
- [x] AC3: Every `REVOLT_EVERY` (4) turns, outside a rollout and not in the last `ROLLOUT_TURNS` ÷ 2 turns, the bot
  revolts when a rollout that revolts and then chooses some government in the deck outscores one that doesn't
  (159's criteria, ported). When the government choice is owed it chooses by rollout; inside a rollout it chooses by
  value. Rollouts play `ROLLOUT_TURNS` (12) turns on a sample fork in cheap mode (no card values, no extra lookahead
  step) and leave the game untouched.
- [x] AC4: Given an announced raid that strikes next turn with its target's defence 1 short and a unit stationed on a
  territory no raid targets, the bot moves the unit onto the target before ending its turn; it doesn't move a unit off
  a raided target when that would leave the target short (168's AC1 and AC3, met through `turn_forecast`).
- [x] AC5: `sim/bot.gd` (`ScriptedBot`) and its tests are gone (`test_bot_lookahead.gd`, `test_bot_spending.gd`, the
  ScriptedBot cases elsewhere); `SimStats` plays `GenericBot`, still reports every metric, and `lookahead_turns` counts
  the rollout turns.
- [x] AC6: 298, 303 and 168 move to `done/` as `wontfix`, each with a Log line naming this item; the backlog README's
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
- [x] `scripts/sim.sh 5` (all strategies) for each civ: note scores, revolts and seconds per game in the Log. Balance
  numbers move; a balance item re-baselines them.

## Log
- 2026-10-05: specced from the generic-bot spike, with 309–313, 315. Supersedes 298, 303, 168. Follows 313.
- 2026-10-05: red. AC4's two tests already pass on 313's bot: the raid's strike is in `turn_forecast`, so moving a
  Levy onto a short Hills values more with no raid rule. Rollouts' value is `value()` of the fork at the horizon (cheap
  mode), not score plus insight as 159/240 had. In green, the ScriptedBot tests go: `test_bot_lookahead.gd` (ported
  as `test_generic_rollouts.gd`), `test_bot_spending.gd`, the bot cases in `test_unrest`, `test_leaving_anarchy`,
  `test_renewal`, `test_wonder_sites`, `test_choice_events` and `test_sim`/`test_sim_anarchy`/`test_sim_strategies`
  (ported where they test SimStats rather than ScriptedBot's rules); `play_seed_1` (the UI smoke games) needs a driver.
- 2026-10-05: green phase.
  - `GenericBot` gained `STRATEGIES` (generic, wide, tall), `rollout`, `REVOLT_EVERY` 4, `ROLLOUT_TURNS` 12 and a static
    `lookahead_turns`; rollouts share one seed per turn (so options are compared on the same future) and run in cheap
    mode. wide is +20 value per settled territory (12 wasn't enough to settle over a Temple in AC2's fixture: playing a
    Temple also raises the deck's average worth, because it leaves the draw pile); tall drops `settle` plays past 2.
  - Bug found and fixed: the deck's worth counted unlimited actions (`actions_per_turn` −1) as 1 play a turn, so
    restoring order from Anarchy (1 action) to Chiefs (unlimited) looked worthless. Unlimited now counts a full hand.
  - `sim/bot.gd`, `test_bot_lookahead.gd` and `test_bot_spending.gd` removed; ScriptedBot's rule tests removed from
    `test_unrest`, `test_leaving_anarchy`, `test_renewal`, `test_wonder_sites`, `test_choice_events` (pick_option),
    `test_sim` (explore, tech pick, famine relief) and `test_sim_strategies` (each strategy's card order and buying).
  - Ported to the generic bot with fixture changes (they test SimStats or game flow, not a bot rule):
    `test_sim::test_sim_stats_reports_how_long_the_territory_deck_lasted` (Pathfinders, explore +1 food: the bot
    doesn't explore for nothing); `test_sim_anarchy`: Charter also gains 1 food (so it's played), the burn-out game
    starts with 0 wealth (else the bot buys order, worth a full hand of plays), the buy-order game scores pop
    (`vp_per_pop` 1: else Anarchy's pop loss costs nothing and order isn't worth buying). The bot's choice events and
    renewal tests now check it answers them.
  - `play_seed_1` (11 UI tests) plays with a new test helper, `play_first_legal` (the first legal action each step):
    a 20-turn real game takes 0.03 s that way, 0.7 s in cheap mode, 2 s with the full bot.
  - The balance tests name `generic` for `baseline` and the three strategies.
  - 168, 298 and 303 moved to `done/` as wontfix; PLAN, CLAUDE.md, README, testing.md and the spec, add-decision
    and balance skills name `GenericBot`.
- 2026-10-05: the balance suite takes 43 min now (29 tests; was minutes): its tests play full real-data games, ~25 s
  each with GenericBot, mostly in one process. 315 (speed) should look at it, or the balance tests should play
  shorter games (`turns`) where the length isn't what they test.
- 2026-10-05: with the user's approval, `test_sim_stats_plays_every_strategy_for_all_and_refuses_others` checks the
  first error line (a stringified array escapes the quotes, so the old check could never match).
- 2026-10-05: manual check, `scripts/sim.sh 5` (all strategies, every civ, 5 seeds; 90 games in 1549 s on 7 workers,
  about 2 min of CPU a game with rollouts):

  | Strategy | Mean score (min–max) | By civ (egypt, sumer, phoenicia, babylon, greece, persia) | Cities | Revolts | Anarchies |
  |---|---|---|---|---|---|
  | generic | 305 (126–649) | 368, 241, 317, 211, 363, 327 | 13.2 | 4.3 | 4.7 |
  | wide | 511 (151–838) | 536, 518, 454, 531, 588, 440 | 30.3 | 2.8 | 3.0 |
  | tall | 119 (50–273) | 76, 113, 80, 102, 203, 137 | 1.0 | 6.0 | 6.9 |

  The bot now revolts (313's never did) and uses Kingship and Theocracy (15 and 39 turns a game for generic). Tall
  (one city beyond the home) is far behind wide: the gap upgrades (300–307) are meant to close. Balance worries for
  the balance item after 315: wide's +20 per territory may be too strong a lever; tall revolts and falls into
  Anarchy most. A sim run is now ~25 min for 5 seeds: 315 matters.
