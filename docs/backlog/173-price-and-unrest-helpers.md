---
id: 173
title: One way to check and pay a price, and to add unrest
type: feature
status: ready
branch: feat/173-price-and-unrest-helpers
---

## Goal
Checking whether a price can be paid, paying it and naming it happen in one place, as does capping unrest at the
limit. 155 (an order price that rises per counter) and 156 (the drain) add more of both. From the 2026-10-01 project
review.

## Acceptance criteria
- [ ] AC1: A short message for a price of several resources names each one you have. Given `unrest.relief`
  `{"food": 2, "wealth": 6}` and 0 food and 1 wealth under Anarchy, `restore_order_error()` is
  "Restoring order needs 2 food, 6 wealth (you have 0 food, 1 wealth)."; the same for `relieve_famine_error()` with `population.famine.relief`
  `{"food": 2, "wealth": 5}` ("Relieving the famine needs 2 food, 5 wealth (you have 0 food, 1
  wealth)."). A one-resource price keeps today's text ("Restoring order needs 6 wealth (you have 1).").
- [ ] AC2: One `EngineCore` helper pays a price and one gives the afford check: `play_card`, `buy`, `grow`, `buy_tech`,
  `relieve_famine` and `restore_order` use them. No `engine/` script but the helper subtracts from `resources` for a
  price, and `resources.wealth` / `resources.food` aren't written in `engine/` (supply.gd:47, population.gd:62 and
  99–100 use the constants).
- [ ] AC3: The amounts text ("2 food, 5 wealth") is a public helper (e.g. `Fields.amounts_text`); `Anarchy` no longer
  calls `Famine._amounts`.
- [ ] AC4: Unrest added by `gain`, by a new era (`Anarchy.stir`) and capped by `choose_government` goes through one
  helper that stops at `unrest_limit()`. Given limit 5, unrest 4 and era unrest 3, a new era leaves unrest at 5 and the
  notice says "+1 unrest" (as today).
- [ ] AC5: Behavior is pinned: `scripts/sim.sh 20` prints the same before and after, and every existing test passes
  unedited.

## Out of scope
- `play_error`'s cost message, which already names the first short resource with its amount.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|

## Log
- 2026-10-01: Specced from the project review.
