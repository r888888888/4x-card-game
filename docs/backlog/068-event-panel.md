---
id: 068
title: Event panel — active events and the event deck on screen
type: feature
status: review
branch: feat/068-event-panel
---

## Goal
Since 039 an event is drawn every turn, but the player only sees it as a log line. Show the active events, how long
each lasts, and what's left in the event deck, so events can be followed at a glance. Comes before real event
content (069).

## Acceptance criteria
- [x] AC1 (active events row): Given a game whose config has an event deck, after every turn of a `ScriptedBot` game,
  the Events row shows one card view per card in `active_events`, in the same order (test hook
  `event_view_ids()` equals the ids in `active_events`).
- [x] AC2 (turns left): Each event view shows "1 turn left" / "2 turns left" from `event_turns_left(uid)`. With
  Trade Winds (2 turns) drawn at the end of turn 1, its view says "1 turn left" during turn 2 (hook
  `event_view_text(uid)` contains it).
- [x] AC3 (event info): An event info label reads "Events: deck N · discard M" from the `event_deck` and
  `event_discard` sizes (hook `event_info_text()`). Its tooltip explains that one event is drawn at the end of
  each turn.
- [x] AC4 (no events): With no `event_deck` in the config (the current real data), the Events row and the event
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
- Drawing an event pops its card into the row; ending flies it to the event info label.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_event_panel::test_event_views_match_the_active_events_after_every_turn` |
| AC2 | `test_event_panel::test_event_view_shows_its_turns_left` |
| AC3 | `test_event_panel::test_event_info_counts_the_event_piles` |
| AC4 | `test_event_panel::test_event_panel_is_hidden_without_an_event_deck`, and the existing `test_ui_smoke` tests |

## Manual check
The real data has no events until 069. To try it now, add a throwaway event to `data/cards.json`
(`{"id": "omen", "name": "Omen", "type": "event", "discard": {"turns": 2}}`) and `"event_deck": {"omen": 2}` to
`data/config.json`, run `godot --path .`, and revert both files afterwards.
- [ ] End turn 1: Omen pops into the Events row (below Researched) with "1 turn left"; its card is coloured and
  marked ❖ as an event.
- [ ] The label under the research info reads "Events: deck 1 · discard 0"; its tooltip explains the draw.
- [ ] End turn 2: the first Omen flies to the label as it ends ("discard 1"), and the second one pops in.
- [ ] With the unchanged data (no events), no Events row or label shows.

## Log
- Red: one test hook, `main.event_panel()` -> {visible, info, tooltip, views: [{uid, id, text}]}, instead of one per
  AC. The fixture-data hook needs no production code: tests swap `Game.engine` for a TEST_CARDS + TEST_EVENTS engine
  before opening main and put the real one back (`with_event_engine`). `open_main`, `close_main`, `play_seed_1`
  moved from `test_ui_smoke.gd` to `test_case.gd`, and the fixture events to `TEST_EVENTS` there, since two files
  use them now.
- Green: the panel test's fixture deck changed from farm + scout to farm + caravan (approved): TEST_CARDS' `scout`
  only draws, so the bot replayed Scouts from the discard forever on turn 1 and the per-turn check never ran.
- Built: `ui/main.gd` (Events section, `_event_info` label, `event_panel()` hook, ending events fly to the label),
  `ui/card_view.gd` (event colour and ❖ mark, `set_event_info`, `_set_info_label` shared with techs). No engine change.
- Follow-up: an icon for the ❖ event mark in `ui/icons.gd` (techs' ✦ has none either).
