---
id: 001
title: Territory cards and the Capital's starting territory
type: feature
status: review
branch: feat/001-territory-cards
---

## Goal
Territories exist as a card type with building slots and keywords, the game has a territory deck,
and the Capital starts on a territory. This is the foundation for explore (002), settle (003),
slots (004), and keywords (005). See PLAN.md › Territories.

## Acceptance criteria
- [x] AC1: Given a card `{"id": "hills", "type": "territory", "slots": 3, "keywords": ["mountain"]}` and
  config `keywords: ["mountain", "fresh_water"]`, when the data loads, then there are no errors and the
  CardDef has `slots == 3`, `keywords == ["mountain"]`, and `is_permanent()` is true.
- [x] AC2: Given a territory with `slots` missing or `-1`, or with keyword `"lava"` that isn't in config
  `keywords`, when the data loads, then there is one error per problem, each naming the card id and the
  field (`slots` / `unknown keyword 'lava'`).
- [x] AC3: Given a non-territory card with `slots` or `keywords`, when the data loads, then there is a warning
  naming the card and field, and no error.
- [x] AC4: Given config `territory_deck: {"hills": 2, "grassland": 1}`, when the data loads, then it is
  normalized like `deck`. An unknown id is an error. A non-territory id there, or a territory id in `deck`,
  is an error that names the id. `starting.territory` must name a territory card, or it is an error.
- [x] AC5: Given `territory_deck: {"hills": 2, "grassland": 1}` and `starting.territory: "grassland"`, when a
  new game starts, then:
  - the `territory_deck` zone holds 3 territories, shuffled by the seed (same seed ⇒ same order)
  - the `frontier` zone is empty
  - the tableau is `[grassland, capital]`
  - `territory_of(capital)` is the Grassland instance
  - the score is unchanged (territories have 0 VP by default).
- [x] AC6: Given a config with none of `keywords`, `territory_deck`, or `starting.territory`, when the data
  loads and a game starts, then there are no errors or warnings, the territory deck is empty, and the
  tableau is `[capital]` (existing games are unaffected).

## Out of scope
- Exploring, settling, slot limits, keyword effects (items 002–005).

## Design notes
- **cards.json:**
  - card type `territory`
  - fields `slots` (int ≥ 0, required on territories) and `keywords` (array of keyword ids, default `[]`)
- **config.json:**
  - `keywords` (array of ids, default `[]`)
  - `territory_deck` ({id: count}, default `{}`)
  - `starting.territory` (card id, optional)
- **Keyword display:** ids are snake_case; show them with `String.capitalize()` (`fresh_water` →
  "Fresh Water").
- **Engine:**
  - `ZONES` gains `territory_deck` and `frontier`
  - `CardInstance.territory_uid` (default -1)
  - `GameEngine.territory_of(card) -> CardInstance` (null if none)
- **UI (drag interface, 008):**
  - add a `territory` colour to `CardView.TYPE_COLORS`
  - the tableau is shown as **territory groups**: one container per settled territory, holding the
    territory card first, then its city and buildings. Cards with no territory go in a last group.
    004 builds on this: a whole group is a building's drop target.
  - 008's slots work inside any container, so `main.gd::_place` puts a tableau card's slot in its
    territory's group container instead of the flat tableau row
- **Real data:** add a `grassland` territory (2 slots, no keywords), set it as `starting.territory`,
  and add the `keywords` list. `territory_deck` stays empty until 002/006.

## Test plan
All in `tests/test_territories.gd`.

| AC | Test |
|---|---|
| AC1 | `test_territory_card_loads_with_slots_and_keywords` |
| AC2 | `test_territory_missing_slots_is_error`, `test_territory_negative_slots_is_error`, `test_territory_unknown_keyword_is_error` |
| AC3 | `test_territory_fields_on_non_territory_are_warnings` |
| AC4 | `test_territory_deck_is_normalized`, `test_territory_deck_unknown_card_is_error`, `test_territory_deck_non_territory_is_error`, `test_territory_in_main_deck_is_error`, `test_starting_territory_must_be_a_territory`, `test_starting_territory_unknown_card_is_error` |
| AC5 | `test_new_game_shuffles_territory_deck`, `test_territory_deck_order_follows_seed`, `test_capital_starts_on_starting_territory`, `test_starting_territory_does_not_change_score` |
| AC6 | `test_config_without_territories_loads_cleanly`, `test_game_without_territories_is_unchanged` |

## Manual check
- [ ] Any seed: the tableau shows one framed group holding the Grassland card (purple, "2 slots"),
  then the Capital.
- [ ] Dragging a Farm into the tableau still works. The Farm lands in a separate, unframed-territory
  group after the Grassland group (placing buildings on territories is 004).

## Log
- 2026-09-28: red. Added `grassland` and `hills` territories to `TEST_CARDS` and a `keywords()` helper;
  `parse_cards` takes the keyword list as an optional last argument. Interface-only declarations
  (`CardDef.slots/keywords`, `CardInstance.territory_uid`, `territory_of` returning null, the unused
  `parse_cards` parameter) went in with the red tests so the typed test files parse.
- 2026-09-28: green. Manual check reworded (user approved at the red checkpoint): under 001 a played
  Farm has no territory, so it goes in the last group; 004 places it on Grassland.
- UI grouping in `main.gd::_place_tableau` uses `territory_of`; it holds no rule beyond display order.
- Known look: the Capital's card content is taller than `TABLEAU_SIZE`, so it overhangs the group
  frame slightly (pre-existing overflow, now visible against the frame).
