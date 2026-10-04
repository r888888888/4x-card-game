---
id: 258
title: A click outside the supply panel closes the supply screen
type: feature
status: in-progress
branch: feat/258-supply-click-outside-closes
---

## Goal
The supply screen closes like a modal does: a click on the dimmer, outside its panel, dismisses it, so the player
needn't find the Close button or press S / Esc.

## Acceptance criteria
- [ ] AC1: Given the supply screen open, when the player clicks the dimmer outside its panel (the window's far
  corner), then the screen closes (`is_open()` is false) and `closed` is emitted.
- [ ] AC2: Given the supply screen open, when the player clicks inside its panel but on no card or button (its
  title), then it stays open.
- [ ] AC3: Given the supply screen open and a pile card's details modal open over it, when the player clicks outside
  the details modal's sheet, then only the details modal closes and the supply screen stays open.

## Out of scope
- Turning the supply screen into a `Modal` on `main.modals` (it stays its own overlay).

## Design notes
UI only (`ui/supply_screen.gd`): the dimmer's input closes the screen on a mouse press outside the panel's rect,
as `Modal._on_scrim_input` does.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_supply_screen::test_a_click_outside_the_panel_closes_the_supply` |
| AC2 | `test_supply_screen::test_a_click_inside_the_panel_keeps_the_supply_open` |
| AC3 | `test_supply_screen::test_a_click_outside_a_details_modal_closes_only_the_modal` |

## Manual check
- [ ] Open the supply (S), click beside the panel: it closes. Click between cards: it stays open.

## Log
