---
id: 081
title: gain_per_keyword op (gain per settled territory with a keyword) and Hunt
type: feature
status: done
branch: feat/081-gain-per-keyword-op
---

## Goal
Cards can scale with the kind of land the player has settled: "+1 food per forest or grassland territory".
The effect-level `keyword` condition only looks at a card's own territory, so actions and techs, which have
none, can't do this today. This adds a first early action that rewards expanding onto a given kind of land.

## Acceptance criteria
<!-- Rules criteria use TEST_CARDS: homeland (no keywords), hills [mountain], river [fresh_water, flood_plain],
grassland (no keywords). Add a test action, e.g. `hunt`: {"op": "gain_per_keyword", "resource": "food",
"amount": 1, "keywords": ["mountain", "fresh_water"]}. -->
- [x] AC1 (count): Given homeland plus settled hills and river, and 0 food, when an action with
  `gain_per_keyword` food, amount 1, keywords `["mountain", "fresh_water"]` is played, then food is 2.
  With amount 2, food is 4.
- [x] AC2 (any-of, once each): Given homeland plus settled river only, when an action with keywords
  `["fresh_water", "flood_plain"]` and amount 1 is played, then food is 1: river has both keywords but counts
  once.
- [x] AC3 (only settled): Given hills in the frontier (not settled) and nothing else settled besides homeland,
  when the action from AC1 is played, then food is 0 and the play still succeeds (it goes to discard).
- [x] AC4 (resource keywords): Given a settled territory copy whose rolled `keywords` include `gold`, and an
  effect with keywords `["gold"]` and amount 1, then the gain is 1 (the copy's keywords are checked, printed plus rolled).
- [x] AC5 (upkeep): `upkeep_ok()` is true. Given a building with an `upkeep` `gain_per_keyword` wealth 1 per
  `["mountain"]` and settled hills, then `upkeep_forecast().wealth` includes the +1 and the next upkeep gives it.
- [x] AC6 (loader and text): `keywords` must be a non-empty list of known keywords (config `keywords` or
  `resource_keywords`). A missing or empty list, a non-list, or an unknown keyword is a load error naming the file,
  the card and the `keywords` field. `amount` defaults to 1 and must be an int ≥ 1. The short text reads
  "+1 food per mountain or fresh water territory".
- [x] AC7 (content): the real data has an `action` `hunt` whose effect is `gain_per_keyword` food. It is in an
  unlocked supply pile or the starting deck, and every keyword it lists is on some territory in `territory_deck`.

## Out of scope
- Counting keywords on buildings or cities (only territories in the tableau count).
- Changing the existing effect-level `keyword` condition.
- UI changes beyond the generated card text.

## Design notes
- New op `gain_per_keyword` (follow the `add-effect` skill): fields `resource`, `amount` (default 1),
  `keywords` (Array[String], any-of). The loader needs the keyword lists in its effect ctx, if they aren't
  already there.
- Settled = a territory card in `tableau`. The Capital's territory counts.
- New engine query `count_territories_with(keywords: Array[String]) -> int` (public, for the effect and the UI).
- Planned content (Manual check): `hunt`: action, free, +1 food per `forest` or `grassland` territory, supply price 2,
  count 2. River Meadow (the starting territory) has `grassland`, so Hunt gives at least +1 from turn 1.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_gain_per_keyword::test_gains_amount_per_settled_territory_with_a_keyword`, `::test_count_territories_with_query` |
| AC2 | `test_gain_per_keyword::test_a_territory_with_several_listed_keywords_counts_once` |
| AC3 | `test_gain_per_keyword::test_frontier_territories_do_not_count` |
| AC4 | `test_gain_per_keyword::test_rolled_resource_keywords_count` |
| AC5 | `test_gain_per_keyword::test_upkeep_gain_per_keyword_is_forecast_and_given`, `::test_gain_per_keyword_may_trigger_on_upkeep`, `test_forecast::test_upkeep_safe_ops_may_trigger_on_upkeep` (row added to `UPKEEP_SAFE`) |
| AC6 | `test_gain_per_keyword::test_gain_per_keyword_loads`, `::test_gain_per_keyword_validation`, `::test_gain_per_keyword_card_text` |
| AC7 | `test_content::test_hunt_gains_food_per_keyword_and_is_available_from_the_start` |

## Manual check
Run `godot --path .`, start any seed, and open the Supply screen (or draw the starting Hunt).
- [ ] Hunt's face reads "+1 food per forest or grassland territory"; hovering shows "+1 food for each settled
  territory with Forest or Grassland"; its details modal reads cleanly.
- [ ] Playing it on turn 1 gives +1 food (the starting territory has grassland).
- [x] Numbers reviewed with the sim (Log).

## Log
- 2026-09-29: Red at 561 tests (was 550), 12 failing. Fixtures are local to `test_gain_per_keyword.gd`, not in
  `TEST_CARDS`, so other tests load while the op is missing. Renamed
  `test_forecast::test_gain_gain_per_tag_score_and_grow_may_trigger_on_upkeep` to `test_upkeep_safe_ops_may_trigger_on_upkeep`
  (it now covers five ops).
- Approved at red. Green: `gain_per_keyword_effect.gd` and `GameEngine.count_territories_with`.
- Hunt shipped as planned (free, +1 food per forest or grassland, supply price 2, count 2), plus **1 copy in the
  starting deck**, not in the plan: `test_every_supply_pile_starts_in_the_deck_or_is_unlocked_by_a_tech` requires an
  unlocked action pile to start in the deck. The alternative, relaxing that test to any unlocked pile, is the user's
  call (asked at close).
- Sim (20 seeds), main → this: score 76.90 (49–93) → 78.85 (60–98); techs 12.00 → 12.20; cities 10.90 → 11.00;
  pop 12.90 → 13.00; era 2 → 2.
