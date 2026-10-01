---
id: 117
title: A dealt card lands without the squash-and-bounce
type: feature
status: red-review
branch: feat/117-no-bounce-on-dealt-cards
---

## Goal
When the hand is dealt, each card flies in from the deck and then lands with a small squash-and-bounce, which reads as
a wiggle across the whole hand. A dealt card should fly in, fade in and settle without it. Other flights (a card
moving to a new slot) keep their landing squash.

## Acceptance criteria
<!-- UI tests on CardView/CardMotion in a plain Control tree, stepping frames by hand. -->
- [ ] AC1: Given a card dealt into a slot (`CardView.deal`), when it lands, then its scale is exactly 1 from the
  moment it arrives and for `Anim.LAND_TIME` afterwards (no squash), and it rests in its slot.
- [ ] AC2: Dealing still flies and fades: after `deal`, before landing the card is on the effects layer, and it
  fades in to full opacity and reaches its slot.
- [ ] AC3: Other flights are unchanged: given a card at rest that is sent to another slot (`fly_to_slot`), when it
  lands, then it squashes to `Anim.LAND_SQUASH` and returns to scale 1 over `Anim.LAND_TIME`.
- [ ] AC4: A rejected card that returns to its slot still shakes on landing (guard).

## Out of scope
- The fly-in, fade and stagger of a deal; the hover lift; pop-in; Reduce motion (already no squash).

## Design notes
- UI only (`ui/card_motion.gd`): `deal` marks the flight so `_land` skips `squash()`.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_card_landing::test_a_dealt_card_lands_without_a_squash` |
| AC2 (guard) | `test_card_landing::test_a_dealt_card_still_flies_and_fades_in` |
| AC3 (guard) | `test_card_landing::test_a_card_sent_to_another_slot_still_squashes_when_it_lands` |
| AC4 (guard) | `test_card_landing::test_a_rejected_card_returning_to_its_slot_still_shakes_on_landing` |

## Manual check
- [ ] Start a game and end a turn: the hand's cards fly in and settle with no bounce. Play a card to the Realm: it
  still squashes on landing.

## Log
