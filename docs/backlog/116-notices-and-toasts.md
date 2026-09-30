---
id: 116
title: Toasts for notable events, and an unread marker on the log
type: feature
status: review
branch: feat/116-notices-and-toasts
---

## Goal
With the log in a closed drawer (115), a few things only the log said go unseen: a famine arriving or ending, a
tech lost for being passed over, a supply pile unlocking, new era techs and events, and the targeting hint. The
engine marks those messages as notices; the UI shows each as a short toast under the top bar, and the Log button
shows when there are lines you haven't seen.

## Acceptance criteria
<!-- AC1–AC2: engine tests with TEST_CARDS. AC3–AC6: UI tests on the real main.tscn. -->
- [x] AC1: The engine emits `noticed(message)` for notable log lines, with the same text as the log line, after
  `logged`. Notable: a famine arriving ("Famine! …"), ending, and a building saving pop from it; relieving it; a tech
  lost for being passed over; a supply pile that can now be bought; an era's techs or events added; an active event
  ending. Test each with a fixture that triggers it.
- [x] AC2: Ordinary lines are not notices: given a turn where a card is played, a card bought, a tech learned,
  cards drawn and reshuffled, and upkeep gains and pop eating, then `noticed` is never emitted.
- [x] AC3: A notice shows a toast. Given the famine arrives at upkeep, then a toast with its text appears centred
  under the top bar, stays `Anim.TOAST_TIME` (3 s) and fades out; at most 3 show at once, newest on top, the oldest
  going first when a fourth arrives. With Reduce motion toasts fade in and out without sliding.
- [x] AC4: The targeting hint is a toast. Given a card that needs a target is double-clicked, then its hint
  ("… Click one (or ←/→ then Enter); Esc cancels.") shows as a toast that stays until targeting ends (a pick, Esc,
  or a cancel), then fades. Refusals don't toast (they already float over the card) but still go in the log.
- [x] AC5: Unread marker. Given the drawer is closed, when a new log line arrives, then the Log button reads
  "Log (L) •"; opening the drawer clears the marker, and lines arriving while it is open don't set it. A new game
  clears it.
- [x] AC6: Toasts never block play: they ignore the mouse, don't take focus, and hide while a modal or the menu is
  open (queued notices show when it closes, if still within their time).

## Out of scope
- An upkeep summary toast (gains, pop eating, VP at upkeep): the counters already change and pulse; note it in the
  Log if play shows it's missed.
- Changing log text or which lines are logged.

## Design notes
- Engine: new `signal noticed(message: String)`, emitted by a `_notice(message)` helper that logs and notices
  (`_log` stays for ordinary lines). The choice of what is notable is a rule and lives in the engine, not in the UI.
- UI: a `Toasts` component on the fx layer (not `main.gd`, 700-line limit); `TopBar` owns the Log button's text.
- Depends on 115 (the drawer and the Log button).

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_famine::test_a_famine_arriving_and_ending_are_notices`, `test_a_guard_saving_pop_is_a_notice`; `test_famine_relief::test_relieving_the_famine_is_a_notice`; `test_tech_passes::test_a_lost_tech_is_a_notice`; `test_supply::test_an_unlocked_pile_is_a_notice_but_learning_and_buying_are_not`; `test_tech_eras::test_an_eras_techs_added_is_a_notice`; `test_event_eras::test_an_eras_events_added_is_a_notice`; `test_events::test_an_event_ending_is_a_notice_and_drawing_one_is_not` |
| AC2 | `test_famine::test_fed_upkeeps_are_not_notices`; the "not" halves of the supply and events tests above |
| AC3 | `test_toasts::test_a_notice_shows_a_toast_under_the_top_bar_for_toast_time`, `test_at_most_three_toasts_show_newest_on_top`, `test_with_reduce_motion_toasts_fade_in_place` |
| AC4 | `test_toasts::test_the_targeting_hint_is_a_toast_until_targeting_ends`, `test_refusals_are_logged_but_do_not_toast` |
| AC5 | `test_toasts::test_the_log_button_marks_lines_not_yet_seen` |
| AC6 | `test_toasts::test_toasts_ignore_the_mouse_and_never_take_focus`, `test_toasts_hide_while_the_menu_is_open_and_show_when_it_closes`, `test_toasts_hide_while_the_tech_tree_is_open` |

## Manual check
- [ ] Play to a famine: its toast reads clearly under the top bar and is gone in about 3 s.
- [ ] Double-click Settler (or another targeted card): the hint toast stays until you pick or press Esc.
- [ ] Close the drawer, end a turn: the Log button shows the dot; open it: the dot is gone.

## Log
- Engine: `signal noticed(message)` and `GameEngine._notice(message)` (logs, then notices); famine.gd, research.gd,
  events.gd and `unlock_supply` use it for the notable lines. Notices keep the log line's text (some start with two
  spaces); toasts strip them.
- UI: `Toasts` (`ui/toasts.gd`, `main.toasts`): `notice(text)`, `hint(text)` / `clear_hint()` (DragController's
  targeting), `shown()` / `texts()`. Hidden while the menu, a start screen, the tech tree, details or the event pop-up
  is open. `LogDrawer.unread_changed` drives `TopBar.set_log_unread` ("Log (L) •").
- Made room in `main.gd` first (689 → 660): the Events section's heading, row and Relieve moved to `EventsSection`
  (`ui/events_section.gd`). main.gd is at 667 after this item.
- Test setup fix, agreed with the user at green: in `test_the_log_button_marks_lines_not_yet_seen`, each end_turn on
  the real data draws an event whose pop-up (rightly) takes L, so the test now presses its OK first
  (`end_turn_and_close_event`). The assertions are unchanged.
- A screenshot showed stacked toasts left-aligned to each other; each is now centred (`SIZE_SHRINK_CENTER`).
