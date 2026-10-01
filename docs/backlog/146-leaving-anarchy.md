---
id: 146
title: Leaving Anarchy: a government the people accept, or paying to restore order
type: feature
status: ready
branch: feat/146-leaving-anarchy
---

## Goal
Anarchy is sticky but escapable by the player's own effort. A new government is only accepted once the people are
calm enough (unrest at most half its limit), so the way out is calming them, not luck of the draw; the more stable a
government, the sooner it is accepted. The player can also pay to restore order under the fallback government.
Follows 145. From `spike/unrest`.

## Acceptance criteria
- [ ] AC1: While Anarchy rules, given unrest 4 and Kingship (unrest limit 7) in hand, then `play_error` for Kingship
  is `"The people won't accept Kingship until unrest is 3 or less."` (7 / 2 rounded down, plus the `unrest_limit`
  modifier before halving). At unrest 3 it plays: Kingship rules, the anarchy card goes to `removed`, and unrest
  stays 3. Outside Anarchy, playing a government has no unrest condition.
- [ ] AC2: Given config `unrest.relief` `{"wealth": 6}` (optional; a non-empty object of known resources, amounts
  >= 1, unrest not allowed), Anarchy ruling and 6 wealth, when `restore_order()` is called, then wealth is 0, the
  fallback government (Chiefdom, limit 5) rules, the anarchy card is in `removed`, unrest becomes min(unrest, 2), and
  a notice says order is restored. `order_relief()` returns the price, `{}` with no relief configured.
- [ ] AC3: `restore_order_error()` is `"There is no anarchy."` outside Anarchy, `"Restoring order needs 6 wealth
  (you have 5)."` when short, the pending-decision message while one is owed, `"The game is over."` after the end;
  "" when it can pay. `restore_order()` returns false and changes nothing whenever the error is non-empty.
- [ ] AC4: A Restore order button below the Realm, beside Relieve famine, shows while Anarchy rules and relief is
  configured: `"Restore order (6 wealth)"`, disabled with `restore_order_error()` as its tooltip when it can't pay.
- [ ] AC5 (bot): while Anarchy rules, `ScriptedBot` pays to restore order at the end of its turn when it has at least
  2 counters, can pay, and no government in hand can be played. Given Anarchy with 1 counter and 10 wealth, it
  doesn't pay; with 2 counters it does.

## Out of scope
- Leaving early with a lasting penalty (a Fragile Order event) or relief prices that change with counters: ideas
  from the spike, not taken up.
- Renewal (147): its trashing is the main way to calm unrest during Anarchy.

## Design notes
- The half-limit check sits in `Anarchy.play_error` (145), so `play_error` and the UI's refusal show it.
- API: `restore_order()`, `restore_order_error()`, `order_relief()` (mirrors `relieve_famine`, `famine_relief`).
  Config: `unrest.relief`, real data `{"wealth": 6}`.
- Spike: with the gate, Anarchy lasted 2.3–2.9 turns; about half ended by a government, half by paying, almost
  none burnt out. Ways to calm during Anarchy: renewal (147), order cards (Feast), Temples' upkeep.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|

## Manual check
- [ ] In Anarchy with unrest above half Kingship's limit, Kingship in hand refuses with the reason; play Feast and it
  becomes playable.
- [ ] The Restore order button appears below the Realm in Anarchy and disappears once order is restored.

## Log
