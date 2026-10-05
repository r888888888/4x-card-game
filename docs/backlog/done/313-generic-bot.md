---
id: 313
title: A generic sim bot that values positions instead of following rules
type: feature
status: done
branch: feat/313-generic-bot
---

## Goal
ScriptedBot plays by a fixed priority list with a rule per mechanic, so every mechanic needs its own bot item and the
sim measures the bot's blind spots (the spike found the scripted bot made Phoenicia, Greece and Persia look about
half as strong as the generic one did). After this, `GenericBot` (`sim/generic_bot.gd`) plays by trying each of
`legal_actions()` on a sample fork, valuing the result with one function and doing the best, and the sim can run it as
the strategy `generic` beside ScriptedBot's. 314 then makes it the only bot.

## Acceptance criteria
Fixture games (`make_engine`, a few turns); the value function is in Design notes.

- [x] AC1: Given 1 action, food to pay, 10 turns left and a Temple (⟳ +1 score) and a Shrine (+1 score now) in the hand,
  when `take_turn` runs, then it plays the Temple. With 1 turn left it plays the Shrine (no upkeep left to score).
- [x] AC2: Given a hand whose only playable card costs food and does nothing (a Guildhall with no effects), when
  `take_turn` runs, then it plays nothing and returns; the turn is left for `play` to end.
- [x] AC3: Given 2 actions, a Scout (draw 2) and a Shrine in the hand and a deck of 4 Temples, when `take_turn` runs,
  then it plays the Scout first and a Temple second (a draw is worth what it lets you play next).
- [x] AC4: Given 1 action, an Explorer and a Forager in the hand, an empty frontier and a Pioneer (settle) in the deck,
  then it plays the Explorer (the Pioneer gains a target); with no Pioneer anywhere it plays the Forager.
- [x] AC5: Given an owed decision, it takes the option whose sample fork values most: given an event choice whose
  options differ only in gaining 1 or 3 food, it chooses the 3-food option.
- [x] AC6: Given unrest 2 below the limit, a card that gains 2 unrest and a Forager, it plays the Forager. `GenericBot`
  only does what `legal_actions()` lists, never changes the real game while valuing (a fixture game's state is the
  same before and after `best_action`), and with the same seed plays the same game twice.

## Out of scope
- Revolts, strategies, raids and removing ScriptedBot: 314. Speed: 315. Tuning the weights: a balance item.

## Design notes
- Start from `sim/generic_bot.gd` on `spike/generic-bot` (keep that branch while this item is open). Port, replacing
  internals with 309–312: `income` → `turn_forecast()`, `has_targets` → `would_target`/`would_need_target`,
  `candidates`/`decision_options` → `legal_actions()`, `engine.fork()` → `sample_fork(seed)` with seed from the game's
  seed, turn and step (repeatable, never the game's rng).
- Value of a position: score + ahead × forecast score + Σ weight × concave(stock + ahead × forecast change) for food,
  wealth and insight (diminishing returns: hoarding counts for little) − unrest weight × unrest − a squared penalty when
  unrest + 2 × its change + 1 nears the limit (margin 3) + deck worth (ahead × plays a turn × the average value of the
  draw pile's cards, 0 for a card with nothing to act on) + 0.5 × the printed cost of learned techs. ahead =
  min(10, turns left). A card's value is measured by playing a copy on a fork (its cost on hand, an action to spare),
  kept 4 turns.
- A candidate whose value is within 0.5 of doing nothing and that gave back a card or an action (a draw, +1 action)
  gets one more step of lookahead. Buys: only the top 3 by card value per price are tried.
- Owed decisions answered on a fork before the fork is valued (an explore's choice). Renewal: expand 312's entry to
  combinations (up to 40).
- Spike results (10 seeds per civ, real data): generic 222–277 mean score per civ vs ScriptedBot baseline 102–237;
  ~25 s a game vs ~2 s.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_generic_bot::test_with_10_turns_left_it_plays_the_temple_that_scores_every_turn`, `test_on_the_last_turn_it_plays_the_shrine` |
| AC2 | `test_generic_bot::test_it_plays_nothing_when_nothing_helps` |
| AC3 | `test_generic_bot::test_it_plays_a_draw_first_when_it_draws_something_better` |
| AC4 | `test_generic_bot::test_it_explores_when_a_settler_would_gain_a_target`, `test_without_a_settler_it_forages_instead_of_exploring` |
| AC5 | `test_generic_bot::test_it_answers_an_event_choice_with_the_option_that_values_most` |
| AC6 | `test_generic_bot::test_it_stays_clear_of_the_unrest_limit`, `test_it_only_does_what_legal_actions_lists_and_valuing_changes_nothing`, `test_the_same_seed_plays_the_same_game` |
| Goal (the sim runs `generic`) | `test_generic_bot::test_sim_stats_plays_the_generic_strategy` |

## Manual check
- [x] `scripts/sim.sh 10 generic --civ <each>` against `baseline`: note scores per civ and seconds per game in the Log
  (no tuning here).

## Log
- 2026-10-05: specced from the generic-bot spike, with 309–312, 314, 315. Follows 309–312.
- 2026-10-05: red. "1 turn left" in AC1 is the last turn (turn = turn_limit). AC5 uses a fixture choice event, Gift
  (+1 or +3 food). `generic` is a strategy SimStats accepts but not one of `ScriptedBot.STRATEGIES`, so `sim.sh` with
  no strategy (all) still plays only the scripted five (each generic game is ~10× slower); 314 makes it the only bot.
  The bot never lists `end_turn` (play ends the turn) or `revolt` (314's rollouts) among its candidates.
- 2026-10-05: green. Ported from the spike onto 309–312 (`legal_actions` less `end_turn`/`revolt`, `sample_fork` with a
  seed from the game's seed, turn and step, `turn_forecast`, `would_target`); a `Context` per game holds the weights,
  card values and step, so no state leaks between games. To meet AC6 (Riot played far from the limit) unrest got no
  flat weight (it costs only through the risk term) and the risk margin went from 3 to 2. SimStats plays `generic`
  (`GenericBot.STRATEGY`); `run_files` accepts it.
- 2026-10-05: manual check, `scripts/sim.sh 10 <strategy> --civ <civ>` on real data (mean score, min–max; techs;
  anarchies; wall time for 10 games on 7 workers):

  | Civ | baseline | generic | techs b → g | anarchies b → g | generic time |
  |---|---|---|---|---|---|
  | Egypt | 95 (25–208) | 315 (141–475) | 20 → 31 | 7.4 → 0.2 | 36 s |
  | Sumer | 64 (39–122) | 199 (82–363) | 20 → 31 | 8.5 → 0.2 | 25 s |
  | Phoenicia | 71 (46–92) | 259 (101–478) | 22 → 31 | 7.4 → 0.5 | 42 s |
  | Babylon | 88 (57–140) | 268 (110–584) | 20 → 31 | 10.8 → 0.5 | 36 s |
  | Greece | 51 (31–118) | 255 (68–554) | 20 → 30 | 8.3 → 0.4 | 34 s |
  | Persia | 73 (35–105) | 202 (102–335) | 20 → 31 | 8.3 → 0.7 | 25 s |

  The baseline fell from the spike's 102–237 since 295: ScriptedBot never builds from the build menu (298 is blocked
  in favour of 314), while the generic bot builds through `legal_actions` with no change. Generic never revolts (314's
  rollouts) and rarely falls into Anarchy. About 20–30 s a game, as in the spike; 315 is the speed item. No tuning
  here: balance worries go to the balance item after 315.
