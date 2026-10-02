---
id: 168
title: The sim bot recruits and moves units to meet raids
type: feature
status: ready
branch: feat/168-bot-defends-raids
---

## Goal
Raids would make the simulator meaningless if the bot ignored them. The `ScriptedBot` answers each announced raid
with the cheapest defence it can manage, so later balance items measure military fairly. Follows 163 (and 164–166 when
built).

## Acceptance criteria
- [ ] AC1: Given a raid forecast with the target's defence short of its strength and a unit stationed on another
  territory with no raid aimed at it, the bot moves that unit onto the target before ending its turn.
- [ ] AC2: Given a shortfall that moving can't cover and a unit in hand it can afford, it plays the unit onto the
  target if the target has a free worker, otherwise onto another territory and moves it there.
- [ ] AC3: The bot doesn't move a unit off a territory that a raid targets when that would leave it short.
- [ ] AC4: With no raid forecast, the bot doesn't play unit cards while a non-unit card it would play is in hand.

## Out of scope
- Buying units ahead of raids from the supply (a later strategy); upgrading.

## Design notes
- Uses only public API: `raid_forecast`, `defense`, `unit_strength`/strength, `move_unit`, `play_card`.

## Test plan
| AC | Test |
|---|---|

## Log
