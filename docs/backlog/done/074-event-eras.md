---
id: 074
title: Event decks that escalate by era
type: feature
status: done
branch: feat/074-event-eras
---

## Goal
PLAN.md's solo opposition is "an event deck that escalates by era". Let events belong to an era like techs, so that
when the game reaches era 2 the harsher era-2 events join the event deck.

## Acceptance criteria
- [x] AC1 (loader): an event may set `era` (int ≥ 1, default 1). `era` is no longer tech-only; on other card types it
  stays an ignored-field warning.
- [x] AC2 (setup): In a new game, era-1 events start in `event_deck`; later-era events wait in a `future_events`
  zone.
- [x] AC3 (era added): When era 2 is added (the `add_era` op, the empty research deck or an `era_unlocks`
  threshold), the era-2 events are shuffled into `event_deck` with the engine rng, once. Events already active or
  in `event_discard` stay where they are, and the era-1 events stay in `event_deck`.
- [x] AC4 (panel): the event info label's tooltip says how many events wait for a later era.

## Out of scope
- Removing easier events when an era is added (they stay; see Design notes).
- The era-2 event content itself.

## Design notes
- Reuse the research deck's era handling (`Research.add_era`, `future_techs`) rather than a second copy of it.
- Decided: when era 2 arrives, the era-1 events stay in the deck; the era-2 events are added to them.
- Depends on 072 (harmful ops), since escalation only matters once events can hurt.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_event_eras::test_an_event_may_have_an_era`, `test_event_era_validation` (era on a non-tech, non-event card stays a warning: `test_tech_eras::test_era_and_research_field_validation`) |
| AC2 | `test_event_eras::test_later_era_events_wait_in_future_events` |
| AC3 | `test_event_eras::test_adding_era_2_shuffles_its_events_into_the_event_deck_once`, `test_era_2_events_are_shuffled_in_by_seed`, `test_an_era_unlocks_threshold_adds_the_era_2_events` |
| AC4 | `test_event_eras::test_event_tooltip_says_how_many_events_wait_for_a_later_era` |

## Manual check
- [ ] No real event has an era yet (the era-2 content is out of scope), so the game looks as before: hover the
  "Events: deck … · discard …" line; its tooltip has no "wait for a later era" sentence.

## Log
- From 039's follow-ups.
- Decided: era-1 events stay when later eras are added.
- 2026-09-30: Red. Tests in a new `tests/test_event_eras.gd` with two local era-2 events (Raid, Blight). The
  warning for `era` on other types keeps naming techs (a TYPE_FIELDS warning names the field's first type).
- 2026-09-30: Green. `Research.add_era` calls `Events.add_era`, so every way an era arrives shares one hook. The event
  shuffle only draws on the rng when the era has events, so the real data (no event eras) plays exactly as before:
  `scripts/sim.sh 20` is identical to `main`. Follow-up: era-2 event content (out of scope here).
