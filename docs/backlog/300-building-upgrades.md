---
id: 300
title: Build upgrades onto buildings: they add to their base, stack, and chain
type: feature
status: ready
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

- [ ] AC1 (loader): A building may set `upgrade_of`, another building's id. Load errors naming file, card and field: an
  unknown id ("upgrade_of: unknown card 'x'"); a card that isn't a building ("upgrade_of: 'scout' is an action"); a
  cycle, itself included, reported once on its first card in card order ("upgrade_of: cycle plough → plough"); an
  upgrade that is a project, or names one ("upgrade_of: a project can't take or be an upgrade"). `upgrade_of` on another
  type is ignored with a warning (`DataLoader.TYPE_FIELDS`). An upgrade can't be in `deck` or `supply`, or be the card of
  a `create` effect ("deck: 'plough' is an upgrade; build it from the build menu").
- [ ] AC2 (build one): Given a Farm on Homeland (pop 2, the Farm working), 1 food and 2 actions left, when
  `build("plough", farm_uid)` is called, then it returns true; food is 0; actions left is 1; a new Plough is in the
  tableau with Homeland as its territory and `upgrade_base(plough_uid)` is the Farm's uid; Homeland's `free_slots` and
  `free_workers` are what they were before; `card_played` is emitted with the Plough's uid and the Farm's uid as target,
  and its `play` effects resolve. `upgrades_on(farm_uid)` is `[plough_uid]`. `build_targets("plough")` lists every Farm
  that could take it now (whatever it costs), in tableau order; with target −1 and exactly one such Farm, `build`
  builds there. A Farm that is idle can be upgraded.
- [ ] AC3 (refusals): `build_error("plough", target)` is "" exactly when `build` would succeed, and `build` returns
  false and changes nothing otherwise. Besides 295's refusals (blocked, locked, no actions, Anarchy, short of the cost),
  each with its message: the target isn't a Farm in the tableau, a territory included ("Plough builds on a Farm."); the
  Farm already carries a Plough ("That Farm already has a Plough."); no Farm can take it, target −1 ("No Farm to build
  Plough on."); target −1 with two or more ("Choose a Farm for Plough."); an upgrade whose `requires` its base's
  territory lacks gets the requires message building it would. A non-upgrade building given a building's uid as target
  is refused as today ("That target isn't valid.").
- [ ] AC4 (stack and chain): A Farm can carry a Plough and a Ditch together, built in either order; `upgrades_on`
  lists them in build order. A second Farm can carry its own Plough. Cathedral builds on a Sanctum, never on a Chapel
  ("Cathedral builds on a Sanctum."), so a Chapel → Sanctum → Cathedral chain takes two builds; `upgrades_on(chapel)`
  is `[sanctum]` and `upgrades_on(sanctum)` is `[cathedral]`.
- [ ] AC5 (an upgrade adds while its base works): Given a Farm with a Plough and a Ditch on River (flood plain, pop 1,
  so the Farm works), then the next upkeep gains 3 food from them (Farm 1, Plough 1, Ditch 1), River's housing is 1
  more than without the Ditch, and `score()` includes the Plough's 1 VP. Given Chapel → Sanctum → Cathedral working,
  `hand_size()` is 1 more and the Cathedral's 2 VP count. When the base stops working (River's pop drops to 0, so the
  Farm is idle; or it is past its territory's slots), then its upgrades and everything built on them count for nothing:
  no upkeep effects, modifiers, housing, defence, training or famine guard, and their printed VP leaves `score()`;
  `fallen_back_reason(uid)` says why ("Its Farm is idle."; "" while it works). When the base works again, so do they,
  at no cost. `upkeep_forecast` agrees with the upkeep that follows.
- [ ] AC6 (state and text): `GameState.copy()` and `fork()` keep each upgrade's base (the suite's copy check covers the
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
| AC1 | `test_upgrades::test_…` |

## Log
- 2026-10-05: specced from the tall-buildings design talk (options B + restructure; see 305–307). The user chose: an
  upgrade costs 1 action like any build; a fallen-back upgrade counts for nothing and returns by itself.
