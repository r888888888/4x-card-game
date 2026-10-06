---
id: 300
title: Build upgrades onto buildings: they add to their base, stack, and chain
type: feature
status: review
branch: feat/300-building-upgrades
---

## Goal
Today a territory's buildings are all equal: one slot and one worker each, with output that ignores where they stand.
After this, a building can carry **upgrades**: cards from the build menu built onto a building already in play, not onto
a territory. An upgrade takes no slot and no worker, and it adds to what its base does (its own effects, modifiers,
housing, defence, VP) while its base works. A base can carry several different upgrades (a Farm takes both a plough and
irrigation), and an upgrade can itself be a base (Shrine → Temple → Great Temple). This is the engine half of the tall
rework; 301 adds the settlement tier an upgrade may need, and the content items (305–307) use both. Follows 295.

## Acceptance criteria
Fixture: `TEST_CARDS` plus these extra cards, with config `build_menu` `{"farm": {}, "plough": {}, "ditch": {},
"chapel": {}, "sanctum": {}, "cathedral": {}}`:
- Plough: `{"id": "plough", "name": "Plough", "type": "building", "cost": {"food": 1}, "vp": 1, "upgrade_of": "farm",
  "effects": [{"op": "gain", "resource": "food", "amount": 1, "trigger": "upkeep"}]}`
- Ditch: `{"id": "ditch", "name": "Ditch", "type": "building", "cost": {"food": 1}, "upgrade_of": "farm", "housing": 1,
  "effects": [{"op": "gain", "resource": "food", "amount": 1, "trigger": "upkeep", "keyword": "flood_plain"}]}`
- Chapel: `{"id": "chapel", "name": "Chapel", "type": "building", "cost": {"food": 1}}`; Sanctum: `{"id": "sanctum",
  "name": "Sanctum", "type": "building", "cost": {"food": 1}, "upgrade_of": "chapel", "modifiers": {"hand_size": 1}}`;
  Cathedral: `{"id": "cathedral", "name": "Cathedral", "type": "building", "cost": {"food": 1}, "upgrade_of":
  "sanctum", "vp": 2}`

- [x] AC1 (loader): A building may set `upgrade_of`, another building's id. Load errors naming file, card and field: an
  unknown id ("upgrade_of: unknown card 'x'"); a card that isn't a building ("upgrade_of: 'scout' is an action"); a
  cycle, itself included, reported once on its first card in card order ("upgrade_of: cycle plough → plough"); an
  upgrade that is a project, or names one ("upgrade_of: a project can't take or be an upgrade"). `upgrade_of` on another
  type is ignored with a warning (`DataLoader.TYPE_FIELDS`). An upgrade can't be in `deck` or `supply`, or be the card of
  a `create` effect ("deck: 'plough' is an upgrade; build it from the build menu").
- [x] AC2 (build one): Given a Farm on Homeland (pop 2, the Farm working), 1 food and 2 actions left, when
  `build("plough", farm_uid)` is called, then it returns true; food is 0; actions left is 1; a new Plough is in the
  tableau with Homeland as its territory and `upgrade_base(plough_uid)` is the Farm's uid; Homeland's `free_slots` and
  `free_workers` are what they were before; `card_played` is emitted with the Plough's uid and the Farm's uid as target,
  and its `play` effects resolve. `upgrades_on(farm_uid)` is `[plough_uid]`. `build_targets("plough")` lists every Farm
  that could take it now (whatever it costs), in tableau order; with target −1 and exactly one such Farm, `build`
  builds there. A Farm that is idle can be upgraded.
- [x] AC3 (refusals): `build_error("plough", target)` is "" exactly when `build` would succeed, and `build` returns
  false and changes nothing otherwise. Besides 295's refusals (blocked, locked, no actions, Anarchy, short of the cost),
  each with its message: the target isn't a Farm in the tableau, a territory included ("Plough builds on a Farm."); the
  Farm already carries a Plough ("That Farm already has a Plough."); no Farm can take it, target −1 ("No Farm to build
  Plough on."); target −1 with two or more ("Choose a Farm for Plough."); an upgrade whose `requires` its base's
  territory lacks gets the requires message building it would. A non-upgrade building given a building's uid as target
  is refused as today ("That target isn't valid.").
- [x] AC4 (stack and chain): A Farm can carry a Plough and a Ditch together, built in either order; `upgrades_on`
  lists them in build order. A second Farm can carry its own Plough. Cathedral builds on a Sanctum, never on a Chapel
  ("Cathedral builds on a Sanctum."), so a Chapel → Sanctum → Cathedral chain takes two builds; `upgrades_on(chapel)`
  is `[sanctum]` and `upgrades_on(sanctum)` is `[cathedral]`.
- [x] AC5 (an upgrade adds while its base works): Given a Farm with a Plough and a Ditch on River (flood plain, pop 1,
  so the Farm works), then the next upkeep gains 3 food from them (Farm 1, Plough 1, Ditch 1), River's housing is 1
  more than without the Ditch, and `score()` includes the Plough's 1 VP. Given Chapel → Sanctum → Cathedral working,
  `hand_size()` is 1 more and the Cathedral's 2 VP count. When the base stops working (River's pop drops to 0, so the
  Farm is idle; or it is past its territory's slots), then its upgrades and everything built on them count for nothing:
  no upkeep effects, modifiers, housing, defence, training or famine guard, and their printed VP leaves `score()`;
  `fallen_back_reason(uid)` says why ("Its Farm is idle."; "" while it works). When the base works again, so do they,
  at no cost. `upkeep_forecast` agrees with the upkeep that follows.
- [x] AC6 (state and text): `GameState.copy()` and `fork()` keep each upgrade's base (the suite's copy check covers the
  new `CardInstance` field). An upgrade's generated card text starts with the line "Builds on a Farm." and its details
  say the same; a base's text is unchanged. A tech's `unlock` of an upgrade entry reads "Plough can now be built on a
  Farm." (card text and the unlock notice), where 295 says "… can now be built." for a building.

