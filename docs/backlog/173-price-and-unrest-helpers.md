---
id: 173
title: One way to check and pay a price, and to add unrest
type: feature
status: review
branch: feat/173-price-and-unrest-helpers
---

## Goal
Checking whether a price can be paid, paying it and naming it happen in one place, as does capping unrest at the
limit. 155 (an order price that rises per counter) and 156 (the drain) add more of both. From the 2026-10-01 project
review.

## Acceptance criteria
- [x] AC1: A short message for a price of several resources names each one you have. Given `unrest.relief`
  `{"food": 2, "wealth": 6}` and 0 food and 1 wealth under Anarchy, `restore_order_error()` is
  "Restoring order needs 2 food, 6 wealth (you have 0 food, 1 wealth)."; the same for `relieve_famine_error()` with `population.famine.relief`
  `{"food": 2, "wealth": 5}` ("Relieving the famine needs 2 food, 5 wealth (you have 0 food, 1
  wealth)."). A one-resource price keeps today's text ("Restoring order needs 6 wealth (you have 1).").
- [x] AC2: One `EngineCore` helper pays a price and one gives the afford check: `play_card`, `buy`, `grow`, `buy_tech`,
  `relieve_famine` and `restore_order` use them. No `engine/` script but the helper subtracts from `resources` for a
  price, and `resources.wealth` / `resources.food` aren't written in `engine/` (supply.gd:47, population.gd:62 and
  99–100 use the constants).
- [x] AC3: The amounts text ("2 food, 5 wealth") is a public helper (e.g. `Fields.amounts_text`); `Anarchy` no longer
  calls `Famine._amounts`.
- [x] AC4: Unrest added by `gain`, by a new era (`Anarchy.stir`) and capped by `choose_government` goes through one
  helper that stops at `unrest_limit()`. Given limit 5, unrest 4 and era unrest 3, a new era leaves unrest at 5 and the
  notice says "+1 unrest" (as today).
- [x] AC5: Behavior is pinned: `scripts/sim.sh 20` prints the same before and after, and every existing test passes
  unedited.

## Out of scope
- `play_error`'s cost message, which already names the first short resource with its amount.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_prices::test_restoring_order_short_of_a_two_resource_price_names_both`, `test_famine_relief::test_relief_short_of_a_two_resource_price_names_both` (one resource: also test_leaving_anarchy's and test_famine_relief's existing error tables) |
| AC2 | `test_prices::test_can_pay_and_pay_a_price`, `test_prices::test_only_engine_core_takes_resources_away_or_names_food_and_wealth_as_fields` |
| AC3 | `test_prices::test_amounts_text_names_each_resource_of_a_price` |
| AC4 | `test_prices::test_set_unrest_stops_at_the_limit_and_returns_the_change`, `test_prices::test_only_engine_core_writes_unrest`, `test_prices::test_a_new_era_at_unrest_4_of_5_adds_1` (a pin: passes today) |
| AC5 | Every existing test unedited; `scripts/sim.sh 20` before and after (Manual check) |

## Manual check
- [x] `scripts/sim.sh 20` prints the same on `main` and on this branch (Claude runs both and pastes the comparison in
  the Log).

## Log
- 2026-10-01: Specced from the project review.
- 2026-10-01: Red. API: `EngineCore.can_pay(cost) -> bool`, `pay(cost)`, `set_unrest(n) -> int` (sets unrest to n,
  between 0 and the limit, returning the change; `gain`, `Anarchy.stir` and `choose_government`'s halving go through
  it), `Fields.amounts_text(cost)`. The structure test also counts feeding (`population.gd`'s `food -= eaten`): pop's
  food goes through `pay` too, so only EngineCore lowers resources. The 4-of-5 era test passes today (it pins AC4's
  example; test_anarchy's checked only 3 → 5).
- 2026-10-01: Green. `EngineCore.price_error(what, cost)` builds the "needs … (you have …)" message for relief, order,
  growing and techs; `play_error` keeps naming its first short resource and `buy_error` its "costs" wording, both
  checking with `can_pay`. `set_unrest` never lifts unrest that is already past a lowered limit, as `gain` did.
  `scripts/sim.sh 20` is identical to `main`'s (diffed).
