---
id: 364
title: Fishing Huts feed and house a coastal city, with Salt Pans and Net Fishing
type: feature
status: in-progress
branch: feat/364-fishing-rework
---

## Goal
Fishing Huts are a worse Farm: the same cost (1 food, 2 wealth) for half the food, competing for the same slot on
three of the four coastal territories, and the coast has no era-1 upgrade path while farms get Irrigation and The
Plough. Give fishing its own shape: huts are cheap and house people, each one puts a Net Fishing action in the deck,
Pottery opens Salt Pans as an upgrade on a hut (the coast's era-1 upgrade, like the Farm's), and the Harbor keeps the
catch. Content only; numbers are a first guess until a balance item.

## Acceptance criteria
- [ ] AC1: Given a fixture building whose play effect is `create` of a fixture action into the `deck`, when it is
  built twice (on territories with room and workers), then the deck holds 2 more copies of that action than before,
  and the discard and hand are unchanged.
- [ ] AC2 (invariant): Every card a building's effect creates in the real data is an action card. The failure names
  the building and the card.
- [ ] AC3: The existing upgrade invariants hold with Salt Pans, in particular
  `test_every_upgrade_and_its_base_are_build_menu_entries_opened_by_a_tech`,
  `test_every_upgrade_can_stand_on_some_territory` (a coastal territory takes both Fishing Huts and Salt Pans) and
  `test_no_upgrade_opens_before_its_base`.

## Out of scope
- The sea slot (366); Sea Trade and the insight from ports (367); coastal events and the Lighthouse (365).
- Balance tuning (the sim and the `balance` skill).

## Design notes
- No engine or format change: buildings already resolve their `play` effects when built (`CardPlay.put_into_play`),
  `create` takes `zone: "deck"`, buildings take `housing`, and an upgrade may set `requires` (as Harbor does). AC1
  and AC2 pass at once; they pin the rule Net Fishing relies on and guard the new content.
- Content changes in `data/cards.json` and `data/config.json`:
  - **Fishing Huts**: cost 2 wealth (no food), `housing: 1`, keeps its `port` tag, ⟳ +1 food and its `requires`
    (coastal or marsh). New play effect: `{ "op": "create", "card": "net_fishing", "zone": "deck" }`, so each hut
    built adds one Net Fishing.
  - **Net Fishing** (`net_fishing`): new action, no cost, no VP, play: `gain_per_keyword` +1 food per `coastal`
    territory. Not in the starting deck or the supply.
  - **Salt Pans** (`salt_pans`): new upgrade, `upgrade_of: "fishing_huts"`, `requires: ["coastal"]`, no tags, no
    tier, ⟳ +1 food. Locked in the build menu; Pottery unlocks it. As an upgrade it takes no slot or worker and
    improves only the hut it is built on, so it stays in its own city; a hut can carry both Salt Pans and a Harbor.
  - **Harbor**: adds ⟳ +1 food to its +2 wealth.
  - Flavor for Net Fishing and Salt Pans follows the style guide §18.
- Salt Pans was first specced as a stand-alone building counting the huts in its city (`gain_per_tag` with a new
  `here` field); the user chose an upgrade instead, so the op is unchanged.
- PLAN.md: update the rural-upgrade (305) and Pottery lines.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_build_menu::test_each_building_built_adds_the_card_its_play_effect_creates_to_the_deck` (passes already) |
| AC2 | `test_content::test_every_card_a_building_creates_is_an_action` (passes already) |
| AC3 | the existing `test_content` upgrade invariants named in AC3 |

## Manual check
- [ ] Shipped numbers: Fishing Huts costs 2 wealth, ⟳ +1 food, housing 1; Net Fishing +1 food per coastal territory;
  Salt Pans (cost about 2 wealth) ⟳ +1 food on its hut; Harbor ⟳ +1 food, +2 wealth.
- [ ] Card text reads right: Fishing Huts says it adds a Net Fishing to your deck; Salt Pans says it builds on a
  Fishing Huts.
- [ ] In a game on Cedar Coast, build Fishing Huts: a Net Fishing turns up in a later hand; research Pottery and the
  hut offers "+ Upgrade" Salt Pans; on a marsh-only territory (Reed Marsh) it doesn't.

## Log
<!-- Decisions and surprises during implementation, newest last. -->
- Balance worry (for a balance item): Net Fishing copies grow with huts, and each pays per coastal territory, so a
  wide coastal empire gets huts × coastal territories in food per cycle. Salt Pans adds a flat +1 per hut it is built on.
