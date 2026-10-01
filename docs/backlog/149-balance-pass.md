---
id: 149
title: Balance pass for the action economy, Insight and Unrest
type: feature
status: draft
branch: feat/149-balance-pass
---

## Goal
Retune the numbers after three rule changes that each deferred their own balance work: actions per turn
(127–129), Insight and the open tech tree (139–143), and Unrest and Anarchy (144–148). 066's pass predates all
of them, so costs, yields and the 100-turn pacing have not been checked against the current game.

## Acceptance criteria
<!-- Draft: the targets below need your answers first (see Open questions). -->
- [ ] AC1 (targets): the item's Design notes record the target for each metric (score spread between strategies
  and civilizations, techs by turn 100, how often Anarchy happens), written before any number changes.
- [ ] AC2 (result): `scripts/sim.sh 20` after the changes meets those targets; before and after tables are in the Log.
- [ ] AC3 (content tests): `scripts/test.sh` stays green with no test edited; only `data/*.json` and `config` numbers change.

## Out of scope
- New rules, ops or cards. This item moves numbers only.
- Re-tuning the simulator's bots (134).

## Design notes
- Uses the `balance` skill. Sequence it after 148, or after 143 if research pacing should be tuned before Unrest
  builds on it (then re-check once 148 lands).

## Open questions
- Run once after 148, or twice (after 143 and after 148)? Recommended: once after 148, since 144–148 interact with
  research pacing (145's once-per-era pacing assumes 143).
- What counts as balanced: the bots are simple, so numbers are relative. Recommended target: no strategy or
  civilization's mean score more than a set margin from the others, and Anarchy reached in a minority of games.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|

## Log
- From the backlog tidy-up: the README listed this as "Balance pass for the action economy (to spec)" and it
  never became an item; 143 and 144 each deferred a general balance pass.
