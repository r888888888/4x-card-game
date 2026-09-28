---
id: 030
title: Capital adds 4 building slots to its territory
type: feature
status: in-progress
branch: feat/030-capital-slots
---

## Goal
The Capital makes its home territory a real hub: the territory it sits on gets 4 extra building
slots, so the starting territory isn't full after a few buildings.

## Acceptance criteria
In these criteria the Capital sits on a territory with 2 slots and has `slots: 4`; Farm costs 2.
Other settled Cities have no `slots`.

- [ ] AC1: Given the Capital on a 2-slot territory with 0 buildings, then `total_slots(territory)` is 6 and
  `free_slots(territory)` is 6.
- [ ] AC2: Given that territory with 5 buildings, then `free_slots` is 1 and playing a Farm targeting it
  succeeds; with 6 buildings `free_slots` is 0 and `play_error` for Farm is "No territory with a free slot."
  when it is the only settled territory.
- [ ] AC3: Given a second settled territory with a City (no `slots`), then its `total_slots` is just its
  own card's `slots`. The Capital's bonus applies only to the territory the Capital sits on.
- [ ] AC4: Given the Capital's territory, then `housing(territory)` is unchanged by the bonus
  (still the territory card's `housing`).
- [ ] AC5: Given a City card with `slots` in `cards.json`, the loader accepts it and reads it as an int >= 0.
  A negative or non-integer `slots` is an error naming the file, card and field. A territory
  card's `slots` behavior is unchanged, and `slots` on any other card type still warns
  "only applies to territories (ignored)".
- [ ] AC6: Given the real `data/cards.json`, the Capital has `slots: 4`.

## Out of scope
- Housing changes (decided: slots only).
- Other cards granting slots (buildings, techs). The field is only for `city` cards.
- Rebalancing the territory deck or building costs.

## Design notes
- **Decided (user, 2026-09-28):** slots only, no housing bonus; the bonus is a `slots` field on the city card,
  not an engine special case for `capital`.
- **Data:** `city` cards may set `slots` (int >= 0, default 0). Loader: read it for `city` too; keep the
  warning for other non-territory types.
- **Engine API:** `total_slots(territory_uid) -> int` = territory card `slots` + sum of `slots` of cities
  on it (0 if not settled). `free_slots` becomes `total_slots - buildings`.
- **UI:** the territory group's "used / total slots used" (`ui/main.gd`) and the territory card's
  `▢N` mark should use `total_slots`, so they show 6, not 2. Card tooltip text for the Capital says
  "+4 building slots on its territory".
- The starting Capital already gets `territory_uid` = its home territory at setup (game_engine.gd), so the
  engine can find a territory's cities by that field. Cities founded by Settle should be checked the same way.

## Test plan
<!-- Filled in by the tdd skill at the red checkpoint. -->
| AC | Test |
|---|---|
| AC1 | `test_slots::test_city_slots_add_to_its_territory`, `test_total_slots_of_a_non_territory_is_0` |
| AC2 | `test_slots::test_city_slots_are_usable_up_to_the_total` |
| AC3 | `test_slots::test_city_slots_apply_only_to_its_own_territory` |
| AC4 | `test_slots::test_city_slots_do_not_change_housing` (guard, passes already) |
| AC5 | `test_data_loader::test_city_slots_loads`, `test_city_slots_must_be_a_non_negative_integer`, `test_slots_on_a_building_still_warns` (guard) |
| AC6 | `test_content::test_capital_adds_4_building_slots` |

## Manual check
- [ ] New game: the Capital's territory group shows "0 / 6 slots used" and lets me place 6 buildings.
- [ ] The Capital's tooltip mentions the +4 slots.

## Log
