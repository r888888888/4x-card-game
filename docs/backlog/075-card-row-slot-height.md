---
id: 075
title: Frontier and Known rows change height when a card lands in them
type: bug
status: red-review
branch: fix/075-card-row-slot-height
---

## Reproduction
- Seed: any (recorded with seed 7).
- Steps:
  1. Play Scout (explore) and keep a territory.
  2. Watch the Frontier row while the territory flies into it.
- Expected: the row appears at its final height and stays put.
- Actual: while the card flies, its slot is a full tableau card tall (175px), so the section is 208px high. When the
  card lands it shrinks the slot to the compact card (95px) and the section snaps to 128px. With the Realm above the
  Frontier (053) the Frontier row visibly jumps down about 30px. The Known row (also compact) does the same when a bought tech
  flies into it. (Events pop in at rest, so their row does not jump.)

## Acceptance criteria
- [ ] AC1: Given a card flying into the Frontier row (explore, keep a territory), before it lands its slot is already
  the height it rests at (a compact card, `CardView.COMPACT_SIZE.y`).
- [ ] AC2: Given a bought tech flying into the Known row (play Research, buy a tech), before it lands its slot is
  already a compact card's height.
- [ ] AC3: Hand slots keep their height (a hand card plus the lift room).

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_card_slots::test_bug_075_frontier_slot_starts_at_compact_height` |
| AC2 | `test_card_slots::test_bug_075_known_slot_starts_at_compact_height` |
| AC3 | `test_card_slots::test_hand_slots_keep_their_height` (guard, passes already) |

## Root cause
<!-- Filled in by Claude after the fix. -->

## Manual check
- [ ] Play Scout and keep a territory: the Frontier row appears at its final height and does not jump when the card
  lands. Same for the first tech bought into the Known row.

## Log
- 2026-09-29: Found in the 053 manual check. Reproduced by recording frames of the real scene: the frontier section went
  from y=415 h=208 to y=444 h=128 on the frame the card landed. Cause: `main.gd`'s `_new_slot` sizes every non-hand slot
  as `TABLEAU_SIZE`, and `CardView._fit_to_slot` only corrects it once the card is at rest.
