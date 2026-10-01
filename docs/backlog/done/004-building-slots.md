---
id: 004
title: Buildings occupy territory slots
type: feature
status: done
branch: feat/004-building-slots
---

## Goal
Each building is placed in a settled territory with a free slot, and the player picks which one.
Running out of slots pushes the player to explore and settle again.

## Acceptance criteria
In these criteria, Capital is on Grassland (2 slots) and Farm costs 2.

- [x] AC1: Given only Grassland settled, with 0 buildings, when I play Farm with no target, then Farm is in
  the tableau, `territory_of(farm)` is Grassland, and `free_slots(grassland)` is 1. The Capital (a city)
  does not use a slot, so `free_slots` was 2 before.
- [x] AC2: Given Grassland holding 2 buildings and no other settled territory, when I try to play Farm, then
  `play_error` is "No territory with a free slot.", the card stays in hand, and food is unchanged.
- [x] AC3: Given Grassland and Hills both settled with free slots, when I play Farm with no target, then
  `play_error` is "Choose a territory for Farm." When I play it targeting Hills, then it is placed on Hills.
- [x] AC4: Given a full Grassland and Hills with a free slot, `valid_targets(farm)` is [hills]. Playing Farm
  with no target auto-places it on Hills. Targeting Grassland gives "That target isn't valid."
- [x] AC5: Territories in the frontier are never valid building targets.

## Out of scope
- Keyword requirements (005).
- Demolishing or moving buildings.

## Design notes
- **Engine API:** `free_slots(territory_uid) -> int` counts buildings whose `territory_uid` matches.
  Cities don't count.
- **Decided (user, 2026-09-28): territories are mandatory for building. There is no legacy mode.**
  - The default test config (`raw_config` in `tests/lib/test_case.gd`) gets
    `starting.territory: "homeland"`, a TEST_CARDS territory with 5 slots and no keywords.
  - `test_new_game_setup`'s tableau assertion changes from `["capital"]` to `["homeland", "capital"]`.
    This edit to an approved test is pre-approved by the user.
  - A Capital with no territory can't hold buildings ("No territory with a free slot.").
  - **Also affected (not covered by the pre-approval above; approve with this item):** three more tests
    check the exact tableau, and each gains `homeland` in front:
    - `test_rules::test_play_building_pays_and_produces`: `["capital", "farm"]` becomes
      `["homeland", "capital", "farm"]`
    - `test_rules::test_create_card`: `["capital", "city"]` becomes `["homeland", "capital", "city"]`
    - `test_play_outcome::test_created_card_reported_in_outcome`: same change, and the new City is at
      tableau index 2 instead of 1
  - A building's `card_played` outcome now has `target` set to the territory it was placed on (003 AC7).
- **UI (drag interface, 008):**
  - each territory group shows used/total slots
  - **Drop onto a territory group:** a whole group (the territory card plus its city and buildings) is a
    drop target, not just the territory card, so it's easy to hit. Only groups in `valid_targets` light up.
  - **Outline:** the ghost outline showing where the building will land appears inside the group under the
    cursor. Today it sits at the end of the tableau.
  - **One valid territory:** dropping anywhere in the tableau places it there, and the outline shows in that group
    from the moment the card is picked up.
  - **Invalid group** (full, or in 005 missing a keyword): hovering it turns the card red and shows
    `play_error(uid, target_uid)`. Dropping there shakes the card back.
  - **Double-click** uses 003's targeting mode when there are several valid territories.

## Test plan
All in `tests/test_slots.gd`.

| AC | Test |
|---|---|
| AC1 | `test_building_goes_on_only_territory_with_room` |
| AC2 | `test_building_with_no_free_slot_fails` |
| AC3 | `test_building_needs_a_choice_with_several_territories`, `test_building_placed_on_chosen_territory` |
| AC4 | `test_full_territory_is_not_a_target` |
| AC5 | `test_frontier_territory_is_not_a_target` |
| Design note (outcome target) | `test_building_outcome_target_is_its_territory` |

## Manual check
- [ ] Slot counts show on each territory group.
- [ ] With two territories with free slots, picking up a Farm lights up both groups. The outline follows
  the group under the cursor, and dropping puts the Farm there.
- [ ] A full territory isn't lit up. Hovering the Farm over it turns the card red with
  "That target isn't valid.", and dropping shakes it back.

## Log
- 2026-09-28: red. `homeland` (5 slots) added to `TEST_CARDS` and made the default `starting.territory`.
  Interface-only `free_slots` returning 0 committed with the tests. Existing tests edited:
  - listed in the design notes: `test_new_game_setup`, `test_play_building_pays_and_produces`,
    `test_create_card`, `test_created_card_reported_in_outcome`;
  - not listed (need approval): `test_territories::base_cards` keeps `homeland`;
    `test_config_without_territories_loads_cleanly` and `test_game_without_territories_is_unchanged`
    override `starting` with no territory; `test_settle_on_invalid_target_fails` expects
    `["homeland", "capital"]`; `test_untargeted_card_has_no_targets_and_ignores_one` and
    `test_outcome_target_for_untargeted_card` use Shrine instead of Farm (Farm now needs a target).
- 2026-09-28: green. Buildings are targeted cards: `_needs_target` covers `building` type or a targeting
  effect; `valid_targets` for a building is the settled territories with `free_slots > 0`. The two
  target error messages moved to helpers.
- UI: each group shows "used / total slots used"; groups are drop targets (lit when valid); the ghost
  sits in the lit group under the cursor (or the only lit group). Double-click with several
  territories reuses 003's targeting mode (click the territory card).
- Follow-up: in targeting mode only the territory card is clickable, not the whole group.
