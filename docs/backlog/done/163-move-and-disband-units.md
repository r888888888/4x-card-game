---
id: 163
title: Move and disband units
type: feature
status: done
branch: feat/163-move-and-disband-units
---

## Goal
Units can march to defend another territory, which is what makes a raid's warning matter, and can be disbanded.
Moving uses an action and changes only a unit's station; it keeps using a worker on its home, so it can reinforce a 1-pop frontier
territory. Disbanding frees that worker; no pop moves. Follows 160 and 162.

## Acceptance criteria
- [x] AC1 (move): Given a Levy homed and stationed on Homeland and Hills settled, when `move_unit(levy, hills)`, then
  `unit_station(levy)` is Hills, its home is still Homeland, `free_workers` of both is unchanged, `defense(Hills)` rises
  by 2 and `defense(Homeland)` falls by 2. It uses one action, like playing a card; no resource is spent.
- [x] AC2 (once a turn): A unit moves at most once per turn: a second `move_unit` that turn returns false with
  `move_unit_error` `"Levy has already moved this turn."`; next turn it can move again.
- [x] AC3 (move errors): `move_unit_error` is `"That isn't a unit in your realm."` for a uid that isn't a unit in the
  tableau, `"Units can only move to a settled territory."` for a frontier or non-territory target, `"Levy is already
  on Hills."` for its own station, `"No actions left this turn."` with no action left, the pending-decision message
  while one is owed, and `"The game is over."` after the end. Order: game over / decision owed, no actions, then the
  unit and target checks (as `play_error`). An idle unit can move. Whenever the error is non-empty, `move_unit` changes nothing.
- [x] AC4 (disband): `disband(uid)` moves a unit from the tableau to the discard, frees its worker on its home
  (`free_workers` +1 there) and removes its strength from its station; no action used. `disband_error` covers a non-unit,
  a pending decision and game over, with the same messages as AC3.
- [x] AC5 (raids): A unit moved onto a raid's target before it strikes defends it, and one moved off doesn't; the
  target itself stays fixed (162 AC3). A garrison that loses goes to the discard whatever its home.
- [x] AC6 (added at green, for the Manual check): `move_targets(uid)` lists the settled territories unit uid can move
  to now ([] when it can't); `unit_move_block(uid)` says why it can't move anywhere ("" when it can; "Levy has
  nowhere else to go." with no other settled territory); `unit_origin(uid)` is "from Homeland" for a unit stationed
  away from its home, else "".

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
| AC6 | `test_unit_moves::test_move_targets_list_where_a_unit_can_go_now`, `test_unit_move_block_says_why_a_unit_cant_move_anywhere`, `test_unit_origin_names_the_home_of_a_unit_stationed_away`; UI: `test_details_move_and_disband_a_unit` |
| Review fix | `test_unit_moves::test_territory_groups_put_a_unit_with_its_station`, `test_a_moved_unit_shows_only_in_the_view_of_the_territory_it_stands_on` |

## Manual check
Run `godot --path ../4x-163 -- --seed 5`. Buy Warriors (Buy Cards), play it on your home when drawn, settle a second
territory, then open the home's territory view and click the Warriors.
- [ ] The details show Move… and Disband in the footer. Move… opens "Move Warriors" listing each other settled
  territory with its defence (⛨); picking one uses an action (the top bar's count drops, when the government limits
  actions) and closes the sheet.
- [ ] In the new territory's view the Warriors show with "from <home>" in the strip at the bottom of the card.
- [ ] Opening its details again: Move… is disabled, its tooltip "Warriors has already moved this turn."; next turn it
  is enabled again. With no action left the tooltip says "No actions left this turn."
- [ ] Disband sends the Warriors to the discard; the home's free workers (⚒) go up by one.

## Log
- 2026-10-04: At the red checkpoint the user changed AC1: moving uses an action (was free); AC3 gains the
  no-actions error. Disbanding stays free.
- UI: the territory view replaces the Realm while open, so the drag in the original Manual check had nowhere to drop.
  The user chose Move… / Disband in the unit's details instead; a Move… sheet (`ui/move_modal.gd`) lists
  `move_targets`. AC6 added at green for it.
- Error order: blocked, no actions, not a unit, moved this turn (`unit_move_block`'s reasons), then not a settled
  territory, then its own station.
- `move_targets` and `unit_move_block` sit in `game_engine.gd` beside `move_unit` (as `revolt_summary` does):
  `engine_queries.gd` is at 498 of its 500-line limit (249). Follow-up: spec a split of `EngineQueries` before
  the next query lands.
- Balance: moving now costs an action, which competes with plays under a limiting government; raids' tuning may want
  a look in a balance item (the bot doesn't move units yet, 168).
- Review (user): a moved unit still showed in its home's territory view. `territory_groups` grouped every card by its
  home (`territory_uid`), and the territory view, keyboard focus and the Realm all read it; a unit is now grouped
  with its station. Tests reproduced it first (engine and the real main scene).
