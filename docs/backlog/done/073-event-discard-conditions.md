---
id: 073
title: Event discard conditions beyond duration
type: feature
status: wontfix
branch: feat/073-event-discard-conditions
---

## Goal
Since 039 an event only ends when its turns run out. Let an event end when the player does something about it, so
events can be threats the player answers, not only weather to wait out.

## Acceptance criteria
<!-- Draft: pick the conditions first (see Design notes); each gets loader and upkeep criteria like these. -->
- [ ] AC1 (`until_tag`): Given an event with `discard: {"until_tag": "culture"}` active, when a card tagged `culture`
  is on the tableau at upkeep, the event's upkeep effects resolve and then it moves to `event_discard`.
- [ ] AC2 (`until_resource`): Given `discard: {"until_resource": {"wealth": 5}}`, at upkeep with 5 or more wealth on
  hand (after upkeep effects), the event ends. Wealth is not spent.
- [ ] AC3 (combined): Given `{"turns": 3, "until_tag": "culture"}`, the event ends at whichever comes first.
- [ ] AC4 (loader): an unknown tag or resource, or a threshold below 1, is a load error naming the card and `discard`.
  An event with conditions but no `turns` never ends by time.
- [ ] AC5 (text and panel): card text gives each condition ("Ends when you have a Culture card"); the event panel
  (068) shows it instead of "N turns left" when there is no `turns`.

## Out of scope
- Paying to discard an event (an action with a cost): a separate item, since it adds a player action.
- Pop thresholds, until harmful events exist that call for them.

## Design notes
- `CardDef.discard_turns` becomes one of several discard fields; `DataLoader.DISCARD_CONDITIONS` gains the new keys.
- The check stays at upkeep, after the event's upkeep effects (039).
- Deferred: which conditions to build is decided per event, when harmful event content is designed. The two
  criteria above are examples, not a commitment; rewrite them once the events that need them exist.
- `event_turns_left` returns 0 for an event with no `turns`; the panel needs another query (for example
  `event_ends_text(uid)`).

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_events::test_…` |

## Log
- From 039's follow-ups.
- Deferred: discard conditions are event-specific; pick them with the harmful event content. Stays `draft`.
- 2026-10-01: closed as `wontfix` while tidying the backlog. No event has asked for a discard condition since
  harmful events shipped (072, 083). Re-spec from this file when one does.
