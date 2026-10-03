---
id: 234
title: The explore choice's first card draws the focus ring before Tab
type: bug
status: red-review
branch: fix/234-explore-choice-focus-ring
---

## Reproduction
- Seed: any; a hand with a Scout (or any card with an explore effect).
- Steps:
  1. Start a game and use only the mouse (never press Tab).
  2. Play the Scout: the explore choice opens with its revealed territories.
- Expected: no focus ring until Tab (230); the first choice card is still the keyboard's starting point.
- Actual: the first choice card draws the teal card focus ring.

## Acceptance criteria
- [ ] AC1: Given pointer mode (no Tab pressed) and an explore choice of two territories, when the choice opens, then
  the first choice card has the card focus (`main.focus.focused`) but draws no ring; pressing Enter keeps it (it goes
  to the frontier and the choice ends).
- [ ] AC2: Given AC1's choice, when Right is pressed, then the second choice card has the focus and draws the ring.
- [ ] AC3: Given keyboard mode (Tab pressed), when the explore choice opens, then its first card draws the ring.
- [ ] AC4: Given pointer mode and no card focused, when Right is pressed in the hand, then the first hand card has the
  focus and draws the ring (unchanged).

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_focus_ring::test_bug_234_the_explore_choice_focuses_its_first_card_with_no_ring` |
| AC2 | `test_focus_ring::test_bug_234_right_on_the_explore_choice_shows_the_ring` |
| AC3 | `test_focus_ring::test_bug_234_after_tab_the_explore_choice_shows_the_ring` |
| AC4 | `test_focus_ring::test_bug_234_right_in_the_hand_still_shows_the_ring` |

## Root cause

## Manual check
- [ ] `godot --path .`: with the mouse only, play a Scout: the explore choice opens with no ring. Press Right: the
  ring shows on the second card. Press Enter: it is kept.
- [ ] Press Tab once, then play another explore card: the first choice card has the ring.

## Log
- Design: CardFocus places the ring itself (`CardView.set_focused`), not through `grab_focus`, so 230's helper never
  saw it. A card focus the code places (sync's explore choice) follows `FocusRing.keyboard`; one the keys place
  (Left/Right/Up/Down/Enter) draws. Test hook: `CardView.shows_focus_ring()`.
