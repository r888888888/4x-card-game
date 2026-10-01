---
id: 033
title: Show the supply on its own screen
type: feature
status: done
branch: feat/033-supply-screen
---

## Goal
The supply (032) is a column of text buttons under the log, easy to miss and without the card faces.
Give it its own screen, opened from a button or S, where each pile is shown as a full card you click to buy.

## Acceptance criteria
<!-- UI-only item. Checked in the running game. The engine calls are the 032 API (supply, buy_price, buy_error, buy). -->
- [x] AC1: Given a game whose config has a supply, then the side column has a "Supply (S)" button above
  Research, and the 032 buy buttons are gone from the side column. With no supply in the config, the
  button is hidden.
- [x] AC2: Given no explore or research choice is open and the game isn't over, when I click "Supply (S)"
  or press S, then an overlay opens over the dimmed board with the title "Supply" and one full-size card per
  pile in config order (Scout, Settler, Temple, Granary), each with "N wealth · M left" under it.
  It opens even when nothing can be bought (turn 1, 0 wealth) or while a hand-limit discard is owed.
- [x] AC3: Given the screen is open and I have 3 wealth, when I click Scout (price 2, 2 left), then wealth
  is 1, the discard has 1 more card, the line under Scout reads "2 wealth · 1 left", and the screen stays open.
- [x] AC4: Given the screen is open, a card that `buy_error` refuses is dimmed, its tooltip starts with
  the reason (for example "Scout costs 2 wealth (you have 1)."), and clicking it changes nothing (same wealth,
  discard and count) and shows the reason, the same way a refused hand card does.
- [x] AC5: Given the screen is open, when I press Esc or S, or click Close, then it closes and the game is
  unchanged. While it is open, E doesn't end the turn, R doesn't research, and hand cards can't be played,
  dragged or discarded. Left/Right move the focus between supply cards, and Enter buys the focused one.
- [x] AC6: The Supply button is disabled (with the reason in its tooltip) and S does nothing while an
  explore choice or research options are open, or after the game is over.
- [x] AC7 (buy flourishes): When a buy succeeds, then (a) the pile card does the tableau landing
  squash (`LAND_SQUASH`, `LAND_TIME`); (b) a "−2 wealth" token flies from the Wealth counter to the pile card
  (like a hand card's cost); (c) a copy of the card flies from the pile to the Discard counter and fades
  out, and the counter pulses when it lands (like a played action). A refused click does none of these,
  only the AC4 shake and reason.
- [x] AC8 (screen flourishes): When the screen opens, the panel fades in and the pile cards pop in one
  after another (`POP_IN_TIME`, `DEAL_STAGGER` apart). Under the mouse a pile card lifts and grows like a
  hand card (`HOVER_LIFT`, `HOVER_SCALE`). With Reduce motion on (016), there is no squash, flight,
  stagger or lift: the panel and cards fade in (`CALM_FADE_TIME`) and the token appears at its end point and fades.

## Out of scope
- Engine or rule changes: prices, counts, limits and the 032 API stay as they are.
- Showing cards you own, deck contents, or a card-removal (retire) action on this screen.
- Considered and not chosen: a "Sold out" stamp, a glow on affordable cards, an "N affordable" hint on the
  Supply button. Sound (the game has no audio yet).

## Design notes
- No engine change, so no new automated tests. The screen calls only `supply()`, `buy_price()`,
  `buy_error()` and `buy()`. The rule for when the screen opens (AC6) repeats conditions the End turn
  button already checks in the UI: `is_over`, `pending_choice`, `research_options()`.
- Build it with `_overlay()`, like Research, with z-order between the choice overlays and the menu. The menu
  (Esc when nothing is focused) still opens above it.
- Card faces: a display-only `CardInstance` per pile (a uid that isn't used anywhere else, for example negative) set up
  through `CardView.setup(..., in_hand = false)`, pickable like the research row. The views live on the
  overlay and are not part of the board's `_views` map.
- Flourishes reuse what exists: `CardView._land()` / `pop_in()` / `leave()`, `main._fly_token()` and
  `_pulse()`, and the `Anim` constants. No new tuning constants unless one is needed, and then only in `anim.gd`.
  Every flourish checks `_calm()`.
- Keyboard: S toggles the screen. While it is open, `_focus_row()` returns the supply cards, as it does for
  the research row.

## Test plan
| AC | Test |
|---|---|
| all | Manual (UI only). Also run by a scratch driver (not committed) that loads the real main scene, sends keys and clicks, and checks engine and UI state: 28 checks over AC1–AC6 and AC8 (reduce motion), all passing. The suite stays at 344, green. |

## Manual check
Run `godot --path .`.
- [ ] **AC1:** the side column has "Supply (S)" above Research, and there are no buy buttons under the log.
- [ ] **AC2:** on turn 1 press S. The Supply panel fades in and Scout, Settler, Temple and Granary pop in one after another, each reading "N wealth · M left" and dimmed (0 wealth).
- [ ] **AC4:** click Scout: it shakes, "Scout costs 2 wealth (you have 0)." floats up, and nothing changes.
- [ ] **AC3/AC7:** once you have 2+ wealth, open it and click Scout. The card squashes, "−2 wealth" flies from the panel's Wealth counter to the card, a copy flies to the Discard counter, which pulses, and the line reads "1 left". The screen stays open.
- [ ] **AC8:** hover a pile card: it lifts and grows like a hand card.
- [ ] **AC5:** with the screen open, E and R do nothing. Left/Right move the focus ring, Enter buys, and S or Esc closes it.
- [ ] **AC6:** press R to research: the Supply button is disabled and its tooltip says "Buy a tech or decline first."
- [ ] Menu → Reduce motion on, then reopen: cards fade in with no pop, lift, squash or flight.

## Log
- 2026-09-29: Specced from the user's request. User chose: overlay, Supply (S) button with full cards,
  stay open after buying, always opens (cards dimmed when blocked).
- 2026-09-29: Flourishes added (AC7, AC8). User chose: card flies to discard, wealth token, squash on
  click, cards deal in on open, hover lift.
- 2026-09-29: Approved by the user as one item (8 criteria, UI only).
- 2026-09-29: The screen has its own Wealth and Discard counters: the top bar's sit under the 65% dimmer,
  and the board's effects layer draws under overlays, so tokens and errors would be hidden. They fly
  to/from the panel's counters on the panel's own effects layer. `_fly_token` and `_show_error` take an optional layer.
- 2026-09-29: CardView: `pop_in` takes a delay, `squash()` split out of `_land`, `lift_on_hover` for
  non-hand cards, `set_buy_info` (price line, dimming, tooltip led by the reason).
- 2026-09-29: The scratch driver found that opening filled in the cards before the screen was shown, so
  they had no price line; fixed. Also fixed a missing space in `_research_button = _button(` from 032.