## Out of scope
- Settlement tiers on upgrades and buildings, and falling back below one (301).
- UI: ribbons on the base card, the "+ Upgrade" chip, the Build modal's Upgrades heading (302). `build_preview` (299)
  with a building as target comes with 302.
- The bot (303), content (305–307), a per-pop gain op (304).
- Removing an upgrade, or moving a base: no rule moves a building out of the tableau today, and projects (the only
  buildings that can be abandoned) can't take upgrades.

## Design notes
- **Data format.** New building field `upgrade_of` (string, a building id), in `DataLoader.TYPE_FIELDS` for
  `CardDef.BUILDING`; parsed into `CardDef.upgrade_of`. Upgrades are build-menu entries like any building (locked or
  not, unlocked by a tech's `unlock`); `once` works on them as on any entry.
- **State.** Each upgrade is its own `CardInstance` in the tableau, so its effects, modifiers, housing and defence go
  through the paths every building uses. New `CardInstance.base_uid` (−1 for anything else), copied by `copy()`.
  Its `territory_uid` is its base's, so `keyword` effects and the territory's sums find it.
- **No slot, no worker.** `CardDef.uses_worker()` is false for an upgrade, and `Territories.buildings_on` (the slot
  count and slot-idle order) skips upgrades; `Modifiers.working_cards`' single pass must skip them the same way, then
  drop an upgrade whose base was dropped (a base comes before its upgrades in tableau order, so one pass still works).
- **"Counts for nothing".** Unlike an idle building (which keeps its housing and printed VP), a fallen-back upgrade
  keeps neither: the user chose a true revert. Housing that falls never culls pop (pop is only capped when it grows),
  so this can't start a loop. Eurekas count tableau cards idle or not, and they count fallen-back upgrades too.
- **Engine API.** `build` / `build_error` / `build_targets` (295) accept a building uid as target for an upgrade
  entry. Queries `upgrade_base(uid) -> int`, `upgrades_on(uid) -> Array[int]`, `fallen_back_reason(uid) -> String`.
- **Relation to 166.** Unit upgrades (166) replace the unit with another card (`upgrades_to` on the base). Buildings
  add instead, because a base can carry several. When 166 is built, consider whether units should use this model.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_upgrades::test_an_upgrade_loads_its_base`, `test_upgrade_of_validation`, `test_an_upgrade_cycle_is_reported_once_on_its_first_card`, `test_an_upgrade_is_never_in_the_deck_the_supply_or_created` |
| AC2 | `test_an_upgrade_builds_onto_its_base_without_a_slot_or_a_worker`, `test_an_upgrade_resolves_its_play_effects`, `test_build_targets_list_every_base_that_could_take_it_in_tableau_order`, `test_an_idle_base_can_be_upgraded` |
| AC3 | `test_an_upgrade_refuses_a_target_that_isnt_its_base`, `test_a_base_takes_each_upgrade_once`, `test_an_upgrade_with_no_target_named_needs_exactly_one_base`, `test_an_upgrade_refuses_as_any_build_does`, `test_an_upgrade_needs_what_it_requires_on_its_bases_territory`, `test_a_building_that_isnt_an_upgrade_refuses_a_building_target` |
| AC4 | `test_a_base_carries_several_different_upgrades_in_build_order`, `test_upgrades_chain_one_build_at_a_time` |
| AC5 | `test_upgrades_add_to_a_working_base`, `test_a_chain_adds_while_its_root_works`, `test_upgrades_on_an_idle_base_count_for_nothing_until_it_works_again`, `test_upgrades_on_a_base_past_its_slots_count_for_nothing`, `test_a_chain_on_an_idle_root_counts_for_nothing`, `test_a_fallen_back_upgrade_adds_no_defence_or_training`, `test_a_fallen_back_upgrade_saves_no_pop_from_famine` |
| AC6 | `test_a_copy_keeps_each_upgrades_base`, `test_an_upgrades_text_says_what_it_builds_on`, `test_an_unlock_of_an_upgrade_names_its_base` |

## Log
- 2026-10-05: specced from the tall-buildings design talk (options B + restructure; see 305–307). The user chose: an
  upgrade costs 1 action like any build; a fallen-back upgrade counts for nothing and returns by itself.
- 2026-10-06: built. An upgrade is idle (`is_idle`) while the root of its chain is, so defence, training, the famine
  guard and the UI's idle look follow without changes; `fallen_back_reason` names that idle root for every link
  ("Its Chapel is idle." for a Cathedral). `Territories.buildings_on` (slots) skips upgrades. Extra test fixtures:
  Rampart (play effect, defence, training, famine guard), Weir (requires), Furrow (unlock), Spears (training).
- Follow-ups: the Build modal (297) lists an upgrade entry on a territory's view, where it is refused ("Plough builds
  on a Farm."); 302 gives upgrades their own place. The real data has no upgrades yet (305–307), so nothing shows.
  `data_loader.gd` is 636 lines and `config_loader.gd` 662, near the 700 limit.
