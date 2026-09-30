---
id: 114
title: Cost tokens float up from the counter
type: feature
status: done
branch: feat/114-cost-tokens-float-up
---

## Goal
When food or wealth is spent, the "−N food" / "−N wealth" token today flies from the counter towards the played
card (or, in the supply screen, the bought pile), dragging the eye to the middle of the screen. Instead it should
float straight up from the counter and fade out, so a cost reads as "this left your stock" and stays by the counter.
Gains ("+N food", "+N VP") keep flying to their counters and pulsing them.

## Acceptance criteria
<!-- UI tests: tokens are placed on the fx layer; step their tweens to read positions. -->
- [x] AC1: Given a card that costs 2 food is played, when its outcome is shown, then a "−2 food" token appears just
  below the food counter and, over its lifetime, moves only upward (x unchanged, y decreasing by
  `Anim.TOKEN_FLOAT_PX`), fades to transparent and is freed; it never moves towards the played card.
- [x] AC2: The same holds for a wealth cost paid when playing a card: the "−N wealth" token floats up from the
  wealth counter.
- [x] AC3: Given the supply screen is open and a pile costs 3 wealth, when it is bought, then the "−3 wealth"
  token floats up from the screen's wealth counter as in AC1, not towards the bought pile.
- [x] AC4: Given a card that costs food and wealth, when played, then both tokens float up from their own counters,
  the second starting `Anim.TOKEN_STAGGER` seconds after the first (as today).
- [x] AC5: Gains are unchanged: a "+N food" token still flies from the played card to the food counter and pulses it.
- [x] AC6: With Reduce motion on, a cost token appears just below its counter, holds and fades out without moving
  (today it appears at the played card).

## Out of scope
- Gain and VP tokens (AC5), error messages, card motion.
- Any other change to token text, size or colour.

## Design notes
- UI only (`ui/ui_kit.gd`, `ui/top_bar.gd`, `ui/supply_screen.gd`, `ui/anim.gd`). No engine change.
- Likely a new `UIKit.float_token(layer, text, from, color, delay)` beside `fly_token`; costs call it and no longer
  need the target point. New constant `Anim.TOKEN_FLOAT_PX` (about 40 px) and float time (about `TOKEN_FLY_TIME`).

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_resource_tokens::test_a_food_cost_floats_up_from_the_food_counter` |
| AC2, AC4 | `test_resource_tokens::test_food_and_wealth_costs_float_up_from_their_own_counters_one_after_the_other` |
| AC3 | `test_resource_tokens::test_a_supply_purchase_floats_up_from_the_screens_wealth_counter` |
| AC5 (guard, passes today) | `test_resource_tokens::test_a_food_gain_still_flies_from_the_card_to_the_food_counter` |
| AC6 | `test_resource_tokens::test_with_reduce_motion_a_cost_fades_in_place_below_its_counter` |

## Manual check
- [ ] Play a card with a food cost: the token rises from under the food counter and fades; nothing crosses the board.
- [ ] Buy from the supply: the wealth token rises from the screen's wealth counter.
- [ ] Turn on Reduce motion and repeat: tokens fade in place under the counter.

## Log
- `UIKit.float_token(layer, text, from, color, delay)`: the token rises `Anim.TOKEN_FLOAT_PX` (40) over
  `TOKEN_FLY_TIME` (ease out) and fades over the second half; with Reduce motion it fades in and out in place.
  `fly_token` and `float_token` share `UIKit._token`. Costs no longer need the card point.
