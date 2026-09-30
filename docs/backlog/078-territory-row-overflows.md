---
id: 078
title: A territory with many cards pushes the side panel off screen
type: bug
status: ready
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
- [ ] AC1: Given the main scene with one territory holding 10 tableau cards, the tableau's minimum width
  (`tableau.get_combined_minimum_size().x`) is no greater than with the same territory holding 1 card. The group's
  cards wrap instead of widening it.
- [ ] AC2: Given the same 10-card territory, every one of its 10 cards still has a view inside that territory's group
  (none are dropped or moved to another group).
- [ ] AC3: The ghost slot shown by `move_ghost(uid)` for a dragged building still goes at the end of that territory's
  cards (guard).

## Test plan
| AC | Test |
|---|---|

## Root cause
<!-- Filled in by Claude after the fix: what was wrong and why the tests didn't catch it. -->

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
