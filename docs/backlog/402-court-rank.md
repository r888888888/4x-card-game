---
id: 402
title: The court - a claimant's passive, once per rank, rising every 10 turns
type: feature
status: ready
branch: feat/402-court-rank
---

## Goal
After [401](401-rival-claimants.md) a claimant takes the court but does nothing there. Give the court card its passive:
its upkeep effects and modifiers apply while it holds the court, **once per rank**. It takes the court at rank 1 and
rises a rank every 10 turns it holds it, up to rank 3. A stable court grows strong, so a late Anarchy (a natural fall,
or a revolution you chose) has a real price: a new court starts again at rank 1.

Builds on 401.

## Acceptance criteria
Fixtures: 401's, with Alpha's passive `upkeep: +1 wealth` and `"modifiers": {"administers": 1}`, and the court block with
`rank_turns: 10, max_rank: 3`. Alpha takes the court at the end of turn 4 (Anarchy fell at turn 2's start).

- [ ] AC1 (the passive works in the court): From turn 5's upkeep, each upkeep gives +1 wealth from Alpha, and the
  administers cap (`Modifiers.administers`) is 1 higher; `upkeep_forecast()` and `turn_forecast()` include the +1
  wealth. While Alpha is only dealt (in `claimants`) or back in the pool, its upkeep effects and modifiers count
  nowhere.
- [ ] AC2 (rank rises every 10 turns): `court_rank()` is 1 on turns 5 to 14, 2 on turns 15 to 24, 3 from turn 25, and
  still 3 on turn 60; 0 with an empty court.
- [ ] AC3 (once per rank): At rank 2 each upkeep gives +2 wealth from Alpha and the administers cap is 2 higher; at rank
  3, +3 and 3 higher. The forecasts match.
- [ ] AC4 (a new court starts over): Given Alpha in the court at rank 2 and a later Anarchy won by Beta, Beta's
  `court_rank()` is 1 on the first turn after, and Alpha's passive no longer applies.
- [ ] AC5 (loader): `court.rank_turns` and `court.max_rank` are optional integers ≥ 1 (defaults 10 and 3; else an error
  naming the field). A claimant's upkeep effects must be ops whose `upkeep_ok()` is true (the existing upkeep rule).
- [ ] AC6 (card text): A claimant's generated text shows its play effects under "When backed:" and its upkeep effects
  and modifiers under "In court, per rank:" (e.g. "In court, per rank: +1 wealth each upkeep. +1 administers.").

## Out of scope
- Keeping rank when the incumbent's faction wins again: 403.
- The real claimants and their numbers: 404.

## Design notes
- Config `unrest.court`: add `rank_turns` (10) and `max_rank` (3).
- New state: when the court card took the court (`GameState.court_since`, the first turn it held it), copied. Query
  `court_rank()`: 0 with an empty court, else min(`max_rank`, 1 + (turn − `court_since`) ÷ `rank_turns`).
- The court counts like an always-on zone, with a multiplier: `Modifiers.total` adds a court card's modifier × rank,
  and upkeep resolves its upkeep effects rank times (the forecasts read the same path, so they agree). Check every
  place that walks `ALWAYS_ON_ZONES` (modifiers, upkeep, forecasts, the resource breakdown of 379 if it has landed).
- UI: the court slot shows the card and its rank ("Rank 2"), with the turns to the next rank in its details, all from
  engine queries.
- `GenericBot` sees the passive through `turn_forecast`; the cost of losing a ranked court through its rollouts.

## Test plan
| AC | Test |
|---|---|
| AC1 | |

## Manual check
- [ ] The court slot shows the card, its rank and when it next rises.
- [ ] A claimant's text reads well on its face and in details.

## Log
