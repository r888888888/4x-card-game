---
id: 218
title: Counters stay put when they change, with more room between them
type: feature
status: red-review
branch: feat/218-steady-counters
---

## Goal
When a resource changes, the top bar's counters jump: the "+N" / "−N" tag (181) is laid out right of the figure, so
it pushes the limit, the forecast and every counter to its right along, then they jump back when it goes. The
odometer roll already shows the change, so the tag goes. The counters also sit closer than the mock's strip
(docs/design/transitions.html: 16 px in a ~1160 px mock of the 1920 px window), so they get more room.

## Acceptance criteria
- [ ] AC1: Given the main scene with 20 food and 20 wealth, when food changes by +2 (or −3), wealth by −4, pop by +1,
  a card is played or upkeep runs, then while the figures roll and after, no counter in the top bar shows a
  "+N" / "−N" tag, and at every step of the roll each counter sits where it settles (within 0.5 px): nothing shifts
  and shifts back. With Reduce motion the figure changes at once, also with no tag.
- [ ] AC2: Given the Supply screen with 10 wealth, when a card is bought, then its Wealth counter rolls down and shows
  no tag.
- [ ] AC3: Given the top bar, then the gap between the turn plate and the first counter, and between each pair of
  neighbouring visible counters, is Tokens.SPACE_5 (24 px); the buttons keep their Tokens.SPACE_3 gaps.
- [ ] AC4: Given the main scene at 1920 × 1080 with every counter on (unrest and pop), then the top bar still fits the
  window: its last button ends inside it.

## Out of scope
- The forecast ("+1" beside a figure, 201) stays.
- A figure gaining or losing a digit (9 → 10) still widens the counter: that change lasts, it doesn't jump back.

## Design notes
- Remove `Counter.show_tag` and its tag label, `Anim.TAG_HOLD`, `TAG_STAGGER`, `CALM_TAG_HOLD`, and the tag tests in
  `test_resource_tokens.gd`, `test_grow_meter.gd`, `test_insight.gd`, `test_unrest.gd` (the tag path is unreachable).
  `UIKit.GAIN_COLOR` / `COST_COLOR` stay if anything else uses them.
- With Reduce motion the figure changes at once and nothing else marks the change (assumed: the user asked for no tag;
  the odometer's registration sound still plays).
- The counters go in their own HBox (separation SPACE_5) inside the top bar, which keeps SPACE_3 for the rest.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_resource_tokens::test_the_tags_are_gone`, `test_a_food_change_rolls_with_no_tag_and_no_counter_moves`, `test_wealth_score_and_pop_changes_roll_with_no_tag_and_no_counter_moves`, `test_a_played_cards_costs_and_gains_roll_with_no_tag_and_no_counter_moves`, `test_end_turn_upkeep_rolls_with_no_tag_and_no_counter_moves`, `test_with_reduce_motion_a_change_shows_at_once_with_no_tag_and_no_counter_moves`; `test_grow_meter::test_a_grow_pops_the_pip_in_and_rolls_pop_and_food_with_no_tags`, `test_with_reduce_motion_the_pip_doesnt_scale_and_pop_shows_no_tag`; `test_insight::test_the_top_bar_shows_insight_with_its_forecast_and_rolls_its_change_with_no_tag`; `test_unrest::test_the_top_bar_shows_unrest_out_of_the_limit_and_rolls_its_change_with_no_tag` |
| AC2 | `test_resource_tokens::test_buying_rolls_the_supply_screens_wealth_down_with_no_tag` |
| AC3 | `test_counters::test_the_counters_sit_space_5_apart_and_the_buttons_space_3` |
| AC4 | `test_board_layout::test_the_top_bar_fits_with_its_longest_texts` (existing, already green: a guard) |

## Manual check
- [ ] Play a card that gains food and wealth: the counters roll in place, nothing to their right moves.
- [ ] The counters' spacing reads like the mock's strip in docs/design/transitions.html.

## Log
- Red: the 181 tag tests (one net tag per counter, colours, stagger, Reduce motion hold, the per-cause tag tests for
  grow, Festival and starving) are replaced: tags are gone. The fixture's food and wealth go 10 → 20 so no change in
  the tests crosses a digit count. "Stays put" is measured against where each counter settles after the roll, since a
  forecast whose text changes width ("+1" → "−1") moves its neighbours for good.
