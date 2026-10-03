---
id: 230
title: The focus ring waits for Tab
type: feature
status: red-review
branch: feat/230-focus-ring-after-tab
---

## Goal
Opening a modal or a screen gives one of its buttons the keyboard focus (the event's OK, the revolt's Keep, the menu's
Restart, Settings' first toggle, a Navigator screen's focus control), and the teal focus ring draws around it before
the player has touched Tab. A mouse player sees a ring they never asked for. Like a browser's `:focus-visible`: the
game starts in pointer mode, where a control focused by the code draws no ring; pressing Tab (or Shift+Tab) switches
to keyboard mode, where focus rings draw as now; a mouse click switches back to pointer mode. The focus itself is
unchanged in both modes, so Enter still presses the focused button.

## Acceptance criteria
- [ ] AC1: Given pointer mode (a fresh game, no Tab pressed yet), when a modal opens and focuses its action button
  (the event modal's OK, the game menu's Restart), then that button has the focus and draws no focus ring; pressing
  Enter still presses it.
- [ ] AC2: Given pointer mode, when a Navigator screen is pushed with a focus control, then that control has the focus
  and draws no ring.
- [ ] AC3: Given a modal open in pointer mode (AC1), when Tab is pressed, then the focus moves to the next button and it
  draws the ring; Shift+Tab likewise moves it back and the previous button draws the ring.
- [ ] AC4: Given keyboard mode (Tab pressed once), when another modal opens and focuses its action button, then that
  button draws the ring.
- [ ] AC5: Given keyboard mode, when the player clicks the mouse anywhere, then the game is back in pointer mode: the
  next modal that opens focuses its action button with no ring (as AC1).
- [ ] AC6: Given pointer mode on the New game screen, when Down moves the selection to the next civilization row, then
  that row draws the ring as now (220's arrow behaviour is unchanged).

## Out of scope
- The board's card focus ring (CardFocus, Left/Right on the cards): only the keyboard puts it on a card already.
- What has the focus, and which control a modal or screen focuses first.
- The ring's look.

## Design notes
- Godot 4.7 already has the mechanism: `Control.grab_focus(hide_focus := true)` focuses without drawing the focus
  state, and Tab/Shift+Tab navigation shows it. `gui/common/show_focus_state_on_pointer_event` is 1 (text fields
  only), so clicked buttons already draw no ring.
- One UI-side home for the mode (a small `ui/` class or `UIKit` statics): keyboard mode turns on when a `ui_focus_next`
  / `ui_focus_prev` press is handled, and off on any mouse button press. Every code focus (`grab_focus()` in
  `event_modal`, `revolt_modal`, `game_menu`, `settings_modal`, `game_over_overlay`, `navigator`, `main`) goes through
  one helper that hides the focus state in pointer mode. Tests read the mode and whether a control's focus is hidden.
- SelectList's `ListRowQuiet` (220) does the same job for list rows by swapping theme variations. If the shared
  helper covers it (code focus hidden, arrows shown), drop `ListRowQuiet` and its swap in this item and update 220's
  tests' expectations only where they name the variation; otherwise leave it and note why in the Log.
- UI only: no engine, autoload or loader change.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_focus_ring::test_a_modals_action_button_is_focused_with_no_ring_until_tab`, `test_focus_ring::test_the_settings_modal_focuses_its_first_control_with_no_ring`, `test_focus_ring::test_a_fresh_main_starts_in_pointer_mode` |
| AC2 | `test_focus_ring::test_a_pushed_screens_focus_control_draws_no_ring` |
| AC3 | `test_focus_ring::test_tab_and_shift_tab_in_a_modal_show_the_ring` (passes already: Godot's Tab shows the focus; a guard) |
| AC4 | `test_focus_ring::test_after_tab_the_next_modal_focuses_with_the_ring` (passes already: today every code focus rings; a guard) |
| AC5 | `test_focus_ring::test_a_click_hides_the_ring_again` |
| AC6 | `test_focus_ring::test_down_in_the_civilization_list_shows_the_ring` (passes already; a guard) |
| all | `test_focus_ring::test_no_ui_script_but_the_helper_calls_grab_focus` |

## Manual check
- [ ] `godot --path .`, click End turn until an event: its OK has no ring. Press Enter: it closes.
- [ ] Open the menu with the ☰ button: Restart has no ring. Press Tab: New game has the ring.
- [ ] With the ring showing, close the menu and reopen it with Esc: Restart has the ring. Click somewhere on the
  board, reopen the menu: no ring.
- [ ] New game screen: no ring on opening; Down shows it on the next row.

## Log
