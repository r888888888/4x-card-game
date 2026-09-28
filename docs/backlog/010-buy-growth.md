---
id: 010
title: Buy growth with food
type: feature
status: done
branch: feat/010-buy-growth
---

## Goal
During the play phase, the player can spend food to grow a territory by 1 pop. Each step costs
more than the last, so growing tall gets expensive. Depends on 009.

## Acceptance criteria
- [x] AC1: Given population on, Homeland with pop 2 and housing 7, and 5 food, when I call
  `grow(homeland_uid)`, then it returns true, Homeland has pop 3, food is 2 (cost = current pop + 1 = 3),
  and `changed` is emitted.
- [x] AC2: Given the same, after that first growth, a second `grow(homeland_uid)` with 2 food is
  rejected: `grow_error` says it needs 4 food (you have 2), `grow` returns false, and pop and food are
  unchanged. With 4 food it succeeds (pop 4, food 0). There is no per-turn limit.
- [x] AC3: Given a territory whose pop equals its housing, then `grow_error` is non-empty (it's at
  housing), and `grow` returns false and changes nothing.
- [x] AC4: `grow` is rejected with no change, and `grow_error` gives a reason, when: the uid is not a
  settled territory (a frontier territory, a city, an unknown uid), a territory choice is pending, the
  game is over, or the config has no `population` block.
- [x] AC5: Given a legal growth, then `grow_error(uid)` is "" before the call.

## Out of scope
- Growth from cards (013).

## Design notes
- Engine API: `grow_error(territory_uid) -> String` and `grow(territory_uid) -> bool`, modelled on
  `play_error` / `play_card`, plus `grow_cost(territory_uid) -> int` (pop + 1) so the UI can show the price
  without computing it. This is a player action, not a card, so it emits no `card_played`.
- UI: a "Grow (N food)" button on each settled territory, disabled with `grow_error` as its tooltip.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_growth::test_grow_adds_1_pop_for_pop_plus_1_food`, `test_grow_emits_no_card_played` |
| AC2 | `test_growth::test_grow_rejected_when_food_is_short`, `test_grow_has_no_per_turn_limit` |
| AC3 | `test_growth::test_grow_rejected_at_housing` |
| AC4 | `test_growth::test_grow_refused_on_non_settled_targets`, `test_grow_refused_while_a_choice_is_pending`, `test_grow_refused_when_game_is_over`, `test_grow_refused_without_population` |
| AC5 | `test_growth::test_grow_error_is_empty_when_legal` |

## Manual check
Run `godot --path .` (real data: Capital on Grassland, housing 4, start 2 pop; turn 1 food is 2).
- [ ] The Capital's territory box shows "Grow (3 food)" next to "Pop 2 / 4". On turn 1 (2 food) it is disabled,
  and hovering shows "Growing Grassland needs 3 food (you have 2)."
- [ ] With 3+ food (play Forage), click it: pop becomes 3 / 4, food drops by 3, the stats bar Pop and Score go up
  by 1, and the button now reads "Grow (4 food)".
- [ ] At 4 / 4 the button is disabled with "Grassland is at its housing (4)."
- [ ] While an explore choice is open, Grow is disabled.

## Log
- 2026-09-28: spec'd with the user. Cost = current pop + 1 food, no limit per turn.
- 2026-09-28: red. 10 failing tests in the new `tests/test_growth.gd`, all on missing `grow` / `grow_error` /
  `grow_cost`. Added `grow_cost` to the API so the Grow button's label comes from the engine.
- 2026-09-28: green. `grow` logs "<Territory> grew to N pop (C food)." The Grow button's label, enabled state and
  tooltip all come from `grow_cost` / `grow_error`.
