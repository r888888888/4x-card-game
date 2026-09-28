---
id: 005
title: Keyword requirements and bonuses
type: feature
status: review
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

- [x] AC1: Given River and Hills settled with free slots, `valid_targets(well)` is [river]. Playing Well with
  no target places it on River.
- [x] AC2: Given only Hills settled, when I try to play Well, then `play_error` is "Well needs a territory with
  Fresh Water." and nothing changes.
- [x] AC3: Given a Paddy on River, when upkeep runs, then it produces 2 food. A Paddy on Hills produces 1.
- [x] AC4: Given a keyword-conditioned `play` effect (for example `score +1` with `keyword: "mountain"`), when
  it's played onto Hills, then it applies; onto River, it doesn't.
- [x] AC5: Given an unknown keyword in `requires` or in an effect's `keyword`, when the data loads, then it is
  an error naming the card and the field.
- [x] AC6: Card text:
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
- [ ] Explore until a Lakeshore (Fresh Water) is settled. Picking up Irrigation only lights up Fresh Water
  territories. Hovering it over another territory turns it red, with "Irrigation needs a territory with
  Fresh Water." under the card.
- [ ] Irrigation's text shows "Requires Fresh Water"; Farm's shows "Each upkeep: +1 food (on Flood Plain)".
  (No real territory has Flood Plain until 006.)

## Log
- 2026-09-28: red. Added `river`, `well`, `paddy`, `lookout` to `TEST_CARDS`; `keywords()` gains
  `flood_plain`. No interface stubs needed.
- 2026-09-28: green. `CardDef.requires` and `Effect.keyword` (parsed in `EffectRegistry.create`); the engine
  filters building targets with `_meets_requires` and skips keyword effects off-keyword in `_resolve`.
  Error precedence: the requires message when no settled territory has a required keyword, or when the
  given target lacks it; "No territory with a free slot." when a keyword territory exists but is full.
- Test setup edit (not an assertion): `test_territories::load_with_keywords` uses `keywords()` so the
  fixture's `flood_plain` loads.
- Real data: config gets the user's keyword list (see 006); Irrigation requires Fresh Water; Farm gets
  +1 food on Flood Plain.
- UI: the drag hint (the engine's reason under a red card) was missing since 004; added here for both.
