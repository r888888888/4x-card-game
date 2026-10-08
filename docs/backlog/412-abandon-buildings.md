---
id: 412
title: Abandon a finished building to free its slot and worker
type: feature
status: red-review
branch: feat/412-abandon-buildings
---

## Goal
The player can clear a building they no longer want: a Farm in the slot a better building needs, a building whose
worker is better used elsewhere, or (once 405 lands) one whose upkeep isn't worth paying. Today only an unfinished
wonder site can be abandoned (286) and only units can be disbanded (163); a finished building stays for the rest of the
game.

## Acceptance criteria
Fixtures: `TEST_CARDS` buildings, built from a test `build_menu` unless a criterion says otherwise: Hut (no effects), a
Hut with an upgrade on it and an upgrade on that (a two-deep tree), a building with `housing` 2, a `once` entry, a
completed project and an unfinished one. Population is on where a criterion names pop.

- [ ] AC1 (main path): Given a working Hut on Homeland with 2 actions left and 3 wealth, when `abandon(hut)` is called,
  then it returns true, the Hut is in no zone (not tableau, discard, hand or deck), Homeland's free slots and free
  workers are each 1 higher, actions and resources are unchanged, the log reads "Abandoned Hut.", and `changed` fires
  once. The Hut's entry can be built again on Homeland.
- [ ] AC2 (dealt building): Given a Hut played from the hand (its id not in `build_menu`), when it is abandoned, then it
  goes to the discard, as a disbanded unit dealt from a deck does.
- [ ] AC3 (its upgrades go with it): Given a Hut with an upgrade on it and a second upgrade on that, when the Hut is
  abandoned, then all three leave the tableau and the base's modifiers, housing, defence and VP from all three no
  longer count (score and the territory's figures equal those of a game with no Hut built). When only the first upgrade
  is abandoned, then it and the upgrade on it leave, and the Hut stays, working.
- [ ] AC4 (idle buildings wake): Given a territory with 2 pop and three buildings, the last placed idle, when the first
  is abandoned, then the idle one works (`is_idle` false) and counts in `upkeep_forecast()`.
- [ ] AC5 (refusals): `abandon_error` names the reason and `abandon` returns false with no change when: the card is a
  wonder or a `once` entry ("Pyramids can't be abandoned."), its housing is still needed (a territory with 5 pop whose
  housing is 5 only with the building's 2: "Homeland's 5 pop need Insula's housing."), the card isn't a building or
  site in the tableau (a unit, a city, a hand card, an unknown uid), the game is over or a decision is owed. An idle or
  fallen-back building can be abandoned.
- [ ] AC6 (sites unchanged): Abandoning an unfinished project site behaves as 286 says (to the discard, progress
  lost); the 286 tests pass unchanged.
- [ ] AC7 (bot sees it): `LegalActions` lists `["abandon", uid]` for every building and upgrade `abandon_error` allows,
  as well as sites; none for a wonder, a `once` entry or a building whose housing is needed. `copy()` keeps the
  result the same (no new state).

## Out of scope
- Refunds, an action cost, or rebuilding a `once` entry.
- Any reason to abandon in the shipped data beyond freeing a slot or worker (405's upkeep supplies it).
- Abandoning cities or territories.

## Design notes
- Engine: widen the existing `abandon(uid)` / `abandon_error(uid)` (now in `engine/sites.gd`) rather than add a second
  action, so the UI, bot and error query stay one pair. The building half probably belongs beside it in a small module
  or in `Upgrades` for the tree; keep `Sites` about sites. Where a card goes reuses the unit rule (296):
  `disbands_to_discard` generalises to "came from the build menu → gone, else → discard" (rename if it reads better).
  Upgrades leave depth first (`upgrades_on`), so nothing is left pointing at a missing `base_uid`.
- Housing refusal: pop can't exceed housing (060), so abandoning is refused rather than killing pop. Compare
  `pop(t)` with `housing(t)` less the card's (and its upgrades') housing; housing modifiers from the tree count too.
- Wonders: a completed `project` and any `once` entry are refused; `built_once` is never cleared.
- No new state: idleness, fallback and housing are derived, so they update by themselves; check `copy()` anyway.
- Bot: GenericBot already tries `abandon` (313). More candidates per turn may slow sims (315); if the suite or a sim
  shows it, limit candidates to idle or fallen-back buildings, or to ones whose forecast changes, and log it here.
- UI: the details modal's existing "Abandon…" button and `AbandonModal` show for a finished building too, with
  wording that fits (no "progress lost"; names the upgrades that go with it). Upgrade rows in the details' Upgrades
  section (387) that are "Built" get an Abandon… too. Every button checks `abandon_error`.
- PLAN.md: the 286 paragraph's `abandon` line and the 300 upgrades paragraph.

## Test plan
All in `tests/test_abandon_buildings.gd` unless named.

| AC | Test |
|---|---|
| AC1 | `test_abandoning_a_building_frees_its_slot_and_worker_for_nothing` |
| AC2 | `test_abandoning_a_building_played_from_the_hand_discards_it` |
| AC3 | `test_abandoning_a_base_takes_its_upgrade_tree_with_it`, `test_abandoning_an_upgrade_takes_the_upgrades_on_it_and_leaves_its_base` |
| AC4 | `test_abandoning_a_building_wakes_an_idle_one_behind_it` |
| AC5 | `test_a_wonder_or_a_once_entry_cant_be_abandoned`, `test_a_building_whose_housing_the_pop_needs_cant_be_abandoned`, `test_only_a_building_in_play_can_be_abandoned`, `test_an_idle_or_fallen_back_building_can_be_abandoned`, `test_abandoning_a_building_is_refused_while_a_decision_is_owed_or_the_game_is_over` |
| AC6 | the existing `test_wonder_sites.gd` AC8 tests; `test_abandoning_is_refused_for_a_completed_wonder_or_a_card_in_hand` loses its Farm case |
| AC7 | `test_legal_actions_list_abandoning_each_building_that_can_go` |

## Manual check
- [ ] Open a Farm's details: "Abandon…" asks to confirm, naming any upgrades that go with it; confirming clears the
  slot and the card leaves the territory view.
- [ ] A wonder's details show no Abandon…, or a disabled one with its reason.
- [ ] Balance worry (for the user to run, not part of this item): `scripts/sim.sh --level 2 --compare <main checkout>`
  to see whether the bot now abandons buildings, and how long the runs take.

## Log
- 2026-10-08: Decisions from the user: free and no refund; upgrades go with their base (an upgrade can also be
  abandoned alone); wonders and `once` entries can't be abandoned; build-menu buildings leave play, dealt ones go to the
  discard. Assumed (not asked): refuse when the territory's pop needs the building's housing.
- 2026-10-08 (red): AC6 said the 286 tests pass unchanged, but `test_wonder_sites.gd`'s refusal test listed a plain Farm
  as not abandonable. That case is the rule this item changes, so it is dropped and the test renamed
  (`test_abandoning_is_refused_for_a_completed_wonder_or_a_card_in_hand`). A refusal for "not a building in play"
  reads "That isn't a building in play." (it replaces 286's "That isn't a wonder being built.").
