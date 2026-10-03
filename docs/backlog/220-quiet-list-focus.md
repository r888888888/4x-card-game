---
id: 220
title: A list row's focus ring waits for the keyboard
type: feature
status: in-progress
branch: feat/220-quiet-list-focus
---

## Goal
Opening the New game screen gives the selected civilization's row the keyboard focus (212), and the teal focus ring
draws around it before the player has touched a key. The selected row already stands out (the pulled strip and its
index tab), so the ring is noise there. A SelectList row draws no ring when the focus came from the code or a click,
and draws it once the keyboard moves the focus (Up/Down in the list, Tab or Shift+Tab onto a row).

## Acceptance criteria
- [ ] AC1: Given a SelectList with rows a, b, c, when row a is focused with `grab_focus()` (as a screen does when it
  opens), then a's `focus` stylebox draws nothing (a `StyleBoxEmpty`).
- [ ] AC2: Given row a focused as in AC1, when Down is pressed, then row b has the focus and its `focus` stylebox is the
  focus ring (a `StyleBoxFlat` with no fill and a `Palette.FOCUS` border).
- [ ] AC3: Given row a focused as in AC1, when Tab moves the focus to row b, then b's `focus` stylebox is the ring; and
  when Shift+Tab moves it back to a, then a's is the ring.
- [ ] AC4: Given row b showing the ring (AC2), when the focus leaves it and b is then focused again with `grab_focus()`
  (or a click), then b draws no ring.
- [ ] AC5: Given the New game screen opening with civilizations, then the selected row has the focus and draws no ring;
  when Down is pressed, the next row has the focus and draws the ring.

## Out of scope
- Other buttons and fields (title screen, menu, settings): their focus ring is unchanged.
- The board's card focus.

## Design notes
- GameTheme gains `ListRowQuiet`, a variation of `ListRow` whose `focus` stylebox is a `StyleBoxEmpty`. SelectList
  builds rows as `ListRowQuiet`; a row becomes `ListRow` when a key press reaches it or it takes the focus while
  `ui_focus_next`/`ui_focus_prev` is pressed, and goes back to `ListRowQuiet` when it loses the focus.
- Changes approved tests: `test_select_list::test_the_list_is_a_well` and
  `test_start_screen::test_the_civilizations_are_a_select_list_with_one_index_tab` assert rows are `ListRow`; they
  accept `ListRow` or `ListRowQuiet`. `test_select_list::test_a_list_rows_focus_is_the_ring_not_the_selection` reads
  the ring from an unfocused row; it reads it after Tab instead (the ring itself is unchanged).

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_select_list::test_a_row_focused_by_the_code_draws_no_ring` |
| AC2 | `test_select_list::test_the_arrows_show_the_ring` |
| AC3 | `test_select_list::test_tab_and_shift_tab_show_the_ring`, `test_select_list::test_a_list_rows_focus_is_the_ring_not_the_selection` (changed) |
| AC4 | `test_select_list::test_the_ring_goes_when_the_focus_leaves` |
| AC5 | `test_start_screen::test_the_new_game_screen_opens_with_no_ring_until_a_key` |

## Manual check
- [ ] New game: the selected civilization has no ring on opening; Down or Tab shows it; a click on a row shows none.

## Log
