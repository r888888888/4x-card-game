---
id: 262
title: Growth cards replace automatic growth
type: feature
status: in-progress
branch: feat/262-growth-cards
---

## Goal
Pop grows by playing growth cards instead of automatically from a food surplus (260 rolled back; the manual Grow button
stays gone). Growth becomes a deck choice that competes for actions and food: Bread and Beer (one pop where the work
is) and Land Grants (a pop on each of your 3 smallest territories). Needs 261. Spike: `spike/growth-cards`.

## Acceptance criteria
- [ ] AC1: No automatic growth: given population on and an upkeep netting +5 food with room everywhere, when the next
  turn starts, then no territory's pop changes and no "grew to" notice is emitted.
- [ ] AC2: `population.growth_surplus` is no longer read: a config with it loads without errors and with the loader's
  usual warning "population: unknown field 'growth_surplus'"; the normalized population block has no
  `growth_surplus`. Test fixtures no longer add it (`NO_GROWTH` is gone).
- [ ] AC3: Real data: the starting deck and the supply hold at least one action whose effects include `grow` with
  `where: "best"`, and at least one with `where: "each"` and a `count`; every growth card costs food. (Content
  invariants: no card ids or numbers in the test.)
- [ ] AC4: Bot: given a hand with a growth card it can afford, it plays it only when that adds pop and the next
  upkeep's net food (`upkeep_forecast()[FOOD]`) after playing it is still ≥ +1. Fixture: food_upkeep 1, Capital +2,
  pop 2, one Farm (+1): net +1 → it skips a `best` growth card (net would be 0); with two Farms (net +2) it plays one.
  With every territory full it skips it.
- [ ] AC5: Bot strategies: `growth` and `tall` play growth cards first (with food-on-upkeep cards) and may buy them
  as their preferred supply cards; `baseline`, `wealth` and `wide` play them in hand order under the AC4 rule.

## Out of scope
- Tuning costs, counts or piles beyond the spike values below: a balance item (next).
- The food tooltip showing net food after a play (follow-up UI item).
- A per-territory Grow button or player-chosen growth targets.

## Design notes
- Remove: `Population.auto_grow` and its call in `TurnLoop.start_turn` (and the `food_before` it uses),
  `growth_surplus` in `ConfigLoader.POPULATION_FIELDS` and `data/config.json`, `NO_GROWTH` in `test_case.gd`, and
  260's tests (`tests/test_auto_growth.gd` AC1–AC7; keep "manual growth is gone" and "the grow op still adds pop",
  moved to `test_growth_cards.gd`; `test_anarchy::test_under_anarchy_nothing_grows_by_itself`). Revert
  `test_population`'s expected dicts.
- Content (spike values, for review under Manual check):
  - **Bread and Beer** (`bread_and_beer`): action, cost 2 food, `{op: grow, amount: 1, where: best}`. 1 in the
    starting deck; supply 8 at price 2.
  - **Land Grants** (`land_grants`): action, cost 5 food, `{op: grow, amount: 1, where: each, count: 3}`. Supply 4
    at price 3.
  - Names: Egyptian and Sumerian workers were paid in bread and beer; Babylonian and Persian rulers granted land on
    the margins.
- Bot (`sim/bot.gd`): a `_growth_ok(engine, card)` check on a fork (play it, compare total pop, read the forecast's
  net food); `_prefers` for `growth`/`tall` adds cards with a `grow` op.
- `PLAN.md`: Growth section (cards, not automatic), Resources row, the 260 notes.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_growth_cards::test_pop_never_grows_by_itself` |
| AC2 | `test_growth_cards::test_growth_surplus_is_an_unknown_population_field`; `test_population::test_population_block_defaults`, `test_population_block_values_load` (dicts reverted: fixtures add no `growth_surplus`) |
| AC3 | `test_content::test_the_deck_and_supply_hold_both_kinds_of_growth_action`, `test_every_growth_card_costs_food` |
| AC4 | `test_sim_strategies::test_every_strategy_skips_a_growth_card_that_leaves_less_than_1_net_food`, `test_every_strategy_plays_a_growth_card_that_leaves_net_food_of_1`, `test_every_strategy_skips_a_growth_card_that_adds_no_pop` |
| AC5 | `test_sim_strategies::test_growth_and_tall_play_growth_cards_first`, `test_growth_and_tall_may_buy_growth_cards`, `test_other_strategies_play_growth_cards_in_hand_order` |

Removed with 260's rule: `tests/test_auto_growth.gd` (its "manual growth is gone" and "the grow op still adds pop" moved
to `test_growth_cards`), `test_anarchy::test_under_anarchy_nothing_grows_by_itself`.

## Manual check
- [ ] `data/cards.json` / `config.json`: Bread and Beer and Land Grants as above (costs, piles, 1 Bread and Beer in
  the starting deck); their generated text reads "+1 pop where it's needed most" and "+1 pop on each of your 3
  smallest territories with room".
- [ ] `godot --path . -- --civ egypt --seed 5`: play Bread and Beer with an idle building: that territory gains 1 pop.
  End turns with a food surplus: nothing grows by itself.

## Log
- Spike results (100-turn sim, 40 seeds): growth through cards raised score for baseline, wide, wealth and tall over
  automatic growth, slowed early pop, and left food for Settlers; Famines rose because the spike bot only checked the
  next upkeep (AC4 fixes that). Uncapped Land Grants drove wide bots into famine (net −5 to −7 by turn 60); capped at 3
  it didn't. Run the `balance` skill in the next item.
