---
id: 081
title: gain_per_keyword op (gain per settled territory with a keyword) and Hunt
type: feature
status: ready
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
- [ ] AC1 (count): Given homeland plus settled hills and river, and 0 food, when an action with
  `gain_per_keyword` food, amount 1, keywords `["mountain", "fresh_water"]` is played, then food is 2.
  With amount 2, food is 4.
- [ ] AC2 (any-of, once each): Given homeland plus settled river only, when an action with keywords
  `["fresh_water", "flood_plain"]` and amount 1 is played, then food is 1: river has both keywords but counts
  once.
- [ ] AC3 (only settled): Given hills in the frontier (not settled) and nothing else settled besides homeland,
  when the action from AC1 is played, then food is 0 and the play still succeeds (it goes to discard).
- [ ] AC4 (resource keywords): Given a settled territory copy whose rolled `keywords` include `gold`, and an
  effect with keywords `["gold"]` and amount 1, then the gain is 1 (the copy's keywords are checked, printed plus rolled).
- [ ] AC5 (upkeep): `upkeep_ok()` is true. Given a building with an `upkeep` `gain_per_keyword` wealth 1 per
  `["mountain"]` and settled hills, then `upkeep_forecast().wealth` includes the +1 and the next upkeep gives it.
- [ ] AC6 (loader and text): `keywords` must be a non-empty list of known keywords (config `keywords` or
  `resource_keywords`). A missing or empty list, a non-list, or an unknown keyword is a load error naming the file,
  the card and the `keywords` field. `amount` defaults to 1 and must be an int ≥ 1. The short text reads
  "+1 food per mountain or fresh water territory".
- [ ] AC7 (content): the real data has an `action` `hunt` whose effect is `gain_per_keyword` food. It is in an
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
| AC1 | `test_effects::test_…` |

## Manual check
- [ ] Hunt's card text and details modal read cleanly; its numbers are reviewed with the `balance` skill.

## Log
