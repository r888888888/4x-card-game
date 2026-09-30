---
id: 070
title: Event tooltip says how long the event lasts
type: feature
status: in-progress
branch: feat/070-event-tooltip-duration
---

## Goal
Since 039 an event's short card text ends with "Lasts 2 turns", but its hover tooltip (`rules_tooltip`) leaves the
duration out. The tooltip is the full text, so it should say it too.

## Acceptance criteria
- [ ] AC1: Given Trade Winds (⟳ +1 wealth, `discard: {"turns": 2}`), `rules_tooltip` is
  "Each upkeep: +1 wealth\nLasts 2 turns".
- [ ] AC2: Given Omen (no effects, no `discard`), `rules_tooltip` is "Lasts 1 turn".
- [ ] AC3: A card with `text` set still shows only that text in both `rules_text` and `rules_tooltip`, event or not.

## Out of scope
- Showing turns left on the tooltip of an active event (the event panel shows it on the card, 068).

## Design notes
- `CardDef.rules_tooltip` appends `lasts_text()` for events, as `rules_text` already does.

## Test plan
| AC | Test |
|---|---|
| AC1, AC2 | `test_events::test_event_tooltip_says_how_long_it_lasts` |
| AC3 | `test_events::test_card_text_replaces_the_duration_on_an_event` (passes already: `text` has always replaced both forms) |

## Log
- From 039's follow-ups.
- 2026-09-30: Red. Tests sit next to 039's `test_event_text_says_how_long_it_lasts` in `test_events.gd`. The card
  details modal uses `rules_tooltip`, so event details gain the line too. A Famine card without `text` would read
  "Lasts 1 turn" (as its `rules_text` already does); the real Famine sets `text`.
