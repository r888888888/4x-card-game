---
id: 072
title: Harmful event ops — lose resources and lose pop
type: feature
status: red-review
branch: feat/072-harmful-event-ops
---

## Goal
Events can only help today: every op gives something. Solo opposition (PLAN.md) needs events that cost the player.
Add the first harmful ops, limited to what the upkeep forecast can restore (resources and pop), so they may also
trigger each upkeep while the event lasts.

## Acceptance criteria
- [ ] AC1 (`lose`): Given 5 food, when an event with `{"op": "lose", "resource": "food", "amount": 2}` is drawn, food
  is 3. Given 1 food, it is 0 (never below 0). The same works for wealth.
- [ ] AC2 (`lose` validation): an unknown resource, or an amount that isn't an integer ≥ 1, is a load error naming
  the card and the effect index. Both ops load on a building too (not only on events).
- [ ] AC3 (`lose_pop`): Given Homeland with 3 pop and a second territory with 1 pop, when an event with
  `{"op": "lose_pop", "amount": 1}` is drawn, the territory with the most pop loses 1 (Homeland: 2). A tie picks the
  first in tableau order. A territory never goes below 0 pop; with no pop anywhere nothing happens.
- [ ] AC4 (upkeep): both ops may use `"trigger": "upkeep"` (`upkeep_ok()` is true), and `upkeep_forecast` includes
  them (an active event with ⟳ lose 1 food shows food −1 more in the forecast).
- [ ] AC5 (text): card text reads "−2 food" and "−1 pop (largest territory)"; the log names the source card.

## Out of scope
- Rule modifiers ("buildings cost +1"), destroying or idling a building, discarding from hand.
- Real harmful event content (a separate content item after this one).

## Design notes
- Follow the `add-effect` skill for each op.
- Decided: `lose_pop` takes pop from the territory with the most pop (ties: first in tableau order), so there is
  no choice in the middle of `end_turn`.
- Decided: like every other op, both are allowed on any card type (for example a building with an upkeep cost);
  the loader only applies its usual rules (no keyword or target on techs and events).

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_harmful_ops::test_lose_takes_the_resource`, `::test_lose_never_goes_below_zero`, `::test_lose_works_for_wealth`, `::test_a_drawn_event_with_lose_takes_food` |
| AC2 | `test_harmful_ops::test_lose_and_lose_pop_load_on_a_building`, `::test_lose_and_lose_pop_validation` |
| AC3 | `test_harmful_ops::test_lose_pop_takes_from_the_territory_with_the_most_pop`, `::test_lose_pop_tie_takes_from_the_first_in_tableau_order`, `::test_lose_pop_with_no_pop_does_nothing` |
| AC4 | `test_harmful_ops::test_upkeep_lose_is_in_the_forecast_and_applies`, `::test_upkeep_lose_pop_applies_and_the_forecast_leaves_pop_alone`, `test_forecast::test_upkeep_safe_ops_may_trigger_on_upkeep` (2 rows added to `UPKEEP_SAFE`) |
| AC5 | `test_harmful_ops::test_lose_and_lose_pop_card_text`, `::test_the_log_names_the_source_card` |

## Log
- From 039's follow-ups.
- Open questions settled: `lose_pop` hits the largest territory; both ops are allowed on any card type.
- 2026-09-30: Red at 610 tests (was 597), 14 failing. Fixtures are local to `test_harmful_ops.gd`. AC1's exact
  numbers are tested on a played action; one test draws an event and stops before the next upkeep (hand over the
  limit), so its numbers stay exact too.
