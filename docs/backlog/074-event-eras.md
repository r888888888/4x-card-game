---
id: 074
title: Event decks that escalate by era
type: feature
status: draft
branch: feat/074-event-eras
---

## Goal
PLAN.md's solo opposition is "an event deck that escalates by era". Let events belong to an era like techs, so that
when the game reaches era 2 the harsher era-2 events join the event deck.

## Acceptance criteria
- [ ] AC1 (loader): an event may set `era` (int ≥ 1, default 1). `era` is no longer tech-only; on other card types it
  stays an ignored-field warning.
- [ ] AC2 (setup): In a new game, era-1 events start in `event_deck`; later-era events wait in a `future_events`
  zone.
- [ ] AC3 (era added): When era 2 is added (the `add_era` op, the empty research deck or an `era_unlocks`
  threshold), the era-2 events are shuffled into `event_deck` with the engine rng, once. Events already active or
  in `event_discard` stay where they are.
- [ ] AC4 (panel): the event info label's tooltip says how many events wait for a later era.

## Out of scope
- Removing easier events when an era is added (open question below).
- The era-2 event content itself.

## Design notes
- Reuse the research deck's era handling (`Research.add_era`, `future_techs`) rather than a second copy of it.
- Open question: when era 2 arrives, should the era-1 events leave the deck, stay, or be diluted? The draft keeps them.
- Depends on 072 (harmful ops), since escalation only matters once events can hurt.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_events::test_…` |

## Log
- From 039's follow-ups.
