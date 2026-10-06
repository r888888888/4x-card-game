---
id: 344
title: Name the modal layouts in the guide (text, card and ledger sheets) with the ledger's sizes in Modal
type: feature
status: red-review
branch: feat/344-modal-layouts
---

## Goal
The guide knows one modal: a text sheet whose body is at most 640 px (§11.10, §15.11; the cap is a reading measure,
§7). The code already has a second (a card in `Modal.aside`, left of the body: card details) and the Build modal is a
third, a list beside the selected entry's card, which the 640 cap squeezes (343). Name all three in the guide and give
the ledger sheet its own sizes, as `Modal` constants, so the Build modal (343) and later choosers build to a rule
instead of to arithmetic.

## Acceptance criteria
- [ ] AC1: Given `Modal`, then `LEDGER_LIST_WIDTH` is 384 (`Tokens.SPACE_9 * 4`), `LEDGER_GAP` is 32
  (`Tokens.SPACE_6`), `LEDGER_DETAIL_WIDTH` is `CardView.HAND_SIZE.x` (264), `LEDGER_ROWS` is 12 and
  `LEDGER_WIDTH` is their sum, 680; `BODY_MAX_WIDTH` stays 640.
- [ ] AC2: Given a `SelectList` (`UIKit.select_list()`) under the game theme with one one-line row, then that row's
  minimum height × `LEDGER_ROWS` equals `Modal.LEDGER_LIST_HEIGHT` (480): the list's height is 12 one-line rows, and the
  suite notices if the row height changes.
- [ ] AC3: Given a ledger of `LEDGER_WIDTH` (680) on the 1920 × 1080 viewport, then it fits beside the sheet's padding
  inside the viewport (680 + the sheet's horizontal padding ≤ 1920) — a guard that the sizes stay sane.
- [ ] AC4: Given the card details modal on a hand card (the card sheet), then its card sits in `aside` at
  `CardView.HAND_SIZE`, left of the body, and the body is at most `BODY_MAX_WIDTH`: the aside is outside the cap
  (documents today's behaviour; a guard).

## Out of scope
- Changing the Build modal: item 343 moves it onto the ledger sizes (its red tests are rewritten against these
  constants, and it adds the `test_modal_sheets` check that a ledger sheet follows its rule).
- Screens: the new-game screen's list keeps its own width (288).
- A shared ledger-building helper in `Modal`: wait for a second ledger sheet.

## Design notes
- Guide (`docs/design/mcm-style-guide.md`): §11.10 gains **Modal layouts**:
  1. **Text sheet**: the body ≤ 640 px (the measure, §7). Abandon, Revolt, Rename, the menu, events.
  2. **Card sheet**: the card in the aside (hand size, left), then the body ≤ 640 px; the aside is outside the cap.
     Card details, the renewal and Modal.show_card users.
  3. **Ledger sheet**: a list column (384 px; rows wrap inside it; 12 one-line rows, 480 px, before it scrolls) and,
     `space.6` (32) right of it, a detail column the width of a hand-size card (264): the selected entry's card with its
     lines under it, wrapping at the card's width. Width 680, no 640 cap: the measure holds inside each column, since no
     line is wider than its column. The Build modal (343).
  §15.11's anatomy line names the three, and the §13 / §7 "640 px" mentions point at text sheets.
- `docs/design/tokens.md`: a row for the ledger sizes (`Modal.LEDGER_*`). The specimen's Build-modal note, if it gives
  sizes, follows.
- Constants in `ui/modal.gd` beside `BODY_MAX_WIDTH`: `LEDGER_LIST_WIDTH`, `LEDGER_GAP`, `LEDGER_DETAIL_WIDTH`,
  `LEDGER_ROWS`, `LEDGER_LIST_HEIGHT` (480), `LEDGER_WIDTH`. Component sizes, like `BODY_MAX_WIDTH`, so they live on
  `Modal`, not in `Tokens`.
- UI only; tests in `tests/test_modal_sheets.gd`.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_modal_sheets::test_the_ledger_sizes_are_modal_constants` |
| AC2 | `test_modal_sheets::test_the_ledger_list_is_twelve_one_line_rows_tall` |
| AC3 | `test_modal_sheets::test_a_ledger_and_the_sheets_padding_fit_the_viewport` |
| AC4 | `test_modal_sheets::test_a_card_sheet_keeps_its_hand_size_card_left_of_a_capped_body` (guard: passes today) |

## Manual check
- [ ] Read the guide's §11.10 Modal layouts and §15.11: the three layouts, their sizes and examples read clearly and
  agree with `Modal`'s constants.

## Log
