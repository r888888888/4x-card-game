---
id: 084
title: Relieve a Famine by paying wealth
type: feature
status: ready
branch: feat/084-relieve-famine
---

## Goal
With a Famine (083) active, a hand with no food cards means watching pop die for turns. Let the player buy grain
with wealth to end the Famine at once, so wealth is a real answer to hunger and the worker spiral can be broken.

## Acceptance criteria
Setup as in 083, with `population.famine.relief: {"wealth": 5}`.

- [ ] AC1 (relief): Given a Famine at 2 counters and 7 wealth, `relieve_famine()` returns true, wealth is 2, and the
  Famine leaves the game (in no zone, `famine_counters()` 0). Growth works again (`grow_error` no longer names the
  Famine). A later short upkeep brings a new Famine with 1 counter.
- [ ] AC2 (rejections): `relieve_famine_error()` returns "There is no famine." with no Famine active, "Relieving the
  famine needs 5 wealth (you have 3)." with 3 wealth, "The game is over." after game over, and the pending-decision
  message while a decision is owed. In each case `relieve_famine()` returns false and changes nothing.
- [ ] AC3 (forecast): after relief, `upkeep_forecast().starve` is 0 if the next upkeep feeds pop, else 1 (a new
  Famine's first death).
- [ ] AC4 (loader): `relief` is a cost dict (known resources, integers ≥ 1); a bad value is a load error naming
  `population.famine.relief`. Without `relief`, `relieve_famine_error()` is "The famine can't be relieved."

## Out of scope
- A relief price that grows with the counters.
- Relief through a card effect (an op).

## Design notes
- New action pair `relieve_famine()` / `relieve_famine_error()` on `GameEngine`, rules in `Population` next to
  `feed`. Uses `_blocked_error("relieve_famine")` like `grow`.
- UI: a "Relieve (5 wealth)" button on the Famine card in the Events row, disabled with the error as its tooltip.
  The UI calls `relieve_famine_error()`; no rule in `ui/`.
- Real data: the `relief` price is set in `data/config.json` and reviewed with the `balance` skill (the sim bot
  should relieve when it can afford to and food won't cover the next upkeep).

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_famine::test_…` |

## Manual check
- [ ] The Relieve button shows on the Famine, is disabled with a reason when you can't pay, and the Famine flies off
  when you pay.

## Log
- Split from 083 (user asked for a wealth payout condition, 2026-09-29).
