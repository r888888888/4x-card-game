---
id: 181
title: Odometer counters and +N tags instead of floating tokens
type: feature
status: ready
branch: feat/181-odometer-counters
---

## Goal
A resource change reads like a mechanism ([docs/design/mcm-style-guide.md](../design/mcm-style-guide.md) §10.3–§10.4,
§15.5): the counter's digits roll to the new value, step by step like an odometer, and a short "+3" tag sits beside it
for a moment. Today a "+3 food" token floats up from the counter (114, 126), which the guide keeps for rare, important
transfers only. The odometer was proven in Godot in the `spike/mcm-godot` spike (`spike/odometer.gd`).

## Acceptance criteria
- [ ] AC1: An `Odometer` showing 7, given `set_value(10)`, shows 8, then 9, then 10, one step every
  `Anim.ODOMETER_STEP` (0.07 s); `shown()` returns the value its digit columns show at that moment and `value` is 10
  from the call on. Going down works the same way (5 → 3 shows 4, then 3).
- [ ] AC2: A change of more than `Anim.ODOMETER_MAX_STEPS` (8) rolls only the last 8 steps: 12 → 40 jumps to 32 and
  rolls 33 … 40; 40 → 12 jumps to 20 and rolls 19 … 12. A second `set_value` during a roll rolls on from where the
  first was heading. With Reduce motion, `set_value` shows the new value at once.
- [ ] AC3: The top bar's food, wealth, insight, unrest, score and pop figures, and the Supply screen's wealth figure,
  are odometers: after a refresh that takes food from 3 to 5, the food counter's odometer `value` is 5 and
  `counter_text(GameEngine.FOOD)` reads the new value at once ("5 (+1)"), while the digits roll. A figure is
  left-aligned against its glyph and grows rightward.
- [ ] AC4: When a refresh changes a counter by n ≠ 0, a tag reading "+n" or "−n" (a real minus, U+2212) in
  `UIKit.GAIN_COLOR` or `UIKit.COST_COLOR` appears directly right of that counter's figure, holds `Anim.TAG_HOLD`
  (0.6 s) and is then gone; one tag per changed counter per refresh, showing the net change (as 126's tokens did).
  Several changed counters show their tags left to right, `Anim.TAG_STAGGER` (0.06 s) apart. With Reduce motion the
  tag appears in place without moving and holds 1.5 s.
- [ ] AC5: No tag appears for a refresh that changes nothing, when a game starts or restarts, or when the Supply screen
  closes after buying (as 126). Buying a card for 3 wealth on the Supply screen rolls the screen's wealth figure down
  by 3 and shows "−3" beside it.
- [ ] AC6: Nothing floats any more: no "+N unit" or "−N unit" label appears on an fx layer for a counter change;
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

## Manual check
- [ ] Seed 5, Egypt: playing Barter rolls wealth up by 2 with a "+2" tag beside it; End turn rolls several counters
  with their tags appearing left to right; a 9 → 10 change rolls the ones column past 9 and the tens in from blank.
- [ ] With Reduce motion on, figures change at once and tags appear in place.

## Log
- 2026-10-01: Specced from the mid-century style guide and the `spike/mcm-godot` spike. Decided 2026-10-01: tags
  replace every floating token, the Supply screen's included.
