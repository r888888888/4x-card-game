---
id: 326
title: A click outside the Knowledge screen closes it
type: feature
status: red-review
branch: feat/326-knowledge-click-outside-closes
---

## Goal
The Knowledge screen (the tech tree, 208) covers only the Realm; the top bar, action buttons, hand and sidebar stay
visible around it. Today only T, Esc or the header's link close it. A left click anywhere outside the sheet should
close it too, the way a click outside the log drawer closes the drawer, so the player can get back to the board
without hunting for the link.

## Acceptance criteria
- [ ] AC1: Given the Knowledge screen open over the Realm, when the player left-clicks a point outside the sheet
  (on the hand section), then the screen closes (`is_open()` is false) and the Realm is the navigator's top again.
- [ ] AC2: Given the Knowledge screen open, when the player left-clicks a hand card outside the sheet, then the
  click does nothing else: no card is selected, played or opened in a details modal, and the hand is unchanged.
- [ ] AC3: Given the Knowledge screen open, when the player left-clicks inside the sheet (on its empty background
  between tiles, or on its header outside the back link), then the screen stays open.
- [ ] AC4: Given the Knowledge screen open with a tech's details modal over it, when the player clicks outside the
  modal's panel, then only the modal closes and the Knowledge screen stays open.
- [ ] AC5: Given the Knowledge screen open, when the player right-clicks outside the sheet, then the screen stays
  open.
- [ ] AC6: Given the Knowledge screen closed (or already leaving), when the player left-clicks the hand, then the
  click works as before (nothing is consumed by the screen).

## Out of scope
- A click on the sheet's own empty space closing it (decided: clicks on the sheet never close it).
- Letting the outside click also do its normal job (decided: it only closes the screen, like the log drawer).
- Other screens on the play area's navigator (the territory view keeps its own rule, 200).

## Design notes
- UI only, no engine change. Follow the log drawer's pattern (`ui/log_drawer.gd` `_input`): while open, a pressed
  left mouse button outside `get_global_rect()` closes the screen and marks the input handled.
- It must not steal clicks meant for a modal over it: the modal stack's `_input` handles those first, or the screen
  checks that no modal is open (`main.modals`).
- Unrelated to 325 (tech tree affordability, in progress in another worktree), which also edits
  `ui/knowledge_screen.gd`; expect a small merge.

## Test plan
| AC | Test |
|---|---|
| AC1, AC2 | `test_knowledge_screen::test_a_left_click_outside_the_screen_closes_it_and_does_nothing_else` |
| AC3 | `test_knowledge_screen::test_a_click_inside_the_screen_leaves_it_open` |
| AC4 | `test_knowledge_screen::test_a_click_outside_a_tech_details_modal_closes_only_the_modal` |
| AC5 | `test_knowledge_screen::test_a_right_click_outside_the_screen_leaves_it_open` |
| AC6 | `test_knowledge_screen::test_a_click_on_the_hand_works_as_before_once_the_screen_is_closed_or_leaving` |

## Manual check
- [ ] Open the Knowledge screen (T), click a hand card: the screen slides back out and the card isn't picked up.
- [ ] Click the top bar or the sidebar rail while it's open: it closes.
- [ ] Click between tiles and on the vellum: it stays open.

## Log
