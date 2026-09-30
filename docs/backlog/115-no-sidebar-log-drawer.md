---
id: 115
title: Remove the right sidebar; the log becomes a drawer
type: feature
status: review
branch: feat/115-no-sidebar-log-drawer
---

## Goal
The right-hand column takes 360 px (about 19% of a 1920 px window) for a log most players rarely read and five
small controls. Remove it so the play area (Realm, Frontier, Known, Events, Hand) gets the full window width. Its
controls move to where they belong: identity and screens to the top bar, End turn beside the hand, the event pile
counts onto the Events heading, and the log into a drawer you open when you want it.

## Acceptance criteria
<!-- UI tests on the real main.tscn at 1920×1080 (like test_button_widths / test_identity_lines). -->
- [x] AC1: No sidebar. Given a game at 1920×1080, then main has no `SidePanel`, and the Realm row and the hand section
  (the hand, then End turn) both reach to within 40 px of the window's right edge.
- [x] AC2: The top bar carries the identity and screens. Given a game with a civilization and a government, then
  the top bar holds, after the stats and before Menu: the civilization and government buttons (text is the card's
  name, tooltip as today, pressing one opens its details), Buy Cards (S), and Knowledge (T) · era name. Each is
  hidden when it is today (no civilization / government / supply / research deck). At 1920×1080 every top bar
  control is fully on screen and each button fits its text (as `test_button_widths` checks).
- [x] AC3: End turn beside the hand. Given a game at 1920×1080, then End turn is fully on screen, to the right of the
  hand's scroll area, and vertically within the hand section; it keeps its AccentButton look, its E key and its
  "Discard N (hand limit M)" text while a discard is pending.
- [x] AC4: Event pile counts on the Events heading. Given a config with an event deck of 3 and 1 in the event
  discard, then the Events section heading reads "Events · deck 3 · discard 1" with the tooltip today's event line
  has; without an event deck the section stays hidden (as today). An event leaving the board flies to that heading.
- [x] AC5: The log drawer. Given a game, then the log is closed and not on screen. Pressing L, or the top bar's
  "Log (L)" button, opens a drawer that slides in from the right edge over the board, showing every log line so far
  (the same text and formatting as today's log, scrolled to the newest). L, Esc, the button again, or a click outside
  it closes it. New lines append while it is open or closed. A new game clears it. With Reduce motion it fades
  instead of sliding.
- [x] AC6: Nothing else moves or breaks. S, T, E, D, I and the arrow keys work as before; a government played
  flies to its top bar button; the game-over, menu, details, tech tree and event modals still open over everything,
  including an open drawer.

## Out of scope
- Toasts for notable events and an unread marker on the Log button: 116.
- Any change to what the engine logs or to log formatting.
- Restyling the top bar beyond fitting the new controls.

## Design notes
- UI only; no engine change. `SidePanel` (`ui/side_panel.gd`) goes away; a `LogDrawer` component holds the
  RichTextLabel and `append_log` / `note` / `clear_log`. The identity buttons and Knowledge move into `TopBar`
  (`identity_buttons()`, `identity_point()` follow them). `main.gd` is at 675/700 lines: the drawer and the
  moved code must not land there.
- Until 116 lands, things only the log says (famine arriving, a tech lost, a pile unlocked, the "click a target,
  Esc cancels" hint) sit in the closed drawer. Build 116 straight after this item.
- Tests that assert the old column change under this item: `test_identity_lines` (side panel order, above the
  Knowledge button, End turn on screen at 1080) and `test_button_widths` (side panel actions at its left edge,
  identity lines span the panel). Name them at the red checkpoint.
- Drawer width about 480 px; Esc closes the drawer before it opens the menu.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_board_layout::test_no_side_panel_and_the_board_spans_the_window` |
| AC2 | `test_board_layout::test_the_top_bar_holds_identity_supply_and_knowledge_before_menu`, `test_top_bar_controls_are_on_screen_and_buttons_fit_their_text` (guard); changed: `test_identity_lines::test_top_bar_shows_civilization_then_government`, `test_identity_lines_sit_before_the_knowledge_button`, `test_playing_a_government_updates_its_line` |
| AC3 | `test_board_layout::test_end_turn_sits_right_of_the_hand_on_screen`, `test_end_turn_still_ends_the_turn_and_shows_a_pending_discard` (guards; AC1 checks it moved) |
| AC4 | changed: `test_event_panel::test_event_info_counts_the_event_piles` (the Events heading carries the counts). The flight to the heading: Manual check |
| AC5 | `test_log_drawer::test_the_log_starts_closed_and_off_screen`, `test_l_opens_the_drawer_at_the_right_edge_with_the_log_so_far`, `test_with_reduce_motion_the_drawer_fades_in_place`, `test_the_log_button_esc_and_a_click_outside_close_it`, `test_lines_append_while_closed_and_a_new_game_clears_it`; changed: `test_action_errors` reads the log through `main.log_drawer.text()`, `test_theme::test_panels_look_as_before` finds the log panel in the drawer |
| AC6 | the existing suite (keys, modals, identity details); modals over an open drawer and the government's flight: Manual check |
| removed | `test_button_widths::test_side_panel_actions_fit_their_text_at_its_left_edge`, `test_identity_lines_still_span_the_side_panel` (the side panel is gone) |

## Manual check
- [ ] Play a government: it flies to its top bar button. An event ending flies to the Events heading.
- [ ] With the drawer open, open the tech tree (T), a card's details (I) and the menu: each shows above the drawer.
- [ ] At 1920×1080 the Realm fills the width; nothing in the top bar is cut off or wraps (check late game too: bigger
  numbers, a long civilization, government or era name).
- [ ] The deck and discard counts and End turn sit bottom-right; with 8+ cards the hand scrolls without covering them.
  Dealt cards come from the Deck count, discarded ones fly to the Discard count.
- [ ] L opens the log drawer from the right and it reads like today's log; Esc and L close it.
- [ ] A smaller window (1600×900): the top bar still fits (note in the Log if not).

## Log
- The top bar didn't fit at 1920: stats (~890 px at size 26), six buttons (~860 px) and 36 px gaps needed ~2280 of
  1884 px. Agreed with the user: "Deck N · Discard M" moved out of the top bar to sit above End turn beside the hand
  (`TurnBox`: the counts, End turn and `pile_point`), and the top bar's gap went from 36 to 20 px (one separation for
  the whole bar; the tests read the bar as one row). It now needs ~1817 px: little slack for long names late game.
- `LogDrawer` (`ui/log_drawer.gd`) takes over `SidePanel`'s log; `TopBar` has the identity buttons, Knowledge and
  Log (L). The drawer covers the full height, so it hides the top bar's Knowledge, Log and Menu buttons while open
  (L, Esc or a click outside closes it). Follow-up if that bothers: start it below the top bar.
- `main.gd` is at 689/700 lines after this item. The next item touching it should split something out first.
