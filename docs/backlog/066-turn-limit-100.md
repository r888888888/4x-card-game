---
id: 066
title: 100-turn games, with a balance pass
type: feature
status: ready
branch: feat/066-turn-limit-100
---

## Goal
Play long enough for a civilization to grow (TODO 19). The game lasts 100 turns instead of 20. The content (territories,
techs, supply piles) and the thresholds are tuned so that the late game still has decisions.

## Acceptance criteria
<!-- Content item: rules already support any turn_limit (the loader reads it with min 1). -->
- [ ] AC1 (rules, TEST_CARDS): With `turn_limit: 100`, the game ends after turn 100's end_turn, and
  `upkeep_forecast()` is `{}` on turn 100. This is the existing rule, rechecked at 100.
- [ ] AC2 (content): the 20-seed scripted sweep plays full games on the real data with no runtime errors, and
  finishes within the suite's time budget. If needed, the sweep plays fewer turns and the sim covers full games.
- [ ] AC3 (content): the real territory deck has enough territories for the bot to keep exploring past turn 40 (sim
  metric; the exact size is under Manual check).
- [ ] AC4: the UI turn counter shows "Turn 37 / 100" without truncation (smoke test reads the label).

## Out of scope
- Era 3 content and new eras (a later item). If the late game is empty, record it here and spec the follow-up.

## Design notes
- Build last: every earlier item changes balance.
- `data/config.json`: `turn_limit: 100`, more territory copies, supply counts, and `era_unlocks` retuned.
- Use the `balance` skill: turns until the territory deck runs out, techs left unresearched at the end, and wealth or
  food left unspent. Record before and after in the Log.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_rules::test_…` |

## Manual check
- [ ] Review the shipped numbers (turn limit, territory counts, supply counts, era thresholds).
- [ ] Play to turn 60+: there are still meaningful choices each turn.

## Log
