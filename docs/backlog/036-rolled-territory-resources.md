---
id: 036
title: Territories roll resource keywords per copy, separate from their terrain
type: feature
status: red-review
branch: feat/036-rolled-territory-resources
---

## Goal
A territory's terrain (Hills, Woodland, Bay, …) and its resources (gold, later tin and copper, …)
become separate. Terrain keywords stay printed on the card. Each copy rolls its resource keywords from
a weighted per-terrain table when the game starts. So one Hills can have gold, another nothing, and
exploring shows you the land and what's in it. Iron counts as everywhere, so it stops being a keyword.

## Acceptance criteria
<!-- Setup unless stated: TEST_CARDS + make_engine, with config resource_keywords ["gold"] and
territory_resources for Hills (printed keywords ["mountain"]). "Keywords of a territory" means
`territory_keywords(uid)`. -->
- [ ] AC1: Given `territory_resources: {"hills": [{"keywords": ["gold"], "weight": 1}]}` and
  `territory_deck: {"hills": 3}`, when the game starts, then each of the 3 Hills has keywords
  `["mountain", "gold"]` (printed first, then rolled). Given a table whose only option is
  `{"keywords": [], "weight": 1}`, each Hills has `["mountain"]`.
- [ ] AC2: Given a Hills table `[{"keywords": ["gold"], "weight": 1}, {"keywords": [], "weight": 1}]`
  and `territory_deck: {"hills": 20}`, when two engines start with the same seed, then each Hills uid has
  the same keywords in both. Some Hills in the deck have gold and some don't.
- [ ] AC3: Given a territory with no `territory_resources` entry (River, and the starting Homeland),
  when the game starts, then its keywords are exactly its printed ones (`["fresh_water", "flood_plain"]`
  for River, `[]` for Homeland). If the starting territory has a table, it rolls too: with Homeland
  `[{"keywords": ["gold"], "weight": 1}]` its keywords are `["gold"]`.
- [ ] AC4: Rolled keywords count like printed ones. Given two settled Hills, A with gold and B without,
  and a building that `requires: ["gold"]`: `valid_targets` is only A, and `play_error` on B is the
  existing "needs a territory with Gold" message. A building with an upkeep effect
  `{gain 1 wealth, keyword: "gold"}` makes +1 wealth at upkeep on A and nothing on B.
- [ ] AC5: `territory_keywords(uid)` returns a territory's keywords in every zone it can be in
  (territory_deck, reveal, frontier, tableau), and `[]` for a uid that isn't a territory.
- [ ] AC6: The loader reports an error (naming the file, and the card or table key and field) when:
  - a keyword is in both `keywords` and `resource_keywords`;
  - a territory card prints a resource keyword;
  - a `territory_resources` key isn't a territory card id;
  - an option's keyword isn't in `resource_keywords`;
  - an option's `weight` isn't an int ≥ 1;
  - a table is empty or isn't an array of `{keywords, weight}`.

  `requires` and effect `keyword` accept either kind of keyword.
- [ ] AC7: Shipped data loads with no errors or warnings and:
  - `iron` isn't a keyword;
  - Highlands prints `["mountain"]`;
  - Forge has no `requires`;
  - `gold` is a resource keyword;
  - `gold_hills` is removed and `territory_deck.hills` is 2;
  - Hills rolls `[{"keywords": ["gold"], "weight": 1}, {"keywords": [], "weight": 1}]`.

## Out of scope
- Tin and copper keywords, their payoff cards, and tables for other terrains (follow-up content item).
- Rebalancing territory slots and housing.
- Revealing resources later (e.g. only after settling). Resources are known from the start.

## Design notes
- **config.json:** new `resource_keywords` (array, validated like `keywords`); `keywords` now lists only
  terrain keywords. New `territory_resources`: `{territory_id: [{"keywords": [...], "weight": int}]}`.
- **Engine:** `CardInstance.keywords` (printed + rolled), filled when territory instances are made
  (territory deck and starting territory), using the game's seeded `rng`. `_meets_requires` and the
  keyword-effect check ([game_engine.gd:805](../../engine/game_engine.gd), `_meets_requires`) read the
  instance's keywords, not `def.keywords`. New public `territory_keywords(uid) -> Array[String]`.
- Rolling uses rng draws while the deck is built, which shifts later shuffles for a given seed. Any test
  that pins exact draw order with a territory table set may need its expected values rechecked. Tests
  without a table don't roll, so they don't change.
- **UI:** the card view and tooltip show the instance's keywords (from `territory_keywords`), with
  resource keywords told apart from terrain ones (e.g. a separate "Resources:" line).

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_territory_resources::test_each_copy_rolls_its_only_option`, `::test_empty_only_option_keeps_printed_keywords` |
| AC2 | `test_territory_resources::test_rolls_follow_the_seed`, `::test_rolls_vary_between_copies` |
| AC3 | `test_territory_resources::test_territory_without_table_keeps_printed_keywords`, `::test_starting_territory_rolls_from_its_table` |
| AC4 | `test_territory_resources::test_rolled_keyword_limits_building_targets`, `::test_rolled_keyword_effect_applies_on_that_copy`, `::test_rolled_keyword_effect_skipped_on_copy_without_it` |
| AC5 | `test_territory_resources::test_territory_keywords_in_every_zone`, `::test_territory_keywords_empty_for_non_territory` |
| AC6 | `test_territory_resources::test_valid_resource_config_loads_cleanly`, `::test_keyword_in_both_lists_is_error`, `::test_resource_keywords_must_be_array`, `::test_territory_printing_resource_keyword_is_error`, `::test_table_for_unknown_card_is_error`, `::test_table_for_non_territory_is_error`, `::test_option_with_terrain_keyword_is_error`, `::test_option_weight_must_be_positive_int`, `::test_empty_table_is_error`, `::test_option_must_be_object_with_keywords_array`, `::test_territory_resources_must_be_object` |
| AC7 | `test_content::test_real_hills_roll_gold_and_iron_is_gone` |

## Manual check
- [ ] Explore: the two revealed Hills can show different resources (one with Gold, one without).
- [ ] A settled territory's card and tooltip list its rolled Gold under Resources.
- [ ] Market's "+1 Gold" bonus shows in the forecast only when it sits on a Hills with gold.

## Log
