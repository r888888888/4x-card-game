---
id: 301
title: A building or upgrade may need a settlement tier, and falls back below it
type: feature
status: red-review
branch: feat/301-buildings-need-a-tier
---

## Goal
Settlement tiers (281) add slots, but nothing on a Town does anything a Hamlet's building can't. After this, a building
or an upgrade (300) may name a **tier**: it can only be built on a territory at that tier or larger, and while its
territory is smaller it **falls back**: it counts for nothing until the territory grows back, when it works again by
itself. This is what makes the urban upgrades (Temple, Library, Merchant Quarter…) a reward for growing tall, and losing
pop a real cost. Follows 300.

## Acceptance criteria
Fixture: 300's cards and `build_menu`, with Sanctum given `"tier": "village"` and Cathedral `"tier": "town"`, plus
Forum: `{"id": "forum", "name": "Forum", "type": "building", "cost": {"food": 1}, "tier": "town", "vp": 1, "effects":
[{"op": "gain", "resource": "food", "amount": 1, "trigger": "upkeep"}]}` (in `build_menu`). Population on with the
281 fixture tiers (Hamlet 0, Village 4, Town 8, Metropolis 13), `vp_per_pop` 0, food upkeep 0.

- [ ] AC1 (loader): A building may set `tier`, the id of one of `population.tiers`. An unknown id is a load error
  naming file, card and field ("tier: unknown tier 'x'"); with tiers off (no `population.tiers`) it is ignored with a
  warning, as a government's `tolerates` is; on another type it is ignored with a warning. Card text gains the line
  "Needs a Village." (the tier's name), after "Builds on …" for an upgrade.
- [ ] AC2 (built only at the tier): Given a Chapel on Homeland at pop 3 (a Hamlet), then `build_error("sanctum",
  chapel_uid)` is "Sanctum needs a Village (Homeland is a Hamlet)." and `build_targets("sanctum")` doesn't list the
  Chapel; at pop 4 it is "" and building succeeds. Forum (a building with a tier, not an upgrade) is refused on Homeland
  below a Town with "Forum needs a Town (Homeland is a Village)." and `build_targets("forum")` leaves Homeland out; at
  pop 8 it builds and takes a slot and a worker like any building.
- [ ] AC3 (falls back): Given Chapel → Sanctum built on Homeland at pop 4, when Homeland drops to pop 3 (`lose_pop`),
  then the Sanctum counts for nothing (as 300 defines it: `hand_size()` loses its +1) and `fallen_back_reason(sanctum)`
  is "Needs a Village."; the Chapel still works. A Cathedral on that Sanctum falls back with it ("Its Sanctum has
  fallen back."). Given Forum built at pop 8, when Homeland drops to 7, then the Forum's upkeep gains no food, its 1 VP
  leaves `score()`, it still takes its slot and its worker, and `fallen_back_reason` is "Needs a Town.".
  `upkeep_forecast` agrees with the upkeep that follows.
- [ ] AC4 (returns by itself): When Homeland grows back to its tier (pop 4 for the Sanctum, 8 for the Forum), then each
  fallen-back card works again with no cost and no action, and `fallen_back_reason` is "". Nothing is removed from the
  tableau at any point.
- [ ] AC5 (notices): When a change of tier makes cards fall back, the tier notice names them, as a caution: "Homeland
  shrinks to a Hamlet. Sanctum falls back." (several: "Sanctum and Cathedral fall back."). When growing makes them work
  again, the info notice says so: "Homeland grows into a Village. Sanctum works again." A change of tier that affects
  no such card keeps 281's notice as it is.

## Out of scope
- UI: the hatched ribbon and lamp, and the Build modal's dimmed rows (302).
- Content (305–307).
- A government's `tolerates` (282) is unrelated: size unrest is still charged per tier above it.

## Design notes
- **Data format.** New building field `tier` (string, a `population.tiers` id), in `DataLoader.TYPE_FIELDS` for
  `CardDef.BUILDING`; `CardDef.tier` plus its name filled in by `ConfigLoader` (as `tolerates_name`), since `CardDef`
  has no config.
- **Rule.** A card falls back while `Population.tier(territory) < its tier`, or (300) while its base is idle or fallen
  back. Derived from pop every time, never stored, as 281's tier is. `Modifiers.working_cards` already knows each
  territory's pop in its single pass, so it can drop these cards there.
- **Building order.** A fallen-back building with a tier keeps its slot and worker (it is still built), unlike an idle
  one, which lacks them; the two can combine.
- **Notices.** `Population._notice_tier` already fires on each tier change; it appends the cards that fell back or came
  back on that territory (tableau order).

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_building_tiers::test_a_building_loads_its_tier`, `test_tier_validation`, `test_a_tiers_text_names_it_after_the_upgrade_line`, `test_with_tiers_off_a_tier_is_ignored` |
| AC2 | `test_an_upgrade_with_a_tier_builds_only_where_its_base_stands_at_that_tier`, `test_a_building_with_a_tier_builds_only_on_a_territory_at_that_tier` |
| AC3 | `test_an_upgrade_below_its_tier_falls_back_and_its_upgrades_with_it`, `test_a_cathedral_falls_back_with_its_sanctum`, `test_a_building_below_its_tier_falls_back_but_keeps_its_slot_and_worker` |
| AC4 | `test_fallen_back_cards_work_again_when_the_territory_grows_back` |
| AC5 | `test_shrinking_names_the_cards_that_fall_back`, `test_growing_names_the_cards_that_work_again`, `test_a_tier_change_that_affects_no_such_card_keeps_its_notice` |

## Log
- 2026-10-05: specced with 300. The user chose: a fallen-back card counts for nothing (no housing, no printed VP) and
  returns by itself when the territory grows back.
