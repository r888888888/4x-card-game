---
id: 343
title: Make the Build modal larger: the guide's ledger sheet (a 384 × 480 list and a hand-size card)
type: feature
status: in-progress
branch: feat/343-larger-build-modal
---

## Goal
The Build modal (297) is cramped: a 288 × 350 list beside the selected entry's card at tableau size (245 × 175), whose
small text is hard to read. Grow it so more rows show before scrolling and the card reads like a hand card.

## Acceptance criteria
- [ ] AC1: Given the Build modal open on a territory, then the selected entry's card is shown at `CardView.HAND_SIZE`
  (264 × 320): its view's size and its slot's minimum size; selecting another row keeps that size.
- [ ] AC2: Given the Build modal open, then the list's column (its scroll area) has a minimum size of
  `Modal.LEDGER_LIST_WIDTH` × `Modal.LEDGER_LIST_HEIGHT` (384 × 480).
- [ ] AC3: Given a refused row selected, then its reason wraps at the card's width (`Modal.LEDGER_DETAIL_WIDTH`, 264).
- [ ] AC4: Given the 1920 × 1080 window, then the open modal's panel lies wholly inside the viewport, its body is
  `Modal.LEDGER_WIDTH` (680) wide, the list column 384, and the card sits `Modal.LEDGER_GAP` (32) right of it.
- [ ] AC5: Given a row wider than the column (a building named "The Great Hall of the Assembled Elders of the Realm"),
  then it wraps: laid out, the list column stays 384 wide (today such a row stretches it).
- [ ] AC6: Given the shown card, then it stays display-only: the mouse passes through it (no hover, drag or details).

## Out of scope
- Other modals' sizes; the Build modal's contents, order and keys.
- Scaling the modal with the window.

## Design notes
- The Build modal is the guide's **ledger sheet** (344, §11.10): `LIST_WIDTH` / the list height / the gap / the card
  width come from `Modal.LEDGER_*`. The card is set up as a hand-size face (`setup(..., true)` like `Modal.show_card`)
  with `MOUSE_FILTER_IGNORE`; the refusal wraps at `LEDGER_DETAIL_WIDTH`; the list rows wrap their text
  (`autowrap_mode` on the row buttons) so the column holds its width.
- UI only; tests in `tests/test_build_modal.gd` (a `LONG_HALL` fixture card for AC5).

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_build_modal::test_the_card_on_the_sheet_is_hand_size_for_every_row` |
| AC2 | `test_build_modal::test_the_list_column_is_the_ledgers` |
| AC3 | `test_build_modal::test_a_refusal_wraps_at_the_cards_width` |
| AC4 | `test_build_modal::test_the_modal_is_a_680_px_ledger_inside_the_window` |
| AC5 | `test_build_modal::test_a_long_row_wraps_inside_the_list_column` |
| AC6 | `test_build_modal::test_the_card_on_the_sheet_ignores_the_mouse` |

## Manual check
- [ ] Open a territory, press B: the list shows more rows before scrolling, the card is hand-size and readable, and the
  modal sits well inside the window.

## Log
- Blocked on 344 (modal layouts in the guide): the Build modal becomes the guide's ledger sheet. When 344 is done,
  rebase on main and rewrite these red tests (never approved) against `Modal.LEDGER_*`: list 384 × 480, card at hand
  size, no 640 cap (the sheet is 680); add the `test_modal_sheets` check that a ledger sheet follows its rule. Found
  while writing them: a refused row's reason doesn't wrap, which stretches today's list to 365 and the body to 645.
- 344 merged into this branch; the red tests were rewritten against `Modal.LEDGER_*` and approved by the user in advance.
