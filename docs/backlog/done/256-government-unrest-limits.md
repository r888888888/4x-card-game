---
id: 256
title: Raise the governments' unrest limits so a run of bad events rarely forces Anarchy
type: feature
status: done
branch: feat/256-government-unrest-limits
---

## Goal
Since raids and the newer unrest events (Bandit Raids, Omen of Doom, Peasant Uprising) landed, a short run of bad
draws pushes Chiefdom into Anarchy in almost every game: one era change (+3) and one Omen of Doom (+2) fill its limit
of 5 on their own. Anarchy should follow neglected unrest, not one unlucky streak.

## Acceptance criteria
- [x] AC1 (data): the government unrest limits are Chiefdom 8, Kingship 10, Theocracy 13 (were 5, 7, 10), still
  rising with each later government.
- [x] AC2 (result): `scripts/sim.sh 20 all --turns 25` shows fewer involuntary Anarchies (anarchies − revolts) for
  every strategy than on `main`; before and after are in the Log.
- [x] AC3 (content tests): `scripts/test.sh` stays green with no test edited; only `data/cards.json` numbers change.

## Out of scope
- Event or raid numbers, era_unrest, Anarchy's length or drain.
- The bots' handling of unrest (they rarely play order cards, so they fall more often than a player would).

## Design notes
- A 10-seed trace over 100 turns found 93% of involuntary Anarchies happen under Chiefdom (152 of 164); Kingship and
  Theocracy almost never fall. Chiefdom's limit is the lever; the other two rise so each later government's limit
  stays above the one before.
- Variants tried, involuntary Anarchies per 25-turn game (baseline / growth / wealth / wide / tall), 20 seeds:
  - 5/7/10 (main): 1.43 / 1.42 / 1.01 / 1.05 / 1.34
  - 7/9/12: 0.99 / 0.87 / 0.68 / 0.68 / 0.87
  - 8/7/10: 0.98 / 0.88 / 0.62 / 0.58 / 0.91
  - 8/11/14: 0.92 / 0.82 / 0.60 / 0.57 / 0.84
  - 10/7/10: 0.65 / 0.67 / 0.23 / 0.26 / 0.63 (rejected: Anarchy becomes rare early; too generous for the start)
- `anarchies` in the sim counts the bots' deliberate revolts too; compare anarchies − revolts.

## Manual check
- [ ] Start a game: Chiefdom's card reads "Unrest limit 8" and the top bar's unrest shows "/ 8".

## Log
- 2026-10-04: chose 8/10/13. `scripts/sim.sh 20 all --turns 25`, involuntary Anarchies per game:

  | strategy | main (5/7/10) | 8/10/13 |
  |---|---|---|
  | baseline | 1.43 | 0.94 |
  | growth | 1.42 | 0.84 |
  | wealth | 1.01 | 0.60 |
  | wide | 1.05 | 0.57 |
  | tall | 1.34 | 0.85 |

  Score barely moves (baseline 27.1 → 28.1). Suite green, 1698 tests.
