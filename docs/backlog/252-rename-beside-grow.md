---
id: 252
title: Move Rename… into the territory's action row, beside Grow
type: feature
status: review
branch: feat/252-rename-beside-grow
---

## Goal
The territory view's actions sit together: Rename… moves from beside the territory's name (a caps link, 248) into the
action row under the stats and pop meter, right after Grow (227), so everything you can do to the territory is in
one place.

## Acceptance criteria
- [x] AC1: Given a territory's view open (seed 5, Egypt, the home territory), then `territory_view.rename_button` is a
  child of `territory_view.actions`, directly after `grow_button`, and the title line (the name, the land caption and
  the info) holds no button.
- [x] AC2: Given that view, then Rename… wears the same key look as Grow (its `theme_type_variation` equals Grow's, not
  `CapsLink`) and doesn't stretch: it is no wider than its text plus padding.
- [x] AC3: Given that view, when Rename… is pressed, then the naming modal opens for that territory, as before (248's
  tests keep passing unchanged).
- [x] AC4: Given Rename… disabled by `rename_territory_error` (as in 248), then it stays in the row, disabled, with the
  reason as its tooltip; Grow beside it keeps its own enabled state and tooltip.

## Out of scope
- Grow's look, cost and behaviour; the order of any later actions added to the row.
- The naming modal itself (251 restyles its buttons and field).

## Design notes
- Assumption (no question asked): Rename… takes Grow's key look (`IconButton`, without an icon) so the row reads as one
  set of keys; a link in a row of keys would read as a different kind of thing. If you'd rather keep the link look,
  AC2 changes to `CapsLink`.
- `ui/territory_view.gd` only: build `rename_button` after `grow_button` and add it to `actions`; its doc comment
  ("Rename… beside the name") changes with it. No engine change.

## Test plan
| AC | Test |
|---|---|
| AC1, AC2, AC3 | `test_rename_modal::test_rename_sits_in_the_action_row_right_after_grow_in_its_key_look`; AC2 also `test_button_widths::test_board_buttons_fit_their_text` |
| AC3 | the 248 tests in `test_rename_modal.gd`, unchanged |
| AC4 | `test_rename_modal::test_a_refused_rename_stays_in_the_row_disabled_with_its_reason` (blocked by a pending renewal: game over closes the view) |

## Manual check
- [ ] `godot --path . -- --civ egypt --seed 5`: open the home territory: the row under the stats reads Grow (its food
  cost), then Rename…, the same height, a small gap between; the title line shows only the name, land and info.

## Log
- Rename… copies Grow's variation (`IconButton`) rather than naming it, so the row stays one look if Grow's changes.
- `CapsLink` is still used by the sidebar's government link (221).
