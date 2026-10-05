---
id: 296
title: Recruit units from the build menu
type: feature
status: ready
branch: feat/296-recruit-units-from-build-menu
---

## Goal
Units work like buildings after 295: not cards you buy and draw, but build-menu entries that techs unlock and that you
recruit straight onto a settled territory for 1 action plus their cost. Warriors can be recruited from turn 1, so the
early raids still have an answer (285's reason for a Warriors card in the starting deck). A unit that leaves play
(disbanded, or lost to a pillage) is gone; you recruit a new one. Follows 295.

## Acceptance criteria
- [ ] AC1: Given `build_menu` `{"warriors": {}}` (a unit, strength 2, cost 2 food), a settled territory with a free
  worker and no free slot, 1 action and 2 food, when `build("warriors", territory)` is called, then it returns true; a
  new Warriors is in the tableau homed and stationed on that territory (`unit_station` is the territory), using a
  worker there but no slot; food is 0, no actions are left, and `card_played` is emitted. Its strength counts toward
  that territory's `defense`.
- [ ] AC2: Given that setup but no territory with a free worker, `build_error("warriors")` is "No territory with a
  free worker." and `build` changes nothing. A unit entry ignores slots and terrain: `build_targets` lists every
  settled territory with a free worker (as `unit_targets` does for a unit card). The other refusals are 295's AC2.
- [ ] AC3: Given a Warriors recruited from the build menu, when it is disbanded, then it is in no zone (not the
  discard: it can't come back through the deck), its worker is free again, and Warriors can be recruited again. When a
  raid pillages the territory it is stationed on, it likewise leaves play, and the raid outcome's `units_lost` still
  lists its uid.
- [ ] AC4: Given a unit card with no build-menu entry (a unit in the deck, as rules fixtures use), when it is
  disbanded or pillaged, then it goes to the discard as today.
- [ ] AC5: An `unlock` of a unit entry logs "Warriors can now be recruited." and its card text reads the same; a
  locked unit entry is refused with "Warriors isn't unlocked yet." (295's locked message).
- [ ] AC6: Content (real data): no unit is in `deck` or `supply`; every unit has a build-menu entry; at least one unit
  entry is unlocked from turn 1, and the starting resources pay for it.

## Out of scope
- The Build… UI (297); the bot (298).
- New units and which techs unlock them: 167 (military content) supplies them as build-menu entries.
- Upgrading a unit in place (166), veterans (165).

## Design notes
- Units share 295's action: `build(card_id, territory)` recruits a unit entry. The UI says "Recruit" for a unit (297);
  the log line is the play step's, as for buildings.
- "Leaves play" needs a rule for build-menu units in `Military.disband` and the pillage step (`engine/military.gd`):
  remove the card instead of moving it to the discard when its id has a build-menu entry. Units with no entry keep
  today's rule (AC4), so the rules fixtures and 163's tests stand.
- Data: Warriors moves from `deck` (1) and `supply` (price 2, 6 copies) to an unlocked entry `"warriors": {}`.
- Disband's details text ("Send it to your discard; its worker is freed.") must change for build-menu units, e.g.
  "Dismiss it; its worker is freed." (297 or here; this item owns the engine side only, the UI wording is 297's).
- **Items to revise when this lands:** 166 (upgrades pay "the difference in cost" for a unit a tech unlocks: still
  fits, but the unlocked unit is a build-menu entry, not a supply pile), 167 (era units "opened by techs" become locked
  unit entries), 168 (the bot's cheapest defence becomes recruiting a unit entry or moving one).

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_units::test_…` |

## Log
