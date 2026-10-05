---
id: 313
title: A generic sim bot that values positions instead of following rules
type: feature
status: ready
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

- [ ] AC1: Given 1 action, food to pay, 10 turns left and a Temple (⟳ +1 score) and a Shrine (+1 score now) in the hand,
  when `take_turn` runs, then it plays the Temple. With 1 turn left it plays the Shrine (no upkeep left to score).
- [ ] AC2: Given a hand whose only playable card costs food and does nothing (a Guildhall with no effects), when
  `take_turn` runs, then it plays nothing and returns; the turn is left for `play` to end.
- [ ] AC3: Given 2 actions, a Scout (draw 2) and a Shrine in the hand and a deck of 4 Temples, when `take_turn` runs,
  then it plays the Scout first and a Temple second (a draw is worth what it lets you play next).
- [ ] AC4: Given 1 action, an Explorer and a Forager in the hand, an empty frontier and a Pioneer (settle) in the deck,
  then it plays the Explorer (the Pioneer gains a target); with no Pioneer anywhere it plays the Forager.
- [ ] AC5: Given an owed decision, it takes the option whose sample fork values most: given an event choice whose
  options differ only in gaining 1 or 3 food, it chooses the 3-food option.
- [ ] AC6: Given unrest 2 below the limit, a card that gains 2 unrest and a Forager, it plays the Forager. `GenericBot`
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
| AC1 | `test_generic_bot::test_…` |

## Manual check
- [ ] `scripts/sim.sh 10 generic --civ <each>` against `baseline`: note scores per civ and seconds per game in the Log
  (no tuning here).

## Log
- 2026-10-05: specced from the generic-bot spike, with 309–312, 314, 315. Follows 309–312.
