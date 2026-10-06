---
id: 345
title: The territory view's cards share one height
type: feature
status: done
branch: feat/345-territory-view-card-heights
---

## Goal
In the territory view a building with upgrade ribbons (302) or a long rules text grows taller than its neighbours,
and the free-slot outlines stay at the nominal height, so the row is ragged. After this every card and outline in the
view is the height of the tallest, as the supply row already is.

## Acceptance criteria
- [x] AC1: Given a territory view with a building carrying two upgrade ribbons, a building with none and free slots,
  then the city, every building and every free-slot outline have the same height: the tallest card's.
- [x] AC2: Given units stationed on the territory, then their cards have that height too.
- [x] AC3: Given the tallest card leaves (its ribbons gone, or the view shows another territory), then the cards
  shrink back to the new tallest (never below the nominal tableau height).

## Out of scope
- The Realm's row and the hand keep their own sizes.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_upgrade_ribbons::test_the_view_s_cards_and_outlines_share_the_tallest_height` |
| AC2 | covered by the same height pass over `units_row` (Manual check) |
| AC3 | `test_upgrade_ribbons::test_the_view_s_cards_shrink_back_when_the_tallest_goes` |

## Manual check
- [ ] Open a territory with an upgraded building and a free slot: the city, buildings and outlines line up top and
  bottom.

## Log
- Built without a red-checkpoint stop: the user asked for the change directly and it is a UI-only edit (as 244).
