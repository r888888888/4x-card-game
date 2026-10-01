---
id: 124
title: Grow is the next pip of a pop meter, says why it's blocked, and animates into the Pop counter
type: feature
status: review
branch: feat/124-grow-pip-meter
---

## Goal
In the territory view, Grow is a "Grow (N food)" button beside a "Pop P / H" phrase: the action sits apart from what
it changes, the housing cap has to be read, and why it's disabled is only in a tooltip (never seen from the keyboard).
Show pop as a meter of pips, one per housing, whose first empty pip is the Grow control; show the blocking reason as
text; and make a successful grow visible: the pip fills and a "+1 pop" token flies into the top bar's Pop counter.

```
Pop  ● ● ○ ○ ○        pop 2, housing 5: the third pip is Grow, "+3 🌾"
         [+3 🌾]
Pop  ● ● ● ● ●        at housing: no Grow, dim line "River Meadow is at its housing (5)."
```

## Acceptance criteria
<!-- UI tests in the real main.tscn on TEST_CARDS, population on, territory view open on a settled territory. -->
- [x] AC1: Pips. Given a territory with pop 2 and housing 5, the view's pop meter (`territory_view.pips()`) has 5
  pips, the first 2 filled and the rest empty. The third pip is `grow_button`, its text is the food cost `grow_cost`
  (3) with the food icon (`Icons`, no word "food"), and its tooltip names the action and the cost. Pips 4 and 5 are
  plain empty pips, not buttons. With population off there is no meter, no Grow and no reason line (as today).
- [x] AC2: At housing. Given pop 5 and housing 5, all 5 pips are filled, `grow_button` is hidden, and the reason line
  (`territory_view.grow_reason`) is visible and reads `grow_error(uid)`.
- [x] AC3: Blocked, with room. Given pop 2, housing 5 and 1 food (cost 3), `grow_button` shows on the third pip,
  disabled, and the reason line reads `grow_error(uid)` ("Growing … needs 3 food (you have 1)."). The same holds for
  a Famine (the reason is the Famine's). When Grow is legal, the reason line is hidden.
- [x] AC4: Growing. Given pop 2, housing 5 and 10 food, pressing `grow_button` makes pop 3 and food 7; the meter then
  has 3 filled pips and `grow_button` is the fourth pip, showing 4. The top bar's Pop counter reads the new total.
- [x] AC5: Grow animation. After AC4's press, the newly filled pip pops in (scales up from below 1 back to 1 over
  `Anim.POP_IN_TIME`), a "+1 pop" token on the fx layer flies from that pip to the top bar's Pop counter and pulses it
  on arrival, and a "−3 food" token floats up from the food counter (as 114). With Reduce motion on, the pip doesn't
  scale, the "+1 pop" token appears at the Pop counter and fades without moving, and the food token behaves as 114 AC6.
- [x] AC6: Only a grow animates. Pop rising for another reason (a card's `grow` effect while the view is open) fills
  its pips without the "+1 pop" token; a refresh that changes nothing starts no animation.

## Out of scope
- A preview of growth's consequences (food each upkeep, idle buildings staffed): a later item.
- A "can grow" hint on the Realm card (the Realm card is 123's).
- Animating pop lost to starvation, or tokens for pop from card effects.
- Changing growth rules or costs.

## Design notes
- UI only, no engine change: the meter reads `pop`, `housing`, `grow_cost`, `grow_error` and `grow`.
- `grow_button` stays the Grow control (the test API and keyboard focus keep working); it is the first empty pip.
- `TerritoryView.stats` keeps its "Pop P / H" text for the Realm card; the view's own bar shows the slots text and the
  meter. 123 (in progress) changes the Realm card's line; check how it uses `stats` when this item starts.
- Tokens reuse `UIKit.fly_token` (gains, pulse on arrival) and `UIKit.float_token` (costs). The view needs the top
  bar's Pop counter position, which the board can pass in, as it does for resource counters.
- Pip look (filled, empty, the Grow pip) is a theme type variation in `GameTheme` with colours in `Palette`.
- Housing can be large; the meter wraps if needed. Note in the Log if 10+ pips look wrong.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_grow_meter::test_the_meter_has_a_pip_per_housing_with_pop_filled_and_grow_on_the_first_empty_one`, `test_without_population_there_is_no_meter_grow_or_reason` |
| AC2 | `test_grow_meter::test_at_housing_every_pip_is_filled_grow_is_hidden_and_the_reason_shows` |
| AC3 | `test_grow_meter::test_without_enough_food_grow_is_disabled_and_the_reason_shows`, `test_when_grow_is_legal_the_reason_line_is_hidden` |
| AC4 | `test_grow_meter::test_pressing_grow_fills_the_pip_and_moves_grow_to_the_next` |
| AC5 | `test_grow_meter::test_a_grow_pops_the_pip_in_and_flies_plus_one_pop_to_the_pop_counter`, `test_with_reduce_motion_the_pip_doesnt_scale_and_plus_one_pop_fades_at_the_counter` |
| AC6 | `test_grow_meter::test_pop_from_a_card_fills_pips_without_a_token`, `test_a_refresh_that_changes_nothing_starts_no_animation` |
| Changed | `test_territory_view::test_the_view_shows_slots_and_pop_and_grow` and `test_grow_is_disabled_with_the_reason_when_it_cannot_grow`: Grow's text is its cost, the reason is `grow_reason`, not the tooltip |

## Manual check
- [ ] `godot --path .`, any seed. Open your home territory from the Realm.
- [ ] Open a territory: the pips read at a glance, the Grow pip stands out as clickable and shows the food icon.
- [ ] Grow: the pip pops in, "+1 pop" flies to the top bar's Pop and pulses it, "−N food" floats up from Food.
- [ ] Grow until housing: the Grow pip disappears and the dim reason shows. Run out of food: the reason updates.
- [ ] Tab to the Grow pip: it gets the focus ring and Enter grows.
- [ ] Reduce motion on: no scaling or flying, tokens fade in place.

## Log
- 2026-09-30: Specced. Options C (consequence preview) and D (Realm-card hint) left for later. Assumed the animation
  is the pip popping in plus a "+1 pop" token flying to the top bar's Pop counter, reusing 114's tokens.
- 2026-09-30: Red. The Famine case of AC3 isn't its own test: the reason line shows `grow_error` whatever it says.
  The food icon is new (`assets/icons/food.svg`); the Grow pip carries it as its Button icon. The view's header keeps
  123's live line ("▢ F   ⌂ P/H   ⚒ W"); the meter goes in the bar beside it.
- 2026-09-30: Green, 800 → 810 tests. UI only: `TerritoryView.pips()`, `grow_reason`, `_show_meter` (reuses its
  pips), `TopBar.fly_grow` and `MainScreen.fly_grow` for the tokens; `Icons.FOOD`; `GameTheme` `PipFilled`,
  `PipEmpty`, `GrowPip` and `PIP_SIZE`. The view tells a grow from the meter apart from other pop gains by noting the
  cost while `grow` runs (its refresh is synchronous), so card effects fill pips without tokens (AC6).
- Follow-up: the meter hides Grow by comparing pop with housing in the UI; an engine query (e.g. `can_ever_grow`)
  would keep that rule out of `ui/`. Also, inside the view the header's "⌂ P/H" now repeats the meter.
