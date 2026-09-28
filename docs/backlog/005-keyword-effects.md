---
id: 005
title: Keyword requirements and bonuses
type: feature
status: ready
branch: feat/005-keyword-effects
---

## Goal
Territory keywords matter. Card data can require a keyword for placement, or make an effect apply
only on a territory with a keyword. That makes where you build a real choice.

## Acceptance criteria
Test fixtures:
- River: 2 slots, keywords `fresh_water` and `flood_plain`
- Hills: 3 slots, keyword `mountain`
- `well`: building, cost 1, `requires: ["fresh_water"]`
- `paddy`: building, cost 2, upkeep +1 food, plus upkeep +1 food with `"keyword": "flood_plain"`

- [ ] AC1: Given River and Hills settled with free slots, `valid_targets(well)` is [river]. Playing Well with
  no target places it on River.
- [ ] AC2: Given only Hills settled, when I try to play Well, then `play_error` is "Well needs a territory with
  Fresh Water." and nothing changes.
- [ ] AC3: Given a Paddy on River, when upkeep runs, then it produces 2 food. A Paddy on Hills produces 1.
- [ ] AC4: Given a keyword-conditioned `play` effect (for example `score +1` with `keyword: "mountain"`), when
  it's played onto Hills, then it applies; onto River, it doesn't.
- [ ] AC5: Given an unknown keyword in `requires` or in an effect's `keyword`, when the data loads, then it is
  an error naming the card and the field.
- [ ] AC6: Card text:
  - Paddy is "Each upkeep: +1 food\nEach upkeep: +1 food (on Flood Plain)"
  - Well includes "Requires Fresh Water"
  - a `requires` with several keywords lists them joined by " or "

## Out of scope
- Keywords with their own rules (for example Jungle clearing).
- Keyword counts ("per Mountain territory").

## Design notes
- **cards.json:** building field `requires` (array of keyword ids; any-of).
- **Effect base:** optional `keyword` field, parsed in `EffectRegistry.create` next to `trigger` and
  checked in `GameEngine._resolve` against `territory_of(source)`. An effect on a card with no territory
  and a keyword never applies.
- **Validation:** loader validation needs the config keyword list in `ctx`, so `parse_cards` gets
  `keywords`.
- **UI:** targeting highlights respect `requires`.

## Test plan
| AC | Test |
|---|---|

## Manual check
- [ ] Irrigation only highlights Fresh Water territories. Keyword bonus lines show on cards.

## Log
