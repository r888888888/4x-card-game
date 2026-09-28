---
id: 021
title: Add wealth as a second resource
type: feature
status: review
branch: feat/021-wealth-resource
---

## Goal
Food currently pays for everything. Add **wealth** as a second resource so that cards can cost food,
wealth, or both: food pays for people (growth, upkeep, Settlers) and wealth pays for premium
buildings. This item adds the resource and shows it. Moving real cards to wealth is 022.

## Acceptance criteria
<!-- Fixture: resources ["food", "wealth"]. Test cards: "shrine" (building, cost 2 food + 2 wealth),
"stall" (building, ⟳ +1 wealth), "bazaar" (action, +2 wealth per city). -->
- [x] AC1: Loader. Given config `resources: ["food", "wealth"]`, a card costing
  `{"food": 2, "wealth": 2}` and a `gain` / `gain_per_tag` effect with `resource: "wealth"` load with
  no errors. A card costing `{"gold": 1}` still gives an error naming the file, card and field (`cost:
  unknown resource 'gold'`). Generated text: "⟳ +1 wealth" and "+2 wealth per city".
- [x] AC2: Starting state. Given `starting.resources: {"food": 2}` (no wealth listed), when a new game
  starts, then food is 2 and wealth is 0. Given `{"food": 2, "wealth": 3}`, then wealth is 3.
- [x] AC3: Mixed cost. Given 3 food, 2 wealth and a Shrine (2 food + 2 wealth) in hand, when played,
  then food is 1, wealth is 0, the Shrine is on the tableau and the `card_played` outcome has
  `paid == {"food": 2, "wealth": 2}`.
- [x] AC4: Can't afford. Given 5 food and 1 wealth, then `play_error` for the Shrine is
  "Shrine needs 2 wealth (you have 1)." and `play_card` returns false with food, wealth and zones
  unchanged. Given 1 food and 5 wealth, then the error is "Shrine needs 2 food (you have 1)."
- [x] AC5: Gaining and carry over. Given a Stall on the tableau and 3 wealth, when the turn ends,
  then wealth is 4 after upkeep. Wealth is never reset or capped: after 3 more turns with the Stall,
  wealth is 7. Given 1 city on the tableau (the Capital), playing a Bazaar gives +2 wealth.
- [x] AC6: Wealth is not food. With population on, given 0 food, 5 wealth and 2 pop, when upkeep runs,
  then pop starves as before and wealth stays 5. `grow_error` with 0 food and 10 wealth still says
  growth needs food, and `grow` spends no wealth.

## Out of scope
- Changing any real card's cost or effects (022).
- Converting food to wealth or wealth to food. Wealth VP at game end. Building maintenance.
- A wealth icon in card text (resource words stay words, as in 020).

## Design notes
- **Expected engine change: little or none.** Costs, `gain`, `gain_per_tag`, starting resources and
  `play_error` already work for any resource by name. The ACs lock this in. Tests that pass on
  first run are guards, not red tests; say which are which at the red checkpoint.
- `data/config.json`: `"resources": ["food", "wealth"]`. No card changes, so the game plays as before
  apart from the new stat.
- Test fixtures: add `wealth` to `resources()` / `raw_config` in `tests/lib/test_case.gd`, and add the
  Shrine, Stall and Bazaar test cards to `TEST_CARDS`. Existing tests must stay green.
- UI (`ui/main.gd`): a "Wealth: N" stat beside Food, in its own colour. `_resource_label` maps wealth to
  it so gain/pay tokens fly there. Card cost text already lists every resource ("2 food 2 wealth").
  Consider a separator ("2 food · 2 wealth") if it reads badly.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
All tests are in `tests/test_wealth.gd`. All 12 passed on first run (guards: the engine already handles
any resource by name). A mutation check (paying only food costs) failed `test_mixed_cost_pays_both_resources`.

| AC | Test |
|---|---|
| AC1 | `test_wealth_cost_and_gains_load`, `test_unknown_resource_cost_is_still_an_error`, `test_wealth_card_text` |
| AC2 | `test_wealth_starts_at_0_when_not_listed`, `test_starting_wealth_from_config` |
| AC3 | `test_mixed_cost_pays_both_resources` |
| AC4 | `test_short_of_wealth_is_rejected`, `test_short_of_food_names_food` |
| AC5 | `test_upkeep_gains_wealth_and_it_carries_over`, `test_gain_wealth_per_city` |
| AC6 | `test_starvation_does_not_spend_wealth`, `test_growth_needs_food_not_wealth` |

## Manual check
Run `godot --path .`.
- [ ] The stats bar shows "Wealth: 0" next to Food and doesn't crowd the bar at the default window size.
- [ ] (With a scratch card or after 022) gaining wealth flies a "+N wealth" token to the Wealth stat
  and pulses it. Paying wealth animates like food.
- [ ] A hand card with a mixed cost shows both parts legibly in the cost slot ("2 food, 2 wealth").
  No real card has one until 022; check it then, or with a scratch cost edit in `data/cards.json`.

## Log
- The spec's "Shrine" test card is named **Guildhall**: `shrine` is already an action in `TEST_CARDS`.
- No test went red: the engine needed no change. Remaining work is `data/config.json` and the UI.
- Green: `data/config.json` lists wealth, and a "Wealth: N" stat (amber, `f2b46d`) sits after Food.
  `_resource_label` sends wealth pay and gain tokens to it. Cost text already joins parts with ", "
  ("2 food, 2 wealth"), so it needed no change. The game launches headless with no errors.
- Suite: 174 → 186 tests.
