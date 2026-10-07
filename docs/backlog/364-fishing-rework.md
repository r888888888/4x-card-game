---
id: 364
title: Fishing Huts feed and house a coastal city, with Salt Pans and Net Fishing
type: feature
status: red-review
branch: feat/364-fishing-rework
---

## Goal
Fishing Huts are a worse Farm: the same cost (1 food, 2 wealth) for half the food, competing for the same slot on
three of the four coastal territories, and the coast has no era-1 upgrade path while farms get Irrigation and The
Plough. Give fishing its own shape: huts are cheap and house people, each one puts a Net Fishing action in the deck,
Pottery opens Salt Pans that pay off per hut in their own city, and the Harbor keeps the catch. Mostly content; the
one engine change is that `gain_per_tag` can count only the cards on its own territory. Numbers are a first guess until
a balance item.

## Acceptance criteria
- [ ] AC1: Given a fixture building whose play effect is `create` of a fixture action into the `deck`, when it is
  built twice (on territories with room and workers), then the deck holds 2 more copies of that action than before,
  and the discard and hand are unchanged.
- [ ] AC2: Given a fixture building on territory A with ⟳ `{ "op": "gain_per_tag", "resource": "food", "amount": 1,
  "tag": "t", "here": true, "trigger": "upkeep" }`, 2 working buildings tagged `t` on A and 3 on territory B, when
  upkeep resolves, then food rises by 2 from it, and `upkeep_forecast` reports that beforehand. If one of the `t`
  buildings on A is idle (past A's pop), it gains 1. Without `here` (or `here: false`) it counts all 5, as today.
- [ ] AC3: Given a card whose `gain_per_tag` sets `here` to something other than a boolean, or sets `here: true` with
  a `zone` other than `tableau`, then loading fails with an error naming the card and the field.
- [ ] AC4: Given `here: true`, then the short card text is "+1 food per t here" and the long text "+1 food per t card
  on this territory"; without `here` both read as today.
- [ ] AC5 (invariant): Every tag a `gain_per_tag` effect in the real data counts is carried by at least one card the
  player can come to have (a build-menu entry, a deck or supply card, a card some effect creates, or a civilization's
  starting card). The failure names the counting card and the tag.
- [ ] AC6 (invariant): Every card a building's effect creates in the real data is an action card. The failure names
  the building and the card.

## Out of scope
- The sea slot (366); Sea Trade and the insight from ports (367); coastal events and the Lighthouse (365).
- Balance tuning (the sim and the `balance` skill).

## Design notes
- Format: `gain_per_tag` gains an optional boolean `here` (default false). With it, it counts only the working
  (not idle, not fallen back) cards with the tag on its own card's territory, and `needs_own_territory()` is true
  (it gains nothing on a card with no territory, as `gain_per_pop` does). `here` needs `zone` to be `tableau`. Follow
  the `add-effect` skill's checklist for a changed op (loader tests, rules tests, card text).
- Otherwise no engine change: buildings already resolve their `play` effects when built (`CardPlay.put_into_play`),
  `create` takes `zone: "deck"`, and buildings take `housing`. AC1 may pass at once; it pins the rule Net Fishing
  relies on. AC5 and AC6 may also pass at once; they guard the new content. AC5 widens
  `test_every_per_keyword_and_per_tag_event_effect_can_fire`'s tag check (events only, no build menu) to every card. Existing content
  tests already hold Salt Pans to a coastal territory in play (`test_every_building_requirement_is_met_by_a_territory_in_play`)
  and the food-cost rule (`test_only_food_buildings_cost_food_and_at_most_1`).
- Content changes in `data/cards.json` and `data/config.json`:
  - **Fishing Huts**: cost 2 wealth (no food), `housing: 1`, tags `["port", "fishing"]`, keeps ⟳ +1 food and its
    `requires` (coastal or marsh). New play effect: `{ "op": "create", "card": "net_fishing", "zone": "deck" }`, so
    each hut built adds one Net Fishing.
  - **Net Fishing** (`net_fishing`): new action, no cost, no VP, play: `gain_per_keyword` +1 food per `coastal`
    territory. Not in the starting deck or the supply.
  - **Salt Pans** (`salt_pans`): new building, `requires: ["coastal"]`, tags `["port"]` (so it can take the sea slot
    in 366), ⟳ `gain_per_tag` +1 food per `fishing` card `here` (only the huts on its own territory).
    Locked in the build menu; Pottery unlocks it.
  - **Harbor**: adds ⟳ +1 food to its +2 wealth.
  - Flavor for Net Fishing and Salt Pans follows the style guide §18.
- Salt Pans improves only the huts in its own city (the user's call), and only working ones: an idle hut catches
  nothing to salt.
- 367 later adds `per` to the same op; the two fields are independent.
- PLAN.md: update the rural-building and Pottery lines.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_build_menu::test_each_building_built_adds_the_card_its_play_effect_creates_to_the_deck` (passes already) |
| AC2 | `test_gain_per_tag::test_here_counts_only_the_tagged_cards_on_its_own_territory`, `test_here_skips_an_idle_tagged_card`, `test_without_here_every_tagged_card_counts` (passes already: today's behaviour) |
| AC3 | `test_gain_per_tag::test_here_validation`, `test_here_on_a_card_with_no_territory_is_a_load_error` |
| AC4 | `test_gain_per_tag::test_here_card_text` |
| AC5 | `test_content::test_every_gain_per_tag_tag_is_on_a_reachable_card` (exists since 132) |
| AC6 | `test_content::test_every_card_a_building_creates_is_an_action` (passes already) |

## Manual check
- [ ] Shipped numbers: Fishing Huts costs 2 wealth, ⟳ +1 food, housing 1; Net Fishing +1 food per coastal territory;
  Salt Pans (cost about 3 wealth) ⟳ +1 food per Fishing Huts on its territory; Harbor ⟳ +1 food, +2 wealth.
- [ ] Card text reads right: Fishing Huts says it adds a Net Fishing to your deck; Salt Pans says "+1 food per
  fishing here".
- [ ] In a game on Cedar Coast, build Fishing Huts: a Net Fishing turns up in a later hand; research Pottery and Salt
  Pans appears in the Build menu only for coastal territories.

## Log
<!-- Decisions and surprises during implementation, newest last. -->
- Balance worry (for a balance item): Net Fishing copies grow with huts, and each pays per coastal territory, so a
  wide coastal empire gets huts × coastal territories in food per cycle. Salt Pans stays per territory, so it rewards tall coastal cities instead.
