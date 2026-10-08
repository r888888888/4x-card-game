---
id: 368
title: Hunters' Camp adds the one Hunt, which pays for forest only
type: feature
status: done
branch: feat/368-hunt-from-hunters-camp
---

## Goal
Hunt is in the starting deck and on sale from turn 1, but it pays +1 food per forest or grassland territory, so for
four of the six civs (Egypt, Sumer, Greece, Persia) it opens as a dead card. Make it the Hunters' Camp's action, the
way Net Fishing is the Fishing Huts' (364): the first Hunters' Camp you build puts the one Hunt in your deck, and Hunt
pays for forest only, the terrain the camp stands on. Hunters' Camp gains a reason to be built. Content only: the
unique `create` exists since 364.

## Acceptance criteria
- [x] AC1 (invariant): Every card a building's effect creates in the real data is reachable and is not in the starting
  deck or the supply: a card a building brings isn't also dealt or bought. The failure names the building and the card.
- [x] AC2 (invariant): Every `create` in a building's effect in the real data whose card is an action is `unique`
  (one copy however many of the building you build). The failure names the building and the card.
- [x] AC3: The existing invariants hold with the change, in particular `test_every_real_card_can_reach_a_game`
  (Hunt is reached through the Hunters' Camp in the build menu), `test_every_card_a_building_creates_is_an_action`,
  `test_every_keyword_is_on_a_territory_and_a_card` and `test_every_gain_per_keyword_keyword_is_on_a_territory_in_play`.

## Out of scope
- Balance: the starting deck drops from 8 cards to 7, and the opening food changes for Phoenicia and Babylon. A
  later balance item retunes (the user's call).
- A grassland action to replace Hunt's grassland payout (Pasture under Animal Husbandry is the natural home).
- The Scout change in `docs/TODO.md` (one Scout, a second from Animal Husbandry): its own item.

## Design notes
- No engine, loader or format change. AC1 and AC2 may pass at once once the data is changed; they guard the rule
  "a building's action comes only from the building, one copy" against later content.
- Content changes:
  - `data/cards.json`, **Hunters' Camp**: add the play effect
    `{ "op": "create", "card": "hunt", "zone": "deck", "unique": true }` (after its upkeep food and score). Timber
    Camp, its upgrade, is unchanged; the Hunt stays in the deck after an upgrade.
  - `data/cards.json`, **Hunt**: `keywords` becomes `["forest"]`.
  - `data/config.json`: remove `hunt` from `deck` and from `supply`.
- Animal Husbandry's eureka (build a Hunters' Camp) is unchanged.
- The bot sees the Hunt through the building's create the same way it sees Net Fishing (364).
- PLAN.md: the starting-deck line (402) is stale (it lists Farm 3 and Hunters' Camp 2, which the config no longer
  deals); rewrite it from `data/config.json` and say Hunters' Camp adds the one Hunt. Update the Hunt line at 110
  if it names the keywords.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_content::test_every_card_a_building_creates_comes_only_from_the_building` |
| AC2 | `test_content::test_every_action_a_building_creates_is_unique` |
| AC3 | existing: `test_every_real_card_can_reach_a_game`, `test_every_card_a_building_creates_is_an_action`, `test_every_keyword_is_on_a_territory_and_a_card`, `test_every_gain_per_keyword_keyword_is_on_a_territory_in_play` (whole suite) |

## Manual check
- [ ] Shipped data: Hunt is in neither the starting deck nor the supply; Hunt reads +1 food per forest territory;
  Hunters' Camp costs 1 food, 2 wealth, ⟳ +1 food, 1 VP, and adds a Hunt.
- [ ] Card text: Hunters' Camp says it adds a Hunt to your deck if you have none.
- [ ] Start as Phoenicia (home Cedar Coast, forest): `godot --path . -- --civ phoenicia --seed 5`. No Hunt in the
  opening hands and none in the market. Build two Hunters' Camps: one Hunt (only one) turns up in a later hand and
  pays 1 food per forest territory.

## Log
<!-- Decisions and surprises during implementation, newest last. -->
- Balance worry (for the balance item): the starting deck is 7 cards; Babylon loses its opening grassland Hunt
  food and Phoenicia its forest Hunt food until a camp is built.
- Red: AC1 and AC2 pass on today's data (only Fishing Huts creates, and correctly), as the Design notes expected.
  Checked they bite: adding a non-unique `create hunt` to Hunters' Camp with Hunt still dealt fails both, naming
  `hunters_camp creates hunt`.
- Green: data change only (cards.json, config.json); suite 2316 → 2318. PLAN.md's starting-deck line rewritten from
  config (it also still listed Warriors, which is in the build menu now) and the `gain_per_keyword` example.
- Follow-up: Hunt's flavor speaks of herds in "the long grass", grassland imagery for a now forest-only card.
