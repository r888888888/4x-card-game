---
id: 068
title: Event panel — active events and the event deck on screen
type: feature
status: in-progress
branch: feat/068-event-panel
---

## Goal
Since 039 an event is drawn every turn, but the player only sees it as a log line. Show the active events, how long
each lasts, and what's left in the event deck, so events can be followed at a glance. Comes before real event
content (069).

## Acceptance criteria
- [ ] AC1 (active events row): Given a game whose config has an event deck, after every turn of a `ScriptedBot` game,
  the Events row shows one card view per card in `active_events`, in the same order (test hook
  `event_view_ids()` equals the ids in `active_events`).
- [ ] AC2 (turns left): Each event view shows "1 turn left" / "2 turns left" from `event_turns_left(uid)`. With
  Trade Winds (2 turns) drawn at the end of turn 1, its view says "1 turn left" during turn 2 (hook
  `event_view_text(uid)` contains it).
- [ ] AC3 (event info): An event info label reads "Events: deck N · discard M" from the `event_deck` and
  `event_discard` sizes (hook `event_info_text()`). Its tooltip explains that one event is drawn at the end of
  each turn.
- [ ] AC4 (no events): With no `event_deck` in the config (the current real data), the Events row and the event
  info label are hidden, and the existing UI smoke test still passes.

## Out of scope
- Real event content (069).
- A modal or detail view for events (056 covers card details in general).
- Sound, or a pause/confirmation when an event is drawn.

## Design notes
- UI only: the row reads `zone("active_events")` and `event_turns_left`; no new engine rules. If the view needs a
  derived value (for example the "turns left" text), add an engine query under TDD.
- Test data: the smoke test drives the real `main.tscn`, which loads `data/`. The real data has no events until
  069, so AC1–AC3 need a test hook to start main with fixture cards and config (for example
  `Game.new_game_with(cards, config, seed)`, using `TEST_CARDS` plus the 039 fixture events).
- Placement follows 053's layout (side column, next to the research info). Build after 052 (split `ui/main.gd`)
  and 053 (board tidy), which both rework `ui/main.gd`.
- Drawing an event flies its card into the row (off with Reduce motion); ending moves it out.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_event_panel::test_event_views_match_the_active_events_after_every_turn` |
| AC2 | `test_event_panel::test_event_view_shows_its_turns_left` |
| AC3 | `test_event_panel::test_event_info_counts_the_event_piles` |
| AC4 | `test_event_panel::test_event_panel_is_hidden_without_an_event_deck`, and the existing `test_ui_smoke` tests |

## Manual check
- [ ] With fixture or 069 events: end turn 1; the drawn event flies into the Events row with "1 turn left".
- [ ] The event info label counts down the deck and shows the discard; its tooltip reads well.
- [ ] A 1-turn event leaves the row at the next upkeep; Reduce motion turns the fly-in off.
- [ ] With the current data (no events), nothing about events shows.

## Log
- Red: one test hook, `main.event_panel()` -> {visible, info, tooltip, views: [{uid, id, text}]}, instead of one per
  AC. The fixture-data hook needs no production code: tests swap `Game.engine` for a TEST_CARDS + TEST_EVENTS engine
  before opening main and put the real one back (`with_event_engine`). `open_main`, `close_main`, `play_seed_1`
  moved from `test_ui_smoke.gd` to `test_case.gd`, and the fixture events to `TEST_EVENTS` there, since two files
  use them now.
