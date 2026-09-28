---
id: 026
title: Passed techs get cheaper, prerequisites discount, third pass removes
type: feature
status: red-review
branch: feat/026-tech-passes
---

## Goal
Techs nobody wants should get cheaper until they're worth buying, and owning a related tech should
make the next one cheaper. When you buy one revealed tech, the other is "passed": it goes back cheaper.
A tech passed for the third time is lost for good. Its last appearance is its cheapest, which forces a
"now or never" choice. Prerequisites never block a purchase; they only lower the price. Depends
on 025.

## Acceptance criteria
Fixtures from 025 (Pottery 2, Writing 3, Bronze Working 5), plus:
- `iron`: "Iron Working", cost 6 wealth, `prereq: "bronze"` (default discount 2)
- `steel`: "Steel", cost 3 wealth, `prereq: "iron"`, `prereq_discount: 5`

Starting wealth is 20. Tests set the research deck order directly.

- [ ] AC1 (loader): `prereq` on a tech must be the id of another tech. An unknown id, a card that isn't
  a tech, or the tech's own id is a load error that names the card and `prereq`. `prereq_discount` is
  an integer ≥ 1 and defaults to 2; any other value is a load error that names the card and
  `prereq_discount`. `prereq_discount` without `prereq` is a warning (ignored). `prereq` or
  `prereq_discount` on a card that isn't a tech is a warning (ignored).
- [ ] AC2 (buying passes the other tech): Given open options [pottery, bronze], when I buy Pottery,
  then Bronze Working has `tech_passes(uid)` 1 and `tech_cost(uid)` 4, and it is back in the research
  deck. Pottery's passes stay 0.
- [ ] AC3 (declining passes nothing): Given open options [pottery, bronze], when I decline, then both
  still have 0 passes and their costs are unchanged (2 and 5).
- [ ] AC4 (discount stacks): When Bronze Working is passed a second time, it has 2 passes and costs 3.
  Buying it then pays 3 wealth.
- [ ] AC5 (third pass removes): When Bronze Working is passed a third time, it goes to the `lost_techs`
  zone, not the research deck. It can't be revealed again: the research deck no longer contains it.
- [ ] AC6 (prerequisite discount): Iron Working costs 6 without Bronze Working in `researched` and 4
  with it. Iron Working with 1 pass and Bronze Working researched costs 3. Iron Working can be bought
  without Bronze Working (at 6).
- [ ] AC7 (minimum cost 1): With Iron Working researched, Steel costs 1 (3 − 5, raised to 1). Pottery
  with 2 passes costs 1 (2 − 2 = 0, raised to 1). `buy_tech` pays `tech_cost`.
- [ ] AC8 (card text): Iron Working's short text is "-2 wealth with Bronze Working" and its tooltip
  has the line "Costs 2 less wealth if you have Bronze Working."

## Out of scope
- Techs that can never be removed (the `add_era` exemption is in 027).
- More than one prerequisite per tech.
- Showing lost techs in the UI beyond a count.

## Design notes
- `CardInstance.passes: int` (techs only).
- Card fields: `prereq` (tech id), `prereq_discount` (int ≥ 1, default 2). Add them to `CARD_FIELDS`.
  The field is called `prereq`, not `requires`, because `requires` already means keywords on
  buildings.
- A prerequisite cycle is harmless, because prerequisites never block a purchase. The loader doesn't
  check for cycles.
- `tech_cost(uid) = max(1, printed − passes − (prereq_discount if prereq is in researched else 0))`.
- New zone `lost_techs`. Engine API: `tech_passes(uid) -> int`.
- Only a purchase passes the other revealed tech. Declining costs only the research charge, so
  there's no way to farm discounts.
- UI:
  - pass markers on revealed techs (○○, ●○, ●●), with "last chance" on ●●
  - the cost shown as printed, discount and total (from engine queries)
  - the count of lost techs next to the research deck count.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_tech_passes::test_prereq_and_default_discount_load`, `test_prereq_discount_loads`, `test_prereq_unknown_card_is_an_error`, `test_prereq_that_is_not_a_tech_is_an_error`, `test_prereq_on_itself_is_an_error`, `test_prereq_discount_below_1_is_an_error`, `test_prereq_discount_must_be_an_integer`, `test_prereq_discount_without_prereq_is_a_warning`, `test_prereq_on_a_card_that_is_not_a_tech_is_a_warning` |
| AC2 | `test_buying_passes_the_other_tech` |
| AC3 | `test_declining_passes_nothing` |
| AC4 | `test_the_discount_stacks_and_is_paid` |
| AC5 | `test_the_third_pass_sends_the_tech_to_lost_techs` |
| AC6 | `test_prerequisite_discounts_only_when_owned`, `test_prerequisite_and_passes_stack`, `test_a_tech_can_be_bought_without_its_prerequisite` (already passes: guards 025 behavior) |
| AC7 | `test_a_big_prerequisite_discount_stops_at_1`, `test_passes_cannot_take_a_tech_below_1` |
| AC8 | `test_prerequisite_card_text` |

## Manual check
- [ ] A passed tech shows its pass markers and lower cost when it comes up again. At ●● it says "last
  chance".
- [ ] A tech with its prerequisite researched shows the discount in its cost breakdown.

## Log
