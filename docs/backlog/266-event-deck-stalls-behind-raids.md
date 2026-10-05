---
id: 266
title: Events stop when the event deck holds only raids that can't be drawn yet
type: bug
status: review
branch: fix/266-event-deck-stalls-behind-raids
---

## Reproduction
- Seed: any. Found by reading the code (event deck review, 2026-10-04), not seen in play yet.
- Steps:
  1. Early on, while `realm_size()` is under `raid_min_size` (12), each raid that comes up goes to the event deck's
     bottom (257). The non-raid events are drawn and pile up in the event discard.
  2. Play until every non-raid event has been drawn. The event deck now holds only the raids, and the discard holds
     the rest.
  3. End turns while raids still aren't allowed: the realm is still under 12, a raid is announced, or `raid_gap` turns
     haven't passed since the last strike.
- Expected: the event discard is shuffled back in and a non-raid event is drawn each turn.
- Actual: `Events.draw` reshuffles the discard only when the deck is *empty*, and `_take_allowed` sends every raid to
  the bottom and returns null. No event is drawn, so play goes eventless:
  - With raids allowed again but spaced out, this lasts about 5 turns per raid left (the 2-turn warning plus the
    4-turn gap), so up to about 10 turns in each pass through the deck.
  - A realm that stays under 12 never gets another event.

## Acceptance criteria
- [x] AC1: Given config `raid_min_size` 99, an event deck holding only a raid, and an event discard holding one
  non-raid event, when the turn's event is drawn, then the discard is shuffled into the deck, the non-raid event is
  active and reported by `event_drawn`, the raid is in the event deck, and the event discard is empty.
- [x] AC2: The same happens when raids are blocked by the gap or by an announced raid rather than by size. Given a
  raid struck at turn S with `raid_gap` 4, an event deck holding only a second raid, and a non-raid event in the
  discard, when the event is drawn at turn S+1, then the non-raid event is drawn and the raid stays in the deck.
- [x] AC3 (unchanged, 257 AC3): Given raids aren't allowed and the event deck and discard together hold only raids,
  when the turn's event is drawn, then no event is active, `event_drawn` isn't emitted, and every raid is still in the
  event deck or discard. The same holds turn after turn.
- [x] AC4 (unchanged): Given an event deck whose top is a blocked raid followed by a non-raid event, and a non-empty
  discard, when the turn's event is drawn, then the non-raid event is drawn from the deck and the discard isn't
  shuffled in. Only a deck with nothing drawable triggers the reshuffle.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_raid_pacing::test_bug_266_a_deck_of_raids_too_soon_to_draw_shuffles_the_discard_back_in` |
| AC2 | `test_raid_pacing::test_bug_266_raids_held_back_by_the_gap_dont_stop_the_events` |
| AC3 | `test_raid_pacing::test_bug_266_with_only_raids_in_both_piles_none_is_drawn_or_lost`, `test_with_only_raids_left_and_none_allowed_no_event_is_drawn` (257) |
| AC4 | `test_raid_pacing::test_bug_266_a_drawable_event_in_the_deck_leaves_the_discard_alone` |

## Root cause
`Events.draw` reshuffled the event discard only when the event deck was empty. Raid pacing (257) made some deck
cards undrawable for a while, and `_take_allowed` returns null when every card left is such a raid, so a deck of
blocked raids counted as non-empty and the turn passed with no event. 257's AC3 tested only raids in *both* piles,
not raids in the deck with events in the discard. Fix: when nothing in the deck can be drawn, shuffle the discard in
(with the raids) and try once more (`Events._reshuffle`).

## Manual check
- [ ] Play a long game without expanding (stay under 12): an event is still drawn every turn after the first pass
  through the deck.

## Log
- AC3 and AC4 tests passed before the fix: they guard behaviour the fix must keep.
- With only raids in both piles, each turn now reshuffles them together and logs the reshuffle; harmless.
