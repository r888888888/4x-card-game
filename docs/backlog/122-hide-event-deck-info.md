---
id: 122
title: Hide the event deck's counts
type: feature
status: red-review
branch: feat/122-hide-event-deck-info
---

## Goal
"Events · deck 13 · discard 1" tells the player how many events are left to come. Hide that: the Events heading just
says "Events", and the section only shows when there is something in it.

## Acceptance criteria
<!-- UI tests in the real main.tscn on TEST_CARDS + TEST_EVENTS (test_event_panel's with_event_engine). -->
- [ ] AC1: Given a config with an event deck, then the Events heading reads "Events" (no deck or discard counts) at the
  start and after events come and go, and its tooltip reads "One event is drawn at the end of each turn. It stays
  active until its turns run out." with no mention of events waiting for a later era.
- [ ] AC2: Given no event is active, then the Events section is hidden; given one or more events are active, then it
  is shown with its heading. (A Famine that can be relieved is itself an active event, so Relieve always shows inside it.)
- [ ] AC3: An event leaving the board still flies to the Events heading (a point), and does not error when the section
  is hidden at the end of the flight (guard).
- [ ] AC4: No config event deck: no Events section, as today (guard).

## Out of scope
- The engine's `event_deck` / `event_discard` zones and their counts in tests; the log still says "Event: …" lines.

## Design notes
- UI only (`ui/events_section.gd`): the counts text and the waiting-events tooltip line go; section visibility follows
  active events and the Relieve button. `main.event_panel()` loses "info"; `test_event_panel`, `test_event_eras`
  (the waiting-events tooltip test) change: name them at the red checkpoint. Assumption: hiding the section when empty
  is part of "hide event deck info" (the section would otherwise show a bare heading with nothing under it).

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_event_panel::test_the_events_heading_names_no_pile_counts` (replaces `test_event_info_counts_the_event_piles`); `test_event_eras::test_event_tooltip_names_no_events_waiting_for_a_later_era` (replaces `test_event_tooltip_says_how_many_events_wait_for_a_later_era`) |
| AC2 | `test_event_panel::test_the_events_section_shows_only_while_an_event_is_active` |
| AC3 | Manual check (the flight's end point is private) |
| AC4 | `test_event_panel::test_event_panel_is_hidden_without_an_event_deck` (guard, unchanged) |

## Manual check
- [ ] A new game shows no Events section until an event is drawn; when it ends, the card flies up and the section goes.

## Log
