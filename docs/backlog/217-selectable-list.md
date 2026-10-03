---
id: 217
title: A selectable list component, and a new game screen that holds still
type: feature
status: red-review
branch: feat/217-selectable-list
---

## Goal
Choosing a civilization feels steady and clear. Today the new game sheet resizes and recentres with each
civilization's text, so it jumps as you move through the list. The selected row is also a pressed button with a pale
border, which barely stands out and looks like the teal focus ring on another row. This item adds a **selectable
list** to the style guide (option A, "Index card", from [list-options.html](../design/list-options.html)) and uses it
for the civilization list.

## Acceptance criteria
- [ ] AC1 (fixed sheet): Given the new game screen is open with the six civilizations, when each civilization is
  selected in turn (with layout settled after each), then the screen's panel keeps the same size and position, and
  every civilization's detail text fits in it without clipping (the detail body's content height ≤ its height).
- [ ] AC2 (footer): The seed field and Start sit at the foot of the detail pane, below a footer rule (a 1 px
  hairline across the pane), and Start keeps the same position on screen whichever civilization is selected.
- [ ] AC3 (the list rows): Each civilization row is a `ListRow` (a `GameTheme` variation of `Button`). Unselected,
  it draws no box or border, just its label in `TEXT_DIM` on the list's `FIELD` (well) background. Selected
  (pressed), it is a `RAISED` (sheet) strip on a hard plinth shadow, with its label in `TEXT`, moved `Tokens.SPACE_2`
  (8 px) toward the detail pane.
- [ ] AC4 (index tab): Every row has an `IndexTab` child on its leading edge, coloured `ACCENT`, `Tokens.SPACE_1`
  (4 px) wide. It is shown only on the selected row, so exactly one row shows it, and it moves to the new row when
  the selection changes by click or arrows. The `Edge` type band (212) is gone.
- [ ] AC5 (focus is not selection): A `ListRow`'s focus style is the focus ring (`GameTheme.focus_ring()`), and its
  selected style is not. When Tab moves the focus off the selected row onto another row, the selected row keeps its
  index tab and pressed state, and the focused row gains neither.
- [ ] AC6 (the component): `UIKit.select_list()` builds the list column (a `FIELD` well holding `ListRow` rows,
  with Up/Down moving the selection), and the new game screen uses it. The style guide's §7 component list gains
  "Selectable list", and tokens.md names `ListRow` and `UIKit.select_list`.

## Out of scope
- The detail text's "Rules" and "Home" set as label-caps headings: that change is in `CardDetailsModal.body_bbcode`,
  shared with the card details modal, so it's left for a separate item.
- Other lists (the settings modal, the Knowledge screen) moving to the component.
- Slide and tab-wipe animation: the selected row and tab snap into place. Motion can follow under §9 later.

## Design notes
- The sheet's height is measured when the list is filled: each civilization's detail is laid out at the pane's
  width, and the tallest sets the detail body's minimum height. This also covers future content with a longer story.
- The "pulled out" offset is a stylebox `expand_margin` and content offset, the same way `GameTheme._pressed`
  presses a button. A stylebox can't translate, so nothing moves the row's rect, and the list column reserves the
  8 px on its trailing side.
- New palette role: none. The tab uses `ACCENT`. The guide gives signal to the selection index tab (§4.2), and this
  screen has no End turn.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_start_screen::test_the_sheet_keeps_its_size_and_place_whichever_civilization_is_selected` |
| AC2 | `test_start_screen::test_start_sits_under_a_footer_rule_and_stays_put` |
| AC3 | `test_select_list::test_a_list_row_draws_no_box_until_selected`, `test_the_list_is_a_well`; `test_start_screen::test_the_civilizations_are_a_select_list_with_one_index_tab` |
| AC4 | `test_select_list::test_only_the_selected_row_shows_its_index_tab`, `test_a_click_or_up_and_down_choose_a_row`; `test_start_screen::test_the_civilizations_are_a_select_list_with_one_index_tab`; changed: `test_the_list_has_a_row_per_civilization_with_its_band_and_the_preselected_one_pressed` → `test_the_list_has_a_row_per_civilization_and_the_preselected_one_pressed` (no `Edge` band) |
| AC5 | `test_select_list::test_a_list_rows_focus_is_the_ring_not_the_selection`; `test_start_screen::test_moving_the_focus_off_the_selected_row_keeps_the_selection` |
| AC6 | `UIKit.select_list()` is what every `test_select_list` test builds; the guide and tokens.md are docs (no test) |

New API: `UIKit.select_list() -> SelectList` (`ui/select_list.gd`, a `PanelContainer`): `add_row(id, text) -> Button`,
`select(id)` (no signal), `selected`, `row(id)`, `ids()`, `signal chosen(id)` on a click or an arrow.
`NewGameScreen.civilization_list` becomes that `SelectList`; the footer rule is a child named `FooterRule`.

## Manual check
- [ ] Title → New game, arrow through all six in Night and Day: nothing moves but the row and its tab; the tab reads
  as orange in both palettes; focus (teal) and selection are told apart after a Tab.
- [ ] 1280×720: the fixed sheet fits on screen.

## Log
- Specced 2026-10-02. The options page `docs/design/list-options.html` holds the five candidates (A index card,
  B folder tab, C ledger line, D selector lamps, E pointer); the user chose A.
