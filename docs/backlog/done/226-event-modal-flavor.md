---
id: 226
title: Show the event's flavor text in the drawn-event modal
type: feature
status: done
branch: feat/226-event-modal-flavor
---

## Goal
When the event phase draws an event, the modal that announces it also shows the event's flavor line (the same
`flavor` the card details show), so the event reads as history, not just numbers.

## Acceptance criteria
- [x] AC1: Given an event whose def has `flavor` "A great flood covered the plain.", when the drawn-event modal opens
  for it, then `main.event_modal().flavor` is that text.
- [x] AC2: Given an event with no flavor, when the modal opens, then `flavor` is "" and no flavor label is visible.
- [x] AC3: Given the modal shows an event with flavor, when it is closed, then `event_modal()` is `{}` as before (the
  flavor is part of the shown state, not a separate modal).

## Out of scope
- Quotes (events have none); adding or rewriting flavor text in `data/cards.json`.
- Changing the summary or lasts lines.

## Design notes
- The text comes from the engine (`GameEngine.card_details`/`def.flavor`), not a literal in `ui/`.
- `EventModal.shown()` gains a `flavor` key; the label sits between the heading and the summary, italic (`RichBody`
  `[i]` like the details modal, via `CardDetailsModal.body_bbcode`).

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_event_modal::test_the_modal_shows_the_events_flavor` |
| AC2 | `test_event_modal::test_an_event_without_flavor_shows_no_flavor_line` |
| AC3 | `test_event_modal::test_closing_the_modal_clears_the_flavor_too` |

## Manual check
- [ ] Draw an event with flavor (`godot --path . -- --civ sumer --turns 20 --seed 5`): the italic line shows under "A new event".

## Log
