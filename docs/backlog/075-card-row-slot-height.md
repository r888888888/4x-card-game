---
id: 075
title: Frontier and Known rows change height when a card lands in them
type: bug
status: done
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
- [x] AC1: Given a card flying into the Frontier row (explore, keep a territory), before it lands its slot is already
  the height it rests at (a compact card, `CardView.COMPACT_SIZE.y`).
- [x] AC2: Given a bought tech flying into the Known row (play Research, buy a tech), before it lands its slot is
  already a compact card's height.
- [x] AC3: Hand slots keep their height (a hand card plus the lift room).

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_card_slots::test_bug_075_frontier_slot_starts_at_compact_height` |
| AC2 | `test_card_slots::test_bug_075_known_slot_starts_at_compact_height` |
| AC3 | `test_card_slots::test_hand_slots_keep_their_height` (guard, passes already) |

## Root cause
`MainScreen._new_slot` sized every non-hand slot as a full tableau card (`CardView.TABLEAU_SIZE`), whatever the card.
Compact cards (frontier territories, known techs) only shrank their slot in `_fit_to_slot`, once at rest, so the row
changed height on the frame a flying card landed. Fixed by sizing the slot from the card: the new `CardView.slot_size()`
(nominal size plus the hand's lift room). No test caught it: the UI tests check which views exist, not slot sizes, and
the jump only showed once 053 put the Realm (which takes the spare height) above the Frontier.

## Manual check
- [ ] Play Scout and keep a territory: the Frontier row appears at its final height and does not jump when the card
  lands. Same for the first tech bought into the Known row.

## Log
- 2026-09-29: Found in the 053 manual check. Reproduced by recording frames of the real scene: the frontier section went
  from y=415 h=208 to y=444 h=128 on the frame the card landed. Cause: `main.gd`'s `_new_slot` sizes every non-hand slot
  as `TABLEAU_SIZE`, and `CardView._fit_to_slot` only corrects it once the card is at rest.
- Fix verified in the rendered scene: frontier and Known sections keep 128px on every frame through the landing.
