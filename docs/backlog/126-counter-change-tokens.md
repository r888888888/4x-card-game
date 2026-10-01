---
id: 126
title: Every change to a top-bar counter floats its net change up from that counter
type: feature
status: done
branch: feat/126-counter-change-tokens
---

## Goal
Today only some changes to the top bar's values show a token, each wired by hand: a card's costs float up from their
counters (114), its gains and VP fly in from the card, a grow flies "+1 pop" from its pip (124), and upkeep, events
and card effects that change pop show nothing. Make it one pattern: whenever Food, Wealth, Score or Pop changes, a
token with the net change ("+2 food", "−1 wealth", "+3 VP", "+1 pop") appears just below that counter and floats up
as it fades, whatever caused it.

## Acceptance criteria
<!-- UI tests in the real main.tscn on TEST_CARDS; tokens are Labels on the fx layer, tweens stepped by hand
(as test_resource_tokens). "Floats up" = 114 AC1: starts centred just below its counter, x fixed, rises
Anim.TOKEN_FLOAT_PX, fades to transparent, freed. -->
- [x] AC1: Net change per counter. Given 10 food, when a refresh finds 12 food, then one "+2 food" token floats up
  from the food counter in the gain colour; 7 food gives one "−3 food" in the cost colour. A card that costs 2 food
  and gains 3 food shows one "+1 food" token, not two. The same holds for Wealth ("wealth"), Score ("VP") and Pop
  ("pop"); a counter whose value didn't change floats nothing.
- [x] AC2: Whatever the cause. Each of these floats its tokens up from the counters, and nothing flies from a card:
  a played card's costs and gains (farm: "−2 food"; caravan: "+N food"), its VP, a grow from the territory view's meter
  ("−3 food" and "+1 pop"), a card's `grow` effect (Festival: "+N pop", N the territories it grew), and end turn's
  upkeep (each resource's net change, and "−N pop" when pop starves).
- [x] AC3: Several at once. When one refresh changes more than one counter, their tokens start in the bar's order
  (Food, Wealth, Score, Pop), each `Anim.TOKEN_STAGGER` after the one before.
- [x] AC4: No token for a fresh game. Starting a game, New game and Restart float nothing, though the counters change.
- [x] AC5: Supply screen. Buying in the supply screen floats "−N wealth" from the screen's own wealth counter (114
  AC3) and none from the top bar's; closing the screen afterwards floats nothing.
- [x] AC6: Reduce motion. A token appears just below its counter, holds and fades without moving (114 AC6).

## Out of scope
- The Turn counter, the forecast in brackets, and counters on other screens (the supply screen's Discard).
- Changing what a counter pulses on (it already pulses when its text changes).
- The pip pop-in of 124 (unchanged).

## Design notes
- UI only. The top bar remembers the values it last showed (`food`, `wealth`, `score()`, `total_pop()`) and floats
  each difference in `refresh`; `fly_outcome` and `fly_grow` go, as do the board's `_outcome` / `_outcome_point`
  for tokens (keep what else uses them, e.g. the card that just played flying to the piles).
- The baseline resets silently on a new game and while the supply screen is open (it shows its own token).
- Changed tests: `test_resource_tokens::test_a_food_gain_still_flies_from_the_card_to_the_food_counter` (gains now
  float up from the counter), `test_food_and_wealth_costs_float_up_…` (still holds), and 124's
  `test_a_grow_pops_the_pip_in_and_flies_plus_one_pop_to_the_pop_counter`,
  `test_with_reduce_motion_the_pip_doesnt_scale_and_plus_one_pop_fades_at_the_counter` and
  `test_pop_from_a_card_fills_pips_without_a_token` (a card's pop now floats "+1 pop" too).
- Depends on 124 (merged first).

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_resource_tokens::test_a_change_floats_one_net_token_per_counter_in_its_colour`, `test_wealth_score_and_pop_changes_float_up_from_their_counters`, `test_a_refresh_that_changes_no_counter_floats_nothing` |
| AC2 | `test_resource_tokens::test_a_played_cards_costs_gains_and_vp_float_up_from_their_counters`, `test_a_grow_effect_floats_its_pop_up_from_the_pop_counter`, `test_a_grow_from_the_meter_floats_food_and_pop_up_from_their_counters`, `test_end_turn_upkeep_floats_its_net_changes`, `test_starving_pop_floats_down_from_the_pop_counter` |
| AC3 | `test_resource_tokens::test_several_counters_float_left_to_right_a_stagger_apart` |
| AC4 | `test_resource_tokens::test_starting_and_restarting_a_game_floats_nothing` |
| AC5 | `test_resource_tokens::test_a_supply_purchase_floats_up_from_the_screens_wealth_counter` (114, unchanged: one token), `test_closing_the_supply_screen_after_buying_floats_nothing` |
| AC6 | `test_resource_tokens::test_with_reduce_motion_a_gain_fades_in_place_below_its_counter` |
| Changed | `test_resource_tokens::test_a_food_gain_still_flies_from_the_card_to_the_food_counter` → `test_a_food_gain_floats_up_from_the_food_counter`; `test_grow_meter`: the grow animation test and its Reduce motion twin now expect "+1 pop" below the Pop counter, and `test_pop_from_a_card_fills_pips_without_a_token` → `test_pop_from_a_card_fills_pips` (no pip pops in); `with_fixture_main` refreshes after setting 10 food and wealth and lets those tokens finish |

## Manual check
- [ ] `godot --path .`, any seed. Play a few cards, grow, end a turn: every change to Food, Wealth, Score and Pop rises from its counter.
- [ ] End a turn with several changes: the tokens ripple left to right, readable, not overlapping.
- [ ] New game and Restart: no tokens.
- [ ] Reduce motion: tokens fade in place.

## Log
- 2026-09-30: Specced from 124's review: the user wants the "+1 pop" token to rise from the Pop counter like the
  costs, as a general pattern. Chosen: card gains rise from their counter too; one net token per counter per change;
  Food, Wealth, Score and Pop.
- 2026-09-30: Red. Starvation is a Famine now (083): the test starves pop on the second hungry upkeep. With 1 VP per
  pop, pop changes also float "±N VP". AC4 and AC5's closing test pass already (nothing floats today); they guard the
  baseline reset.
- 2026-09-30: Green, 810 → 822 tests. `TopBar.refresh(e, layer, quiet)` remembers each counter's last value and
  floats the difference (`_float_changes`); `reset_counters()` on a new game; quiet while the supply screen is open.
  Gone: `TopBar.fly_outcome`, `fly_grow`, `resource_label`, `UIKit.fly_token`, `MainScreen.fly_grow`,
  `_outcome_point`; the meter keeps only the pip pop-in.
- To start each token under its counter's new width, the bar lays itself out at the end of its refresh instead of
  next frame. Approved with the user: `test_log_drawer::test_dealt_cards_start_from_the_log_button…` now reads the Log
  button's position after the end turn (it really moves when the counters change width). Also fixed in the AC3 test:
  it read freed tokens' text and measured the stagger in rounded steps; it now compares seconds.
