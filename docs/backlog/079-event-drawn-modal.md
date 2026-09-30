---
id: 079
title: Show a modal when a new event is drawn
type: feature
status: done
branch: feat/079-event-drawn-modal
---

## Goal
An event is drawn at the end of every turn, but the player only notices it as a new card in the Events row (068)
and a log line. Pop up a modal when a new event comes into play, showing the event, what it does, how long it
lasts, and what it just did, so events can't be missed.

## Acceptance criteria
- [x] AC1 (engine signal): Given an event game whose event deck has Windfall (gain 2 food) on top, when the turn
  ends, then `event_drawn` is emitted once with an outcome `{uid, gained, vp, drawn, created}` (the `card_played`
  shape) where `uid` is Windfall's uid in `active_events` and `gained` is `{food: 2}`; it is emitted before `changed`.
- [x] AC2 (no effect): Given Omen (no effects) on top, when the turn ends, then `event_drawn` is emitted with Omen's
  uid and empty `gained`, `drawn`, `created` and `vp` 0. Given empty event deck and event discard, when the turn
  ends, then `event_drawn` is not emitted.
- [x] AC3 (modal opens): Given main running an event game with Windfall on top, when the player ends turn 1, then
  the event modal is visible and its test hook `event_modal()` returns `{uid, id: "windfall", text, lasts, summary}`
  where `text` is Windfall's generated card text, `lasts` is "Lasts 1 turn" and `summary` contains "+2" and food.
  With Omen, the summary is empty (or "No immediate effect").
- [x] AC4 (dismiss): Given the event modal is open, when the player presses Esc, Enter, clicks its OK button or
  clicks outside the panel, then it closes (`event_modal()` returns `{}`). While it is open, keys and clicks don't
  reach the board (an End Turn key press doesn't end turn 2).
- [x] AC5 (hand limit): Given the drawn event and a hand over the hand limit, when the turn ends, then the event
  modal shows first and the hand-limit discard is still pending after it is closed (`pending_kind()` unchanged).
- [x] AC6 (last turn): Given the last turn of the game, when the player ends it, then the event modal is not shown
  and the game-over overlay is.

## Out of scope
- A setting to turn the popup off.
- Modals for events ending, or for upkeep effects of events already in play.
- Sound or new animations beyond the modal's own open/close.

## Design notes
- New engine signal `event_drawn(outcome: Dictionary)` emitted from `Events.draw`, after the play effects resolve.
  Build the outcome with the same machinery as `card_play` (`_outcome` collecting `gained`, `vp`, `drawn`,
  `created`) so the UI summary reads state, not log text. No data format change.
- The engine emits `event_drawn` on the last turn too (the event is still drawn); the UI skips the modal when
  `is_over`, because it opens only on `changed` after the game-over check. (Alternatively queue the outcome and
  open on the next `changed` unless `is_over`.)
- UI: a new `ui/event_modal.gd`, modelled on `CardDetailsModal` (dimmer, big card on the left, text on the right,
  one OK button), z-ordered with the other overlays. The summary text ("+2 Food", "Drew 1 card", "+1 VP") should
  come from an engine helper (e.g. `outcome_summary(outcome)`) under TDD if no existing formatter fits.
- UI tests use `with_event_engine` from `test_event_panel.gd` (move it to `tests/lib/test_case.gd` if shared).

## Test plan
| AC | Test (`tests/test_event_modal.gd`) |
|---|---|
| AC1 | `test_event_drawn_reports_the_event_and_what_it_gave_before_changed` |
| AC2 | `test_event_drawn_for_an_event_with_no_effect_reports_nothing_gained`, `test_no_event_drawn_without_events` |
| Losses (README order note) | `test_event_drawn_reports_what_the_event_took`; summary: `test_outcome_summary_lists_gains_losses_vp_and_cards` |
| AC3 | `test_ending_the_turn_shows_the_drawn_event`, `test_an_event_with_no_effect_shows_no_immediate_effect` |
| AC4 | `test_esc_enter_ok_and_a_click_outside_close_the_modal`, `test_keys_do_not_reach_the_board_while_the_modal_is_open` |
| AC5 | `test_the_hand_limit_discard_is_still_owed_after_the_modal` |
| AC6 | `test_the_last_turn_shows_game_over_and_no_modal` |

## Manual check
- [ ] With the real data, end turn 1: a modal shows the drawn event large, its text, "Lasts N turns", and what it
  gave; the board is dimmed behind it.
- [ ] Esc / Enter / OK / click outside close it; the new event is then in the Events row.
- [ ] End the last turn: only the game-over overlay appears.

## Log
- 2026-09-30: Red. `with_event_engine` moved from `test_event_panel.gd` to `test_case.gd` (gains `overrides`).
  Beyond the ACs, following the planned-order note ("its summary covers losses as well as gains"): outcomes gain a
  `lost` map ({resource: amount} the `lose` op actually took), and `outcome_summary(outcome)` formats
  "+1 food, −2 wealth, +1 VP, drew 2 cards, created 1 card" ("" for nothing; the modal shows "No immediate effect").
- 2026-09-30: With the user's OK, three approved uid lookups changed from `active_events` to "active_events or
  event_discard" (`event_uid`): a 1-turn event has already been discarded by the next turn's upkeep when end_turn
  returns. The click-outside case needed `push_input(click, true)` (viewport, not window, coordinates) at the far
  corner (the panel is still at the origin before layout); the assertions are unchanged.
- 2026-09-30: Green. The `event_drawn` outcome also carries the event's `id`, so the modal needs no zone search.
  `start_game` closes an open event modal (an old game's event: caught by
  `test_start_screen::test_menu_and_game_over_name_the_civilization`, whose Esc it swallowed). The 20-seed sim is
  identical to `main`. `game_engine.gd` is at 675 lines (limit 700): the next engine item likely needs a split.
