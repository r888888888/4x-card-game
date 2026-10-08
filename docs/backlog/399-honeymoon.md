---
id: 399
title: A new government's honeymoon - 3 turns where unrest can't rise
type: feature
status: review
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

- [x] AC1 (unrest can't rise): On turns 5, 6 and 7, `honeymoon_left()` is 3, 2 and 1; gaining unrest (an effect
  `gain unrest 2`, a played card adding unrest, an upkeep effect adding unrest) leaves unrest at 0, and a new era adds
  no unrest. On turn 8 `honeymoon_left()` is 0 and the same gains raise unrest as usual.
- [x] AC2 (lowering still works): Given a honeymoon turn with unrest set to 2 directly, Feast brings it to 0 (it never
  goes below 0).
- [x] AC3 (no revolution): During the honeymoon `revolt_error()` is "The people back the new government (N turns)."
  with N = `honeymoon_left()`, `revolt()` changes nothing, and `legal_actions()` has no `revolt`; on turn 8 a
  revolution can be declared.
- [x] AC4 (no fall): Given a honeymoon turn and a government whose limit (with modifiers) is 0, Anarchy doesn't fall at
  the next turn's start while the honeymoon lasts.
- [x] AC5 (the forecasts know it): During the honeymoon, `upkeep_forecast()` and `turn_forecast()` show no unrest
  gained and `anarchy_ahead()` is false; on its last turn (turn 7) they count the next upkeep's unrest as usual.
- [x] AC6 (only after Anarchy, and off without config): A new game has no honeymoon (`honeymoon_left()` is 0 on turn
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
| AC1 | `test_honeymoon`: `test_the_honeymoon_counts_down_its_turns`, `test_during_the_honeymoon_no_source_raises_unrest`, `test_after_the_honeymoon_unrest_rises_as_usual` |
| AC2 | `test_honeymoon::test_during_the_honeymoon_unrest_still_falls_to_0` |
| AC3 | `test_honeymoon::test_no_revolution_during_the_honeymoon` |
| AC4 | `test_honeymoon::test_anarchy_doesnt_fall_during_the_honeymoon` |
| AC5 | `test_honeymoon::test_the_forecasts_count_no_unrest_during_the_honeymoon` |
| AC6 | `test_honeymoon`: `test_a_new_game_has_no_honeymoon`, `test_without_honeymoon_turns_there_is_none`, `test_honeymoon_turns_loads_and_is_validated`, `test_a_copy_keeps_the_honeymoon`; `test_engine_structure` (`honeymoon_left`) |
| UI (Design notes) | `test_honeymoon::test_the_sidebar_shows_the_honeymoon_turns_left` |

## Manual check
Steps: `godot --path . -- --seed 5`; revolt from the civilization modal, end turns until the Government overlay opens
and choose a government.
- [ ] After choosing a government the honeymoon shows with its turns left and disappears on turn 8.
- [ ] Playing a Settler during the honeymoon leaves the unrest meter at 0.
- [ ] Balance worry (for the user to run): free Settlers for 3 turns after every Anarchy may make revolting pay.
  `scripts/sim.sh --level 2 --compare <main checkout>` (revolts, settlements).

## Log
- 2026-10-08: red tests in a new `tests/test_honeymoon.gd`; only its games set `honeymoon_turns` (the shared
  `UNREST_BLOCK` stays without it, so other Anarchy tests keep their unrest). Resolved: N in the revolt message is
  "3 turns" / "1 turn"; AC4 also checks Anarchy falls at turn 8's start, once the honeymoon is over; the sidebar line
  reads "Honeymoon: 3 turns" under the government.
- 2026-10-08: green. `UpkeepBreakdown.ledger` now steps its fork to the next turn's number before the upkeep (the turn
  the upkeep belongs to), so a honeymoon's last turn forecasts its end; nothing else in the suite read the fork's turn.
  The sidebar test's setup moved inside `with_main` (it starts a new game); its assertions are unchanged.
- Follow-up: a new era during the honeymoon still posts "A new era stirs the people: +0 unrest." (`Anarchy.stir`
  notices whatever was added); it could stay silent when nothing was added.
