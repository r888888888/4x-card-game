---
id: 281
title: Settlement tiers add building slots as pop grows
type: feature
status: red-review
branch: feat/281-settlement-tiers
---

## Goal
Each settled territory has a size tier set by its pop (Hamlet, Village, Town, Metropolis on the real data). A tier is
reached automatically, costs nothing beyond the pop, and adds building slots, so growing one territory tall opens room
to build there. Housing stays with terrain and buildings, so fertile land climbs the tiers and rough land stays
small (the critique's option A + B). Government tolerance of big territories is 282; growth aiming at a threshold is 283.

## Acceptance criteria
Fixture tiers below: `[{id: hamlet, pop: 0, slots: 0}, {id: village, pop: 4, slots: 1}, {id: town, pop: 8, slots: 2},
{id: metropolis, pop: 13, slots: 3}]` (each with a `name`), on `TEST_CARDS` with population on.

- [ ] AC1: Tier from pop: given the fixture tiers and a settled Homeland, when its pop is 0, 3, 4, 7, 8, 12 and 13,
  then `tier(uid)` is 0, 0, 1, 1, 2, 2 and 3. `tier_name(uid)` is the tier's `name` ("Hamlet" … "Metropolis"), and
  `next_tier_pop(uid)` is 4, 4, 8, 8, 13, 13 and 0 (0 at the top tier). Given a config with no `population.tiers`, or
  a uid that isn't a settled territory, then `tier` is -1, `tier_name` is "" and `next_tier_pop` is 0.
- [ ] AC2: Slots: given the fixture tiers and a settled Grassland (slots 2) with no city card on it, when its pop is 3,
  4, 8 and 13, then `total_slots(uid)` is 2, 3, 4 and 5. Tier slots add to city slots: the starting Homeland (slots 5)
  with a Citadel (slots 4) at pop 4 has 10. Without tiers, Grassland at pop 13 has 2. Placing a building: Grassland at
  pop 3 with 2 buildings has no target for a third (`valid_targets` of a building in hand leaves it out). At pop 4 it is a target, and the
  third building can be played there.
- [ ] AC3: Dropping a tier idles buildings past the slots: given Grassland at pop 4 (3 slots) with 3 buildings that each
  give ⟳ +1 food, when `lose_pop` takes it to 3 (Hamlet, 2 slots), then `is_idle` is true for the building placed
  last and false for the first two. The next upkeep gains +2 food from them, not +3. The idle building keeps its
  printed VP in `score()`, `free_slots(uid)` is 0 (never negative), and `territory_summary` counts it in `idle`. When
  pop returns to 4, it works again (the next upkeep gains +3). A building idle from slots also skips its modifiers, its
  famine guard and its defence, the same as a worker-idle one.
- [ ] AC4: Slot idling and worker idling combine: given Grassland at pop 4 with 3 buildings (3 slots, 4 workers), when
  pop drops to 2, then the last building is idle for both reasons and the second is idle for workers. The count stays
  2 idle, not 3 (a building is idle when either rule says so).
- [ ] AC5: Notices: given the fixture tiers and Grassland at pop 3, when a `grow` effect takes it to 4, then the engine
  emits `noticed` once with a message naming the territory and "Village" (e.g. "Grassland grows into a Village.").
  When `lose_pop` takes it back to 3, `noticed` names "Hamlet" (e.g. "Grassland shrinks to a Hamlet."). Growing from
  4 to 5, or settling a new territory at pop 1, emits no tier notice.
- [ ] AC6: Loader: `population.tiers` is optional (absent = tiers off). When present it must be a non-empty array of
  objects, each with a unique non-empty `id`, a non-empty `name`, an int `pop` ≥ 0 and an int `slots` ≥ 0. The first
  tier's `pop` must be 0, `pop` must rise strictly from tier to tier, and `slots` must never fall. Each break is a load
  error naming `population.tiers`, the tier's index and the field. An unknown field in a tier is a warning. Real data:
  `data/config.json` loads with tiers on and at least 2 tiers (content invariant, no numbers).
- [ ] AC7: Territory status and tooltip: `territory_status(uid)` adds `tier_name` and `next_tier_pop`. The territory
  tooltip gains a line with the tier name and the pop of the next tier (e.g. "Village: a Town at 8 pop"), or just the
  tier name at the top tier, and no tier line with tiers off. The glossary's idle line says buildings past a
  territory's slots are idle too.

## Out of scope
- Unrest from big territories (282) and growth aiming at a threshold (283).
- Tiers granting housing (deliberately left out: housing stays terrain plus buildings, so tiers don't climb themselves).
- Building upgrades with tier requirements and specialists (later TODO items, which can key off `tier`).
- Re-tuning the Capital's +3 slots, territory slots or housing buildings around the new slots: a balance item. Log
  any worries below.
- Bot changes: `ScriptedBot` places buildings through `building_targets`, so it uses the new slots with no new rule.

## Design notes
- Config: `population.tiers: [{"id": "hamlet", "name": "Hamlet", "pop": 0, "slots": 0}, …]`, parsed in
  `ConfigLoader._parse_population` (`tiers` joins `famine` as a known non-int field). The normalized block holds the
  array, or `[]` when tiers are off.
- Engine API (in `EngineQueries`, logic in `Population` or a new `Tiers` helper if `population.gd` grows): `tier(uid)
  -> int`, `tier_name(uid) -> String`, `next_tier_pop(uid) -> int`. The tier is derived from pop and never stored:
  nothing new in `GameState`.
- `Territories.total_slots` adds the tier's `slots`. `free_slots` clamps at 0.
- Idle: `Population.is_idle` becomes "worker-idle or slot-idle". Slot-idle means the building's index in
  `buildings_on` is ≥ `total_slots`. Units take no slot, so only buildings can be slot-idle.
  `Modifiers.working_cards`' single pass (150) needs the same rule.
- Notices: `Population.add_pop` and `lose_pop` compare the tier before and after, and `_notice` on a change
  (`NOTICE_INFO` for growing, `NOTICE_CAUTION` for shrinking).
- Names avoid the City card type and Hunters' Camp. The tier names come from config, so UI text names no content.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_tiers::test_the_tier_follows_pop`, `test_no_tier_without_tiers_or_for_a_card_that_isnt_a_settled_territory` |
| AC2 | `test_tiers::test_a_tier_adds_its_slots`, `test_tier_slots_add_to_city_slots`, `test_without_tiers_pop_adds_no_slots`, `test_a_building_fits_the_slot_a_tier_adds` |
| AC3 | `test_tiers::test_dropping_a_tier_idles_the_building_placed_last`, `test_a_building_idle_from_slots_keeps_its_printed_vp`, `test_a_building_idle_from_slots_skips_its_modifiers_and_defence`, `test_a_building_idle_from_slots_guards_no_pop_from_famine` |
| AC4 | `test_tiers::test_slot_and_worker_idling_combine` |
| AC5 | `test_tiers::test_growing_into_a_tier_is_a_notice`, `test_shrinking_out_of_a_tier_is_a_notice`, `test_growing_within_a_tier_is_no_notice`, `test_settling_at_pop_1_is_no_notice` |
| AC6 | `test_tiers::test_tiers_load_and_are_optional`, `test_tiers_must_be_a_non_empty_array_of_objects`, `test_each_tier_needs_an_id_a_name_and_whole_pop_and_slots`, `test_tiers_start_at_pop_0_rise_strictly_and_never_lose_slots`, `test_an_unknown_tier_field_is_a_warning`; `test_content::test_population_has_at_least_2_tiers` |
| AC7 | `test_tiers::test_territory_status_names_the_tier_and_the_next_one`, `test_the_territory_tooltip_has_a_tier_line`, `test_the_territory_tooltip_has_no_tier_line_without_tiers`, `test_the_glossary_says_buildings_past_the_slots_are_idle` |

## Manual check
- [ ] Shipped tiers in `data/config.json`: Hamlet 0 (+0 slots), Village 4 (+1), Town 8 (+2), Metropolis 13 (+3).
- [ ] The territory view and its tooltip show the tier and the next threshold. Growing past 4 pop on a territory pops a
  "grows into a Village" notification, and its extra slot can take a building.

## Log
- 2026-10-04: specced from the size-tier critique. The user chose four tiers with widening bands, slots only (A + B),
  and government tolerance (D, item 282). Assumed the bot needs no new rule.
