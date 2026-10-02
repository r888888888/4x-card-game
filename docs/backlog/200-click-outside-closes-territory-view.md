---
id: 200
title: A click outside the territory box closes the territory view
type: feature
status: ready
branch: feat/200-click-outside-closes-territory-view
---

## Goal
The territory view closes like a modal does: a click on the board around the territory's box goes back to the Realm,
without reaching for the breadcrumb or Esc.

## Acceptance criteria
- [ ] AC1: Given a settled territory's view is open (seed 5: Delta Marsh), when the left mouse button is pressed and
  released on the view's area outside the territory box (the empty space beside or below it), then the view goes
  back to the Realm, as the breadcrumb's Back does (the same transition and `Sfx.NAV_BACK`).
- [ ] AC2: Given the same, a click inside the box (its title, a building, an empty slot outline, the pop meter, Grow)
  does what it does today and leaves the view open.
- [ ] AC3: Given the same, a click on the hand, the top bar, the sidebar or an open modal leaves the view open.
- [ ] AC4: Given a hand card dragged and dropped outside the box but on the view, then the drop still targets the
  territory (101) and the view stays open; a right-click there does nothing.
- [ ] AC5: Given the view is already leaving (transition running), a second outside click does nothing.

## Out of scope
- Clicking outside other navigated screens.

## Test plan
| AC | Test |
|---|---|

## Manual check
- [ ] Open Delta Marsh, click the empty board to its right: it shrinks back into its card.

## Log
- Specced 2026-10-02 from the notes list.
