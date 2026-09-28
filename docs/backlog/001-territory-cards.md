---
id: 001
title: Territory cards and the Capital's starting territory
type: feature
status: ready
branch: feat/001-territory-cards
---

## Goal
Territories exist as a card type with building slots and keywords, the game has a territory deck,
and the Capital starts on a territory. This is the foundation for explore (002), settle (003),
slots (004), and keywords (005). See PLAN.md › Territories.

## Acceptance criteria
- [ ] AC1: Given a card `{"id": "hills", "type": "territory", "slots": 3, "keywords": ["mountain"]}` and
  config `keywords: ["mountain", "fresh_water"]`, when the data loads, then there are no errors and the
  CardDef has `slots == 3`, `keywords == ["mountain"]`, and `is_permanent()` is true.
- [ ] AC2: Given a territory with `slots` missing or `-1`, or with keyword `"lava"` that isn't in config
  `keywords`, when the data loads, then there is one error per problem, each naming the card id and the
  field (`slots` / `unknown keyword 'lava'`).
- [ ] AC3: Given a non-territory card with `slots` or `keywords`, when the data loads, then there is a warning
  naming the card and field, and no error.
- [ ] AC4: Given config `territory_deck: {"hills": 2, "grassland": 1}`, when the data loads, then it is
  normalized like `deck`. An unknown id is an error. A non-territory id there, or a territory id in `deck`,
  is an error that names the id. `starting.territory` must name a territory card, or it is an error.
- [ ] AC5: Given `territory_deck: {"hills": 2, "grassland": 1}` and `starting.territory: "grassland"`, when a
  new game starts, then:
  - the `territory_deck` zone holds 3 territories, shuffled by the seed (same seed ⇒ same order)
  - the `frontier` zone is empty
  - the tableau is `[grassland, capital]`
  - `territory_of(capital)` is the Grassland instance
  - the score is unchanged (territories have 0 VP by default).
- [ ] AC6: Given a config with none of `keywords`, `territory_deck`, or `starting.territory`, when the data
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
- **Real data:** add a `grassland` territory (2 slots, no keywords), set it as `starting.territory`,
  and add the `keywords` list. `territory_deck` stays empty until 002/006.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_data_loader::test_…` |

## Manual check
- [ ] The Capital's territory shows in the tableau next to the Capital, with its slots and keywords
  on the card.

## Log
