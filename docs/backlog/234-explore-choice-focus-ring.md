---
id: 234
title: The explore choice's first card draws the focus ring before Tab
type: bug
status: review
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
- [x] AC1: Given pointer mode (no Tab pressed) and an explore choice of two territories, when the choice opens, then
  the first choice card has the card focus (`main.focus.focused`) but draws no ring; pressing Enter keeps it (it goes
  to the frontier and the choice ends).
- [x] AC2: Given AC1's choice, when Right is pressed, then the second choice card has the focus and draws the ring.
- [x] AC3: Given keyboard mode (Tab pressed), when the explore choice opens, then its first card draws the ring.
- [x] AC4: Given pointer mode and no card focused, when Right is pressed in the hand, then the first hand card has the
  focus and draws the ring (unchanged).

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_focus_ring::test_bug_234_the_explore_choice_focuses_its_first_card_with_no_ring` |
| AC2 | `test_focus_ring::test_bug_234_right_on_the_explore_choice_shows_the_ring` |
| AC3 | `test_focus_ring::test_bug_234_after_tab_the_explore_choice_shows_the_ring` |
| AC4 | `test_focus_ring::test_bug_234_right_in_the_hand_still_shows_the_ring` |

## Root cause
CardFocus draws the card ring itself (`CardView.set_focused`), not through `grab_focus`, so 230's `FocusRing.focus`
and its `grab_focus` check never covered it; `CardFocus.sync` put the ring on the first explore choice card whenever
the choice opened. 230 had put the card ring out of scope on the belief that only keys place it. Now
`CardFocus.set_card(view, shown := true)`: sync passes `FocusRing.keyboard`, so the card holds the focus (Enter still
keeps it) with no ring or lift in pointer mode; every key-driven placing still draws.

## Manual check
- [ ] `godot --path .`: with the mouse only, play a Scout: the explore choice opens with no ring. Press Right: the
  ring shows on the second card. Press Enter: it is kept.
- [ ] Press Tab once, then play another explore card: the first choice card has the ring.

## Log
- Design: CardFocus places the ring itself (`CardView.set_focused`), not through `grab_focus`, so 230's helper never
  saw it. A card focus the code places (sync's explore choice) follows `FocusRing.keyboard`; one the keys place
  (Left/Right/Up/Down/Enter) draws. Test hook: `CardView.shows_focus_ring()`.
- `test_cabinet_doors` (timings) and `test_engine_scaling` flaked once each under load; both pass on rerun.
