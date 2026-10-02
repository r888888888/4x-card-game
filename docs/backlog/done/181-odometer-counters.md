---
id: 181
title: Odometer counters and +N tags instead of floating tokens
type: feature
status: done
branch: feat/181-odometer-counters
---

## Goal
A resource change reads like a mechanism ([docs/design/mcm-style-guide.md](../design/mcm-style-guide.md) §10.3–§10.4,
§15.5): the counter's digits roll to the new value, step by step like an odometer, and a short "+3" tag sits beside it
for a moment. Today a "+3 food" token floats up from the counter (114, 126), which the guide keeps for rare, important
transfers only. The odometer was proven in Godot in the `spike/mcm-godot` spike (`spike/odometer.gd`).

## Acceptance criteria
- [x] AC1: An `Odometer` showing 7, given `set_value(10)`, shows 8, then 9, then 10, one step every
  `Anim.ODOMETER_STEP` (0.07 s); `shown()` returns the value its digit columns show at that moment and `value` is 10
  from the call on. Going down works the same way (5 → 3 shows 4, then 3).
- [x] AC2: A change of more than `Anim.ODOMETER_MAX_STEPS` (8) rolls only the last 8 steps: 12 → 40 jumps to 32 and
  rolls 33 … 40; 40 → 12 jumps to 20 and rolls 19 … 12. A second `set_value` during a roll rolls on from where the
  first was heading. With Reduce motion, `set_value` shows the new value at once.
- [x] AC3: The top bar's food, wealth, insight, unrest, score and pop figures, and the Supply screen's wealth figure,
  are odometers: after a refresh that takes food from 3 to 5, the food counter's odometer `value` is 5 and
  `counter_text(GameEngine.FOOD)` reads the new value at once ("5 (+1)"), while the digits roll. A figure is
  left-aligned against its glyph and grows rightward.
- [x] AC4: When a refresh changes a counter by n ≠ 0, a tag reading "+n" or "−n" (a real minus, U+2212) in
  `UIKit.GAIN_COLOR` or `UIKit.COST_COLOR` appears directly right of that counter's figure, holds `Anim.TAG_HOLD`
  (0.6 s) and is then gone; one tag per changed counter per refresh, showing the net change (as 126's tokens did).
  Several changed counters show their tags left to right, `Anim.TAG_STAGGER` (0.06 s) apart. With Reduce motion the
  tag appears in place without moving and holds 1.5 s.
- [x] AC5: No tag appears for a refresh that changes nothing, when a game starts or restarts, or when the Supply screen
  closes after buying (as 126). Buying a card for 3 wealth on the Supply screen rolls the screen's wealth figure down
  by 3 and shows "−3" beside it.
- [x] AC6: Nothing floats any more: no "+N unit" or "−N unit" label appears on an fx layer for a counter change;
  `UIKit.float_token` and `Anim.TOKEN_FLY_TIME`, `TOKEN_FLOAT_PX` and `TOKEN_STAGGER` are gone, and the floating-token
  tests (`test_resource_tokens`, the "+1 pop floats" cases in `test_grow_meter`, the insight float in `test_insight`)
  become tag tests asserting the same counters, amounts, colours and order.

## Out of scope
- The turn number (it changes on End turn and gets a split-flap later); the Supply screen's discard count; the resource
  lamp pulse (§15.5 step 3); the stat pulse on labels that aren't odometers (the Log button keeps its pulse).

## Design notes
- `Odometer` (a `Control` with `clip_contents`, one column of 0–9 plus a second 0 per digit, tweening each column's y)
  as in `spike/odometer.gd`, in `ui/`. Its digits use the `Stat`/`BarStat` font from 178 (tabular figures), so each
  column is one digit wide.
- A counter becomes glyph + odometer + forecast label; `counter_text` (177) keeps returning the whole reading, so the
  text tests don't move again. `counter(key)` returns the counter, whose `figure()` is its odometer (for the tag's
  position).
- The tag is a `Label` in the counter's row, not on the fx layer, so it follows the figure as it widens.
- Builds on 177, 178 and 180.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_odometer::test_the_constants`, `test_rolling_up_shows_each_value_in_turn`, `test_rolling_down_shows_each_value_in_turn` |
| AC2 | `test_odometer::test_a_long_change_rolls_only_the_last_eight_steps`, `test_a_change_mid_roll_rolls_on_from_where_it_was_heading`, `test_with_reduce_motion_the_new_value_shows_at_once` |
| AC3 | `test_resource_tokens::test_a_refresh_rolls_the_figure_and_the_reading_changes_at_once`, `test_every_counters_figure_is_an_odometer`, `test_a_figure_sits_against_its_glyph_and_grows_rightward`; figure colours now read `counter(key).figure().color` in `test_resource_glyphs` and `test_unrest` |
| AC4 | `test_resource_tokens::test_the_tag_constants`, `test_a_change_shows_one_net_tag_per_counter_in_its_colour`, `test_wealth_score_and_pop_changes_tag_their_counters`, the cause tests (played cards, grow effect, grow from the meter, upkeep, starving), `test_several_tags_appear_left_to_right_a_stagger_apart`, `test_with_reduce_motion_a_tag_appears_in_place_and_holds_longer` |
| AC5 | `test_resource_tokens::test_a_refresh_that_changes_no_counter_shows_no_tag`, `test_starting_and_restarting_a_game_shows_no_tags`, `test_closing_the_supply_screen_after_buying_shows_no_top_bar_tag`, `test_buying_rolls_the_supply_screens_wealth_down_with_a_tag` |
| AC6 | `test_resource_tokens::test_the_floating_tokens_are_gone` and "nothing floats" in every tag test; changed to tag tests: `test_grow_meter` (grow, Reduce motion, no-change), `test_insight` (+3), `test_unrest` (+3) |

## Manual check
- [ ] Seed 5, Egypt: playing Barter rolls wealth up by 2 with a "+2" tag beside it; End turn rolls several counters
  with their tags appearing left to right; a 9 → 10 change rolls the ones column past 9 and the tens in from blank.
- [ ] With Reduce motion on, figures change at once and tags appear in place.

## Log
- 2026-10-01: Specced from the mid-century style guide and the `spike/mcm-godot` spike. Decided 2026-10-01: tags
  replace every floating token, the Supply screen's included.
- 2026-10-02: Built. `ui/odometer.gd` (`Odometer`: `show_now`, `set_value`, `shown`, `value`, `color`, and a
  `widened` signal emitted at once, since `minimum_size_changed` arrives a frame late) rolls a whole change in one
  tween (a tween started from another's callback would wait a frame), restarting from what its columns show when a new
  value arrives mid-roll. `ui/counter.gd` (`Counter`: glyph, optional word, odometer, tag, forecast) is each top-bar
  counter and the Supply screen's wealth ("Wealth: " stays there, as 180 kept text on that screen).
  `UIKit.float_token` and `Anim.TOKEN_*` are gone; `Anim.CALM_TAG_HOLD` = 1.5. Decided while building: with Reduce
  motion tags don't stagger (each appears at once); the tag takes room in the row while it shows, so the counters to
  its right shift by its width for `TAG_HOLD` (the spacer before the buttons absorbs it). Not done: IBM Plex Mono
  (178's note) - the odometer uses BarStat's tabular Barlow figures, which keep columns even.
