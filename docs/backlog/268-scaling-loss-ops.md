---
id: 268
title: Loss ops that scale with the realm: lose_pct and lose_per_keyword
type: feature
status: red-review
branch: feat/268-scaling-loss-ops
---

## Goal
Every harmful op today takes a flat amount (`lose`, `lose_pop`), and a flat −2 food stops mattering by mid-game. Two
new ops let threats grow with the realm:
- `lose_pct` takes a share of what is stored, like Anarchy's drain.
- `lose_per_keyword` takes an amount per matching territory: the mirror of `gain_per_keyword`, for a drought on
  deserts or a storm on the coast.

The era-2 and era-3 events (270) use both.

## Acceptance criteria
- [ ] AC1 (`lose_pct`): Given 7 food, when `{ "op": "lose_pct", "resource": "food", "pct": 25 }` resolves, then food
  is 5: 25% of 7 is 1.75, rounded up to 2. The play outcome's `lost` reports 2 food. Given 0 food, nothing is taken and
  `lost` has no food.
- [ ] AC2 (`lose_pct` on upkeep): Given an event with `lose_pct` wealth 50 on `upkeep` and 6 wealth, then
  `upkeep_forecast()` shows wealth −3, and the next upkeep takes 3.
- [ ] AC3 (`lose_per_keyword`): Given 3 settled territories (two with `desert`, one printed and one rolled, and one
  `grassland`) and 5 food, when `{ "op": "lose_per_keyword", "resource": "food", "amount": 1, "keywords": ["desert"] }`
  resolves, then food is 3. With 1 food, food is 0, never below. With no desert territory, nothing is taken.
- [ ] AC4 (loader): Each of these is a load error naming the file, the card and the field:
  - `lose_pct`: `pct` missing, 0 or 101.
  - `lose_pct`: an unknown resource.
  - `lose_per_keyword`: an empty or missing `keywords`.
  - `lose_per_keyword`: an unknown keyword.
  - `lose_per_keyword`: `amount` below 1.

  Both ops may use the `upkeep` trigger (`upkeep_ok()` is true).
- [ ] AC5 (text): Card text reads "−25% food" and "−1 food per desert territory". The tooltip reads "Lose 25% of
  stored food (rounded up)" and "−1 food for each settled territory with desert".

## Out of scope
- Shipping cards that use the ops (270).
- A percentage gain, or a per-tag loss.

## Design notes
- New ops, added with the `add-effect` skill:
  - `lose_pct` `{resource, pct (int 1–100)}`. It takes ⌈stored × pct ÷ 100⌉ through `engine.lose`, so `lost`, unrest
    calming and the floor at 0 behave as for `lose`.
  - `lose_per_keyword` `{resource, amount (≥ 1, default 1), keywords}`. It counts with `count_territories_with`, the
    same as `gain_per_keyword`.
- Both are added to the upkeep-safe list in PLAN.md and CLAUDE.md, which only allow resources, bonus score and pop.
- Anarchy's drain could later use `lose_pct`. Not in this item.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_lose_pct::test_lose_pct_takes_a_share_of_the_store_rounded_up`, `test_lose_pct_of_an_empty_store_takes_nothing` |
| AC2 | `test_lose_pct::test_upkeep_lose_pct_is_forecast_and_taken`, `test_forecast::test_upkeep_safe_ops_may_trigger_on_upkeep` (rows) |
| AC3 | `test_lose_per_keyword::test_lose_per_keyword_takes_amount_per_matching_territory`, `test_lose_per_keyword_never_goes_below_zero`, `test_lose_per_keyword_with_no_matching_territory_takes_nothing`, `test_upkeep_lose_per_keyword_is_forecast_and_taken` |
| AC4 | `test_lose_pct::test_lose_pct_loads_and_may_trigger_on_upkeep`, `test_lose_pct_validation`, `test_lose_per_keyword::test_lose_per_keyword_loads_and_may_trigger_on_upkeep`, `test_lose_per_keyword_validation` |
| AC5 | `test_lose_pct::test_lose_pct_card_text`, `test_lose_per_keyword::test_lose_per_keyword_card_text` |

## Log
