---
id: 260
title: Territories grow automatically from a food surplus
type: feature
status: review
branch: feat/260-automatic-growth
---

## Goal
Pop grows by itself when the realm makes enough food, instead of the player buying each pop with the Grow button.
A turn's food surplus of at least `population.growth_surplus` (default 2) grows the largest territory with room by
1 pop, for free. Each new pop eats 1 food, so growth settles where the surplus is `growth_surplus − 1` (+1 at the
default), leaving a trickle of food for Settlers and Feast. The manual Grow action goes away.

## Acceptance criteria
"Net food" is the food the upkeep's effects gained minus what pop ate (food after feeding − food before upkeep),
the figure `upkeep_forecast()[FOOD]` predicts. It doesn't include the Anarchy drain that comes after feeding.

- [x] AC1: Given population on, `growth_surplus` 2, one settled territory with 2 pop and housing 5, and upkeep effects
  that make 4 food, when the next turn starts, then after feeding (2 eaten, net +2) the territory has 3 pop and food
  is 2 more than before upkeep (growth costs no food).
- [x] AC2: Given the same setup but upkeep making 3 food (net +1), when the next turn starts, then pop stays 2.
  With `growth_surplus` 1 in the config, the same net +1 grows it to 3.
- [x] AC3: Given two settled territories, A with 3 pop and B with 2 pop, both with room, and net food +5, when the turn
  starts, then A grows to 4 and B stays 2. At most 1 pop grows per turn, whatever the surplus.
- [x] AC4: Given A with 3 pop at its housing 3 and B with 2 pop and room, and net food ≥ 2, when the turn starts, then
  B grows to 3. Given A and B both with 2 pop and room, A first in tableau order, then A grows. Given every
  territory at its housing, nothing grows and nothing errors.
- [x] AC5: No growth happens, even with net food ≥ `growth_surplus`, when Anarchy rules after feeding
  (`Anarchy.build_error` non-empty) or the population rules are off.
- [x] AC6: When a territory grows, the engine logs and emits `noticed` at `NOTICE_INFO` naming the territory and its
  new pop (e.g. "River Meadow grew to 3 pop."). No growth means no notice.
- [x] AC7: The config loader reads `population.growth_surplus` (an integer ≥ 1, default 2 when it's missing) and
  reports an error naming the field when it is not an integer or is below 1. `data/config.json` sets it to 2.
- [x] AC8: The manual growth action is gone: `GameEngine` has no `grow`, `grow_error` or `grow_cost`, the territory
  view has no Grow button, and `"grow"` is not one of the actions `_blocked_error` takes. The `grow` effect op
  (+pop from cards) still works as before.

## Out of scope
- A top bar or territory view hint saying which territory will grow next turn (a follow-up item if wanted).
- Tuning food numbers, Settlers' or Feast's costs, or `growth_surplus` beyond the default: that's a balance item.
- Changing Famine, housing or feeding rules.

## Design notes
- Config: `population.growth_surplus` (int ≥ 1, default 2) joins `ConfigLoader.POPULATION_FIELDS`.
- Engine: `Population.auto_grow(e, net_food)` runs in `TurnLoop.start_turn` right after `Population.feed`, before
  `Anarchy.start_of_turn` and the drain. `start_turn` records food before `resolve_upkeep` to work out net food.
  Order: most pop first, ties in tableau order, skipping territories at their housing (like `Population.most_pop`, but
  only counting those with room). It runs on forks too, so `upkeep_forecast` stays a pure query: it reports
  resources and `starve`, as before.
- Famine: no check needed. Net food ≥ 1 means everyone was fed (a short upkeep eats all the food there is, so its net
  is ≤ 0), and a fed upkeep ends the Famine in `after_feeding`. So with `growth_surplus` ≥ 1, the upkeep that ends a
  Famine may grow, and a Famine can't be active when growth runs. (Dropped from AC5 while writing the tests.)
- Removed: `Population.grow`/`grow_error`, `GameEngine.grow`/`grow_error`/`grow_cost`, the territory view's
  `grow_button` and `_grow`, the Grow button's coverage in `tests/test_grow_meter.gd` (the pop meter pips stay, as
  long as they're still covered), the `"grow"` action in `_blocked_error`'s list, and the glossary's "Grow" wording
  (the grow op's `terms()` still uses "Grow": reword its glossary entry to "+pop on a territory, up to its housing").
  Tests that call `grow` (test_growth, test_famine, test_anarchy, test_blocking, test_wealth, …) are either removed or
  rewritten for automatic growth.
- `PLAN.md`: Resources/Actions rows and the turn order (step 4 "buy growth") updated, plus a line under the turn's
  upkeep phase.
- Bot (`sim/bot.gd`): `_grow` and `_growth_order` go. Growth is automatic, so the bot does nothing about it. The
  growth/tall strategies still favour food cards.
- Fixtures: `make_engine` overrides with a population block but no `growth_surplus` get the default 2. Existing tests
  whose upkeep nets ≥ 2 food may now grow pop; fix them at the red checkpoint by giving their population override
  a high `growth_surplus` where growth isn't the point.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_auto_growth::test_a_surplus_of_2_grows_the_territory_for_free` |
| AC2 | `test_auto_growth::test_a_surplus_below_growth_surplus_grows_nothing`, `test_growth_surplus_1_grows_on_a_surplus_of_1` |
| AC3 | `test_auto_growth::test_the_largest_territory_grows_and_only_by_1` |
| AC4 | `test_auto_growth::test_a_full_territory_is_skipped`, `test_a_tie_goes_to_the_first_in_tableau_order`, `test_nothing_grows_when_every_territory_is_full` |
| AC5 | `test_anarchy::test_under_anarchy_nothing_grows_by_itself`, `test_auto_growth::test_nothing_grows_with_population_off` |
| AC6 | `test_auto_growth::test_growing_logs_and_notices_the_territory_and_its_pop`, `test_no_growth_no_notice` |
| AC7 | `test_auto_growth::test_growth_surplus_defaults_to_2`, `test_growth_surplus_is_read`, `test_growth_surplus_must_be_an_integer_of_at_least_1`; `test_population::test_population_block_values_load` (fixture default) |
| AC8 | `test_auto_growth::test_manual_growth_is_gone`, `test_the_grow_op_still_adds_pop` |

Fixtures: `raw_config` gives a population block without `growth_surplus` `NO_GROWTH` (1000), so existing fixture games
don't start growing; tests opt in by setting it.

## Manual check
- [ ] `godot --path . -- --civ egypt --seed 5`: play a Farm on the home territory. When the top bar's food forecast
  reads +2 or more, End turn: the home territory gains 1 pop and an info notice "<territory> grew to N pop." flags out
  of the rail. The next turn's forecast is 1 lower.
- [ ] Open a territory (click its card): pips and Rename… show, no Grow button.
- [ ] `data/config.json` has `population.growth_surplus: 2`.

## Log
- Balance: growth no longer costs food, and Farms now turn straight into pop and VP (`vp_per_pop`). Settlers
  compete with growth for food only through the surplus that's left. Expect pop and score to rise in the sim; check in
  a balance item.
- Turn 1's upkeep (run by `new_game`) grows too, like any other. Two approved tests assumed it didn't; with the
  user's OK they reset home pop to 2 after setup (`set_home_pop`). Rally (grow "here" from hand) adds no pop, so tests
  that grew pop by card use Festival; that also made `test_famine::test_no_growth_during_a_famine` really test the
  Famine's block on the grow op.
