---
id: 227
title: Move Grow out of the pop meter into an actions row in the territory view
type: feature
status: done
branch: feat/227-territory-actions-row
---

## Goal
In the territory view, Grow is the pop meter's first empty pip (124), so the action sits inside the display of what it
changes, and it vanishes at housing. Give the view a section of its own for actions, a row under the stats line and the
meter, and put Grow there as an ordinary button. The meter goes back to showing pop only, and the row has room for more
territory actions later.

```
River Meadow   Hills
▢ 2   ⌂ 2/5   ⚒ 0     ● ● ○ ○ ○
[Grow 3🌾]                              ← the actions row; why it's blocked is the button's tooltip
[city] [farm] [ ] [ ]
```

## Acceptance criteria
<!-- UI tests in the real main.tscn on TEST_CARDS, population on, territory view open on a settled territory. -->
- [x] AC1: The actions row. The view has an actions row (`territory_view.actions`) inside the box, below the stats
  line and the pop meter and above the city and buildings. `grow_button` is in it, and not in the meter.
- [x] AC2: Plain pips. Given pop 2 and housing 5, `pips()` is 5 plain pips (no buttons), the first 2 filled and the
  other 3 empty.
- [x] AC3: The Grow button. Given pop 2, housing 5 and 10 food, `grow_button` is shown and enabled, its text is
  "Grow" with the food cost `grow_cost` (3) and the food icon, and its tooltip names the action and the cost.
- [x] AC4: Blocked, with the reason as the tooltip. Given pop 2, housing 5 and 1 food, `grow_button` is shown,
  disabled, and its tooltip is `grow_error(uid)`. Given pop 5 and housing 5, the same: shown, disabled, tooltip
  `grow_error(uid)`. No separate reason line shows in the view (`grow_reason` is gone).
- [x] AC5: Growing. Given pop 2, housing 5 and 10 food, pressing `grow_button` makes pop 3 and food 7; the meter has
  3 filled pips of 5, the new one pops in (as 124 AC5), and Grow now costs 4.
- [x] AC6: Population off. With population off there are no pips and no Grow, and the actions row is hidden.

## Out of scope
- Other territory actions in the row (it holds only Grow for now).
- Changing growth rules, costs or the grow animation.
- Showing the blocked reason somewhere a keyboard user can read it (124 had it as a line; see Log).

## Design notes
- UI only, no engine change: Grow reads `grow_cost`, `grow_error` and `grow` as before. With Grow always shown, the
  UI no longer compares pop with housing to hide it (124's follow-up), so `grow_error` alone decides.
- `grow_button` stays the Grow control (test API and keyboard focus). It drops the `GrowPip` look for a normal button
  (`UIKit.button`, sized to its text); `GrowPip` goes from `GameTheme` if nothing else uses it.
- `territory_view.actions`: an `HBoxContainer` (or flow) in the box's body between the stats bar and `row`.
- Tests that change: `test_grow_meter.gd` (Grow is no longer a pip; the reason is the tooltip; at housing Grow is
  disabled, not hidden) and `test_territory_view.gd`'s `grow_reason` checks.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_grow_meter::test_grow_is_in_the_actions_row_below_the_stats_and_meter_above_the_cards` |
| AC2 | `test_grow_meter::test_the_meter_is_plain_pips_one_per_housing_with_pop_filled` |
| AC3 | `test_grow_meter::test_grow_is_a_button_reading_grow_and_its_food_cost` |
| AC4 | `test_grow_meter::test_without_enough_food_grow_is_disabled_with_the_reason_as_its_tooltip`, `test_at_housing_grow_is_disabled_with_the_reason_as_its_tooltip` |
| AC5 | `test_grow_meter::test_pressing_grow_fills_the_next_pip_and_raises_the_cost` (pop-in: 124's animation tests, unchanged) |
| AC6 | `test_grow_meter::test_without_population_there_is_no_meter_grow_or_actions_row` |
| Changed | 124's meter tests in `test_grow_meter.gd` replaced by the above (Grow was a pip; the reason was `grow_reason`; Grow hid at housing). `test_territory_view::test_the_view_shows_slots_and_pop_and_grow` (text "Grow N") and `test_grow_is_disabled_with_the_reason_when_it_cannot_grow` (reason in the tooltip) |

## Manual check
<!-- Only for UI-visible changes. Steps to try in the running game. Delete if not needed. -->
- [ ] `godot --path . -- --seed 5`. Click your home territory in the Realm to open its view.
- [ ] The pips read as pop only; Grow is a button in its own row under the stats, reading "Grow 3" with the food icon.
- [ ] Hover Grow with too little food, and again at housing: the tooltip says why.
- [ ] Grow: the pip pops in and the top bar rolls Pop and Food.
- [ ] Tab to Grow: it gets the focus ring and Enter grows.

## Log
- 2026-10-02: Specced. User choices: the row sits below the stats, Grow is a normal "Grow N🌾" button, at housing it
  shows disabled, and the reason moves from 124's dim line into the tooltip. Note: a tooltip isn't seen from the
  keyboard, which 124 fixed with the line; accepted for now.
- 2026-10-02: Red: 7 tests in `test_grow_meter.gd` replace 124's meter tests; 2 checks in `test_territory_view.gd`
  change (the "Grow N" text, the reason in the tooltip). 124's pop-in and roll tests stay as they were.
- 2026-10-02: Green, 1465 → 1466 tests. UI only: `TerritoryView.actions` (an `HBoxContainer` in the box between the
  stats bar and the cards) holds `grow_button`; `grow_reason` and the meter's reordering of Grow are gone; Grow is
  always shown with population on, and `grow_error` alone decides whether it's enabled, which settles 124's
  follow-up (the UI no longer compares pop with housing). `GameTheme`'s `GrowPip` became `IconButton`, a plain
  Button variation that only caps the icon's width (the food icon sits after the text). PLAN.md, testing.md and
  the style guide's §11.7 and sound tables updated. Checked by eye with a screenshot on seed 5, enabled and disabled.
