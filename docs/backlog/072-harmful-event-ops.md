---
id: 072
title: Harmful event ops — lose resources and lose pop
type: feature
status: draft
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
| AC1 | `test_events::test_…` |

## Log
- From 039's follow-ups.
- Open questions settled: `lose_pop` hits the largest territory; both ops are allowed on any card type.
