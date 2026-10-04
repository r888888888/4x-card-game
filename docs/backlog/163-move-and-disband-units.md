---
id: 163
title: Move and disband units
type: feature
status: in-progress
branch: feat/163-move-and-disband-units
---

## Goal
Units can march to defend another territory, which is what makes a raid's warning matter, and can be disbanded.
Moving uses an action and changes only a unit's station; it keeps using a worker on its home, so it can reinforce a 1-pop frontier
territory. Disbanding frees that worker; no pop moves. Follows 160 and 162.

## Acceptance criteria
- [ ] AC1 (move): Given a Levy homed and stationed on Homeland and Hills settled, when `move_unit(levy, hills)`, then
  `unit_station(levy)` is Hills, its home is still Homeland, `free_workers` of both is unchanged, `defense(Hills)` rises
  by 2 and `defense(Homeland)` falls by 2. It uses one action, like playing a card; no resource is spent.
- [ ] AC2 (once a turn): A unit moves at most once per turn: a second `move_unit` that turn returns false with
  `move_unit_error` `"Levy has already moved this turn."`; next turn it can move again.
- [ ] AC3 (move errors): `move_unit_error` is `"That isn't a unit in your realm."` for a uid that isn't a unit in the
  tableau, `"Units can only move to a settled territory."` for a frontier or non-territory target, `"Levy is already
  on Hills."` for its own station, `"No actions left this turn."` with no action left, the pending-decision message
  while one is owed, and `"The game is over."` after the end. Order: game over / decision owed, no actions, then the
  unit and target checks (as `play_error`). An idle unit can move. Whenever the error is non-empty, `move_unit` changes nothing.
- [ ] AC4 (disband): `disband(uid)` moves a unit from the tableau to the discard, frees its worker on its home
  (`free_workers` +1 there) and removes its strength from its station; no action used. `disband_error` covers a non-unit,
  a pending decision and game over, with the same messages as AC3.
- [ ] AC5 (raids): A unit moved onto a raid's target before it strikes defends it, and one moved off doesn't; the
  target itself stays fixed (162 AC3). A garrison that loses goes to the discard whatever its home.

## Out of scope
- Moving costs beyond the action, distance or travel time; moving several units at once.

## Design notes
- New API: `move_unit(uid, territory_uid)` / `move_unit_error(uid, territory_uid)`, `disband(uid)` / `disband_error(uid)`.
- Per-turn tracking in `GameState` (e.g. `moved_units`, cleared at the start of a turn), copied by `copy()`.
- Under Anarchy, moving and disbanding are allowed (they aren't building, buying or researching).

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_unit_moves::test_moving_a_unit_changes_its_station_for_an_action` |
| AC2 | `test_unit_moves::test_a_unit_moves_once_a_turn`, `test_moves_this_turn_survive_a_fork` |
| AC3 | `test_unit_moves::test_move_unit_error_reasons`, `test_moving_needs_an_action_left`; `test_blocking` rows for `move_unit` |
| AC4 | `test_unit_moves::test_disbanding_a_unit_frees_its_worker_and_its_strength`, `test_disband_error_reasons`; `test_blocking` rows for `disband` |
| AC5 | `test_raids::test_163_a_unit_moved_onto_the_target_defends_it`, `test_163_a_unit_moved_off_the_target_doesnt_defend_it`, `test_163_a_lost_garrison_goes_to_the_discard_whatever_its_home` |

## Manual check
- [ ] Drag a unit from the territory view onto another territory in the Realm row to move it; the moved unit shows on
  the new territory with "from Homeland".
- [ ] A Disband button in the unit's details; a unit that already moved this turn shows why it can't move again.

## Log
- 2026-10-04: At the red checkpoint the user changed AC1: moving uses an action (was free); AC3 gains the
  no-actions error. Disbanding stays free.
