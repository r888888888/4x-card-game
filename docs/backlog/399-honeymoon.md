---
id: 399
title: A new government's honeymoon - 3 turns where unrest can't rise
type: feature
status: ready
branch: feat/399-honeymoon
---

## Goal
After [384](384-simpler-anarchy.md) a government chosen after Anarchy starts at 0 unrest, but nothing stops unrest from
climbing straight back or a revolution being declared at once (and with [385](385-renewal-action.md)'s free trashing,
revolting again and again could pay). Give the new government a **honeymoon**: for the 3 turns after it is chosen,
unrest can't rise and no revolution can be declared. It is a protection the player can feel and use: Settlers and
Corvée cost no unrest during it, a window to expand.

Builds on 384.

## Acceptance criteria
Fixtures are `tests/lib/anarchy_case.gd`'s, with `unrest.honeymoon_turns: 3` and Anarchy's 3 turns ending at the end of
turn 4 (fallen at turn 2's start), Kings chosen.

- [ ] AC1 (unrest can't rise): On turns 5, 6 and 7, `honeymoon_left()` is 3, 2 and 1; gaining unrest (an effect
  `gain unrest 2`, a played card adding unrest, an upkeep effect adding unrest) leaves unrest at 0, and a new era adds
  no unrest. On turn 8 `honeymoon_left()` is 0 and the same gains raise unrest as usual.
- [ ] AC2 (lowering still works): Given a honeymoon turn with unrest set to 2 directly, Feast brings it to 0 (it never
  goes below 0).
- [ ] AC3 (no revolution): During the honeymoon `revolt_error()` is "The people back the new government (N turns)."
  with N = `honeymoon_left()`, `revolt()` changes nothing, and `legal_actions()` has no `revolt`; on turn 8 a
  revolution can be declared.
- [ ] AC4 (no fall): Given a honeymoon turn and a government whose limit (with modifiers) is 0, Anarchy doesn't fall at
  the next turn's start while the honeymoon lasts.
- [ ] AC5 (the forecasts know it): During the honeymoon, `upkeep_forecast()` and `turn_forecast()` show no unrest
  gained and `anarchy_ahead()` is false; on its last turn (turn 7) they count the next upkeep's unrest as usual.
- [ ] AC6 (only after Anarchy, and off without config): A new game has no honeymoon (`honeymoon_left()` is 0 on turn
  1). With no `honeymoon_turns` in the unrest block there is none after Anarchy either. The loader: `honeymoon_turns`,
  when given, must be an integer ≥ 1 (else an error naming it). `copy()` copies the honeymoon (the suite's copy check).

## Out of scope
- Anarchy's own rules (384); renewal (385); the claimants (401–404).
- Any bonus during the honeymoon besides the two protections.

## Design notes
- Config `unrest.honeymoon_turns` (optional, integer ≥ 1; `data/config.json`: 3).
- New state: `GameState.honeymoon_until` (the last protected turn, 0 for none), set by `choose_government` to the
  current turn + `honeymoon_turns` (the choice comes at the end of Anarchy's last turn, so the protected turns are the
  next 3). New query `honeymoon_left()`: `honeymoon_until` − turn + 1, never below 0.
- `set_unrest` refuses a rise while `honeymoon_left()` > 0 (one place for every source: effects, era stir, size
  unrest, upkeep), and `Anarchy.start_of_turn` doesn't fall during it.
- `revolt_summary()` needs no change: no revolution is possible during the honeymoon, so it is `[]`.
- UI: the government slot shows the turns left ("Honeymoon: 3 turns", the count from `honeymoon_left()`), and the
  Revolt button shows `revolt_error()` as today.
- `GenericBot` sees it through `turn_forecast` (no unrest gained) and `legal_actions` (no revolt).

## Test plan
| AC | Test |
|---|---|
| AC1 | |

## Manual check
- [ ] After choosing a government the honeymoon shows with its turns left and disappears on turn 8.
- [ ] Playing a Settler during the honeymoon leaves the unrest meter at 0.
- [ ] Balance worry (for the user to run): free Settlers for 3 turns after every Anarchy may make revolting pay.
  `scripts/sim.sh --level 2 --compare <main checkout>` (revolts, settlements).

## Log
