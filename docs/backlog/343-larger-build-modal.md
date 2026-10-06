---
id: 343
title: Make the Build modal larger: a wider, taller list and a hand-size card
type: feature
status: red-review
branch: feat/343-larger-build-modal
---

## Goal
The Build modal (297) is cramped: a 288 × 350 list beside the selected entry's card at tableau size (245 × 175), whose
small text is hard to read. Grow it so more rows show before scrolling and the card reads like a hand card.

## Acceptance criteria
- [ ] AC1: Given the Build modal open on a territory, then the selected entry's card is shown at `CardView.HAND_SIZE`
  (264 × 320): its view's size and its slot's minimum size; selecting another row keeps that size.
- [ ] AC2: Given the Build modal open, then the list's column (its scroll area) is 336 px wide
  (`Tokens.SPACE_9 * 3 + Tokens.SPACE_7`) and 480 px tall (`Tokens.SPACE_9 * 5`) at minimum.
- [ ] AC3: Given a refused row selected, then its reason wraps at the card's width (264, `CardView.HAND_SIZE.x`).
- [ ] AC4: Given the 1920 × 1080 window, then the open modal's panel lies wholly inside the viewport and its body is at
  most `Modal.BODY_MAX_WIDTH` (640) wide: 336 + 32 + 264 = 632.
- [ ] AC5: Given a row whose text is wider than the column (a refused row's reason), then it wraps within the column:
  laid out, the list's scroll area stays 336 px wide (today such a row stretches it to 365 and the body to 645).
- [ ] AC6: Given the shown card, then it stays display-only: the mouse passes through it (no hover, drag or details).

## Out of scope
- Other modals' sizes; the Build modal's contents, order and keys.
- Scaling the modal with the window.

## Design notes
- `BuildModal.LIST_WIDTH` becomes `Tokens.SPACE_9 * 3 + Tokens.SPACE_7` (336: the widest that keeps the body inside the
  guide's 640 px cap beside a hand-size card; the user chose fitting the cap over 384); a new `LIST_HEIGHT := Tokens.SPACE_9 * 5` replaces
  `CardView.TABLEAU_SIZE.y * 2`. The card is set up as a hand-size face (`setup(..., true)` like the Modal aside and the
  details modal) with `MOUSE_FILTER_IGNORE`; `_card_slot` and the refusal's wrap width use `CardView.HAND_SIZE`.
- The list rows wrap their text (`autowrap_mode` on the Build modal's row buttons) so the column holds 336 and the
  body the cap.
- UI only; tests in `tests/test_build_modal.gd`.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_build_modal::test_the_card_on_the_sheet_is_hand_size_for_every_row` |
| AC2 | `test_build_modal::test_the_list_column_is_336_by_480` |
| AC3 | `test_build_modal::test_a_refusal_wraps_at_the_cards_width` |
| AC4 | `test_build_modal::test_the_larger_modal_fits_the_window_and_the_body_cap` |
| AC5 | `test_build_modal::test_a_long_row_wraps_inside_the_336_column` |
| AC6 | `test_build_modal::test_the_card_on_the_sheet_ignores_the_mouse` |

## Manual check
- [ ] Open a territory, press B: the list shows more rows before scrolling, the card is hand-size and readable, and the
  modal sits well inside the window.

## Log
