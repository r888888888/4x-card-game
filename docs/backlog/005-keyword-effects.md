---
id: 005
title: Keyword requirements and bonuses
type: feature
status: red-review
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
- **UI:** targeting highlights respect `requires`. With the drag interface (008, 004), hovering a building over
  a group without the keyword turns the card red and shows the engine's reason, for example
  "Well needs a territory with Fresh Water." (from `play_error(uid, target_uid)`).

## Test plan
All in `tests/test_keywords.gd`.

| AC | Test |
|---|---|
| AC1 | `test_requires_limits_targets_to_keyword_territories` |
| AC2 | `test_requires_with_no_keyword_territory_fails`, `test_requires_error_for_target_without_keyword` (UI design note) |
| AC3 | `test_keyword_upkeep_applies_on_matching_territory`, `test_keyword_upkeep_skipped_elsewhere` |
| AC4 | `test_keyword_play_effect_applies_on_matching_territory`, `test_keyword_play_effect_skipped_elsewhere` |
| AC5 | `test_unknown_requires_keyword_is_error`, `test_unknown_effect_keyword_is_error`, `test_keyword_fields_load_without_warnings` |
| AC6 | `test_keyword_effect_text`, `test_requires_text`, `test_requires_several_keywords_text` |

## Manual check
- [ ] Picking up Irrigation only lights up Fresh Water territories. Hovering it over another territory turns it red
  and shows the reason. Keyword bonus lines show on cards.

## Log
- 2026-09-28: red. Added `river`, `well`, `paddy`, `lookout` to `TEST_CARDS`; `keywords()` gains
  `flood_plain`. No interface stubs needed.
