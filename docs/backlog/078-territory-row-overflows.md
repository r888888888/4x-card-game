---
id: 078
title: A territory with many cards pushes the side panel off screen
type: bug
status: done
branch: fix/078-territory-row-overflows
---

## Reproduction
- Seed: any.
- Steps:
  1. Settle a territory and play buildings on it until it holds 6 or more tableau cards.
- Expected: the territory's cards wrap onto a new line inside its group, and the side panel (log, End turn) stays
  fully on screen.
- Actual: the group grows one card wider per card. At the 1920px base width the play area has
  1920 − 2×18 margin − 14 gap − 360 side panel = 1510px. A group of n cards needs n×245 + (n−1)×10 + 2×11 padding,
  so 6 cards need 1542px. The play area grows to fit and pushes the side panel past the right edge.

## Acceptance criteria
- [x] AC1: Given the main scene with one territory holding 10 tableau cards, the tableau's minimum width
  (`tableau.get_combined_minimum_size().x`) is no greater than with the same territory holding 1 card. The group's
  cards wrap instead of widening it.
- [x] AC2: Given the same 10-card territory, every one of its 10 cards still has a view inside that territory's group
  (none are dropped or moved to another group).
- [x] AC3: The ghost slot shown by `move_ghost(uid)` for a dragged building still goes at the end of that territory's
  cards (guard).

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_territory_row::test_bug_078_many_cards_do_not_widen_the_tableau` |
| AC2 | `test_territory_row::test_bug_078_every_card_stays_in_its_group` (guard: passes before the fix) |
| AC3 | `test_territory_row::test_bug_078_ghost_goes_after_the_groups_last_card` (guard: passes before the fix) |

## Root cause
`TerritoryGroup.row` was an `HBoxContainer`, whose minimum width is the sum of its cards. The tableau's
`HFlowContainer` wraps whole groups but can't shrink one, so a group of 6+ cards set the play area's minimum width and
pushed the side panel off screen. The UI tests only checked structure, never a minimum size. Fix: the row is an
`HFlowContainer`, and `TableauView._fit_rows` gives it the width of its cards in one line capped at the tableau's
width (on refresh, on `move_ghost` and when the tableau resizes), so a small group stays compact beside others and a
full one wraps.

## Manual check
- [ ] Play 8 or more buildings on one territory at 1920×1080 and at a narrower window: the cards wrap onto more lines,
  the Realm scrolls vertically, and the side panel stays fully visible.
- [ ] Dragging a building onto a full-width territory shows the ghost at the end of its last line.

## Design notes
- UI only (`ui/tableau_view.gd`): `TerritoryGroup.row` is an `HBoxContainer`, whose minimum width is the sum of its
  cards. The tableau's `HFlowContainer` wraps whole groups but can't shrink one, and horizontal scrolling is off, so
  the width propagates up to `body`. Likely fix: make the row a flow container limited to the tableau's width.
  No engine or data change.

## Log
- 2026-09-29: Reported by the user. The cause comes from the layout code and the arithmetic above; it hasn't been
  recorded in the rendered scene yet.
- Red: reproduced in the real main scene (seed 1, 8 Farms added to the home territory's territory card and Capital):
  the tableau's minimum width goes 522 → 2562px. AC1 compares with the game's start (2 cards) rather than 1 card.
- Approved at red. Green: the row wraps (above); main's `place` callback now takes a `Container`.
- Rendered check at 1920×1080 (10 cards on River Meadow): 5 per line, 2 lines; the side panel's right edge is at 1902.
- **Found while checking, not fixed here:** the side panel is taller than the window. Its bottom is at 1183px of 1080
  on `main` at the start of a game (1062px before 065), so End turn is off screen: 065's Government row added
  ~120px to the play area. 088 removes both the Civilization and Government rows.
