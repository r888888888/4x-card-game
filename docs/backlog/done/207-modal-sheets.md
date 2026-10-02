---
id: 207
title: Modals as the specimen's drafting sheets, laid down and lifted off
type: feature
status: done
branch: feat/207-modal-sheets
---

## Goal
Every modal looks and moves like the specimen's sheet (guide §15.11, `docs/design/mcm-specimen.html` "Turn", and
`transitions.html` "Buy cards"): a title block with a 4 px bar, title left and context caps right, the body, a footer
rule with the buttons right (primary rightmost), a hard 8 px shadow; it rises into place, and a stacked one sits
+8,+8 on the one below.

## Acceptance criteria
- [x] AC1: `Modal` builds the sheet: a panel on `RAISED` with a 2 px `TEXT` border, `RADIUS_0`, an 8,8 `SHADOW`
  shadow; a title block (4 px `TEXT` bar on top, the title in the Title variation at left, an optional context in
  caps at right); a body at most 640 px wide; an optional footer above which a 1 px `CONTROL_DISABLED_BORDER` rule
  runs, buttons right-aligned. Subclasses set `title`, `context` and footer buttons through `Modal`'s API instead of
  building their own headers.
- [x] AC2: Every modal uses it: card details, the civilization modal, the event modal, the Settings modal (206), and
  the game menu and the game-over sheet, which become `Modal`s on `main.modals` (today they build their own scrims), each with its title (and context where it has one: the event modal "Turn N",
  card details the card type) and its Close or primary button in the footer.
- [x] AC3: Opening a modal (Reduce motion off): its panel starts 24 px below its place at opacity 0 and reaches its
  place in 0.24 s (`Anim.MACHINED`), opacity 1 by 0.12 s; its scrim fades in over 0.16 s. With Reduce motion: a 0.12 s
  fade, no movement.
- [x] AC4: A modal opened over another sits +8,+8 from the one below (replacing `Modal.cascade`'s offset if it differs),
  and opens with AC3's motion without a second scrim fade.
- [x] AC5: Closing: the panel moves to +12 px below and to opacity 0 in 0.16 s (`Anim.RELEASE`) with its scrim; it
  takes no clicks or keys while closing, and the modal below takes them at once. Closing several at once (ModalStack
  closing above a lower one) runs them together.
- [x] AC6: The existing sounds (189: sheet open/close, stacked quieter, under a bell quieter) play as today.

## Out of scope
- The tech tree (it becomes a screen in 208). Choice overlays (explore, renewal, government; 209 does government).

## Design notes
- `GameMenu` and `GameOverOverlay` are `RefCounted` builders with their own scrim and keys today; moving them onto
  `Modal` is part of AC2 (their tests' hooks may move; behaviours stay).
- Timings are the guide's tokens (`Anim`, `Tokens`); tests read the tween's targets at its end and the positions at
  t = 0, as 104's navigator tests do.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_modal_sheets::check_sheet` in each AC2 test: sheet style, bar, title, context, body ≤ 640, footer and rule |
| AC2 | `test_card_details_is_a_sheet_titled_with_the_card_and_its_type`, `test_the_civilization_modal_is_a_sheet`, `test_the_event_modal_is_a_sheet_with_the_turn_as_context`, `test_the_menu_is_a_sheet_on_the_modal_stack`, `test_game_over_is_a_sheet_on_the_modal_stack_that_stays` (its primary, Replay, rightmost) |
| AC3 | `test_a_sheet_rises_into_place_and_its_scrim_fades_in`, `test_with_reduce_motion_a_sheet_only_fades_in` |
| AC4 | `test_a_sheet_over_another_sits_8_8_from_it_and_rises_without_a_second_scrim_fade`; changed: `test_modal_stack::test_a_modal_over_another_is_one_cascade_step_from_centre` (cascade 36,28 → 8,8; measured after the rise), `test_a_modal_alone_is_centred` (measured after the rise) |
| AC5 | `test_a_closing_sheet_drops_and_fades_while_the_one_below_takes_input`, `test_a_closed_sheet_ends_12_px_below_clear_and_comes_back_in_place`, `test_closing_several_sheets_at_once_lifts_them_together`, `test_with_reduce_motion_a_closing_sheet_only_fades` |
| AC6 | Existing `test_sheet_sounds` (unchanged) |
| — | Changed: `test_button_widths::test_menu_and_game_over_columns_share_one_width` → `test_the_menu_column_shares_one_width_and_footer_buttons_fit_their_text` (Close, Exit and the game-over buttons move to footers) |

Decisions made writing the tests:
- Titles: card details = the card's name, context its type; the civilization modal = "Civilization"; the event = the
  event's name, context "Turn N"; "Menu"; "Game over".
- Footers: details "Close (Esc)" (its "Play as" action goes in 212); civilization "Close (Esc)"; event "OK (Enter)"; menu
  "Close (Esc)", "Exit" (so Exit stays last, as 067 has it); game over "New game", "Replay this seed" (primary).
- The game-over sheet can't be dismissed (Esc, a click outside): only its buttons or a new game end it.
- The 640 px limit is the `body` column; a modal's card (details, event) sits beside it.
- A stacked sheet shows its scrim at once ("without a second scrim fade").

## Manual check
- [ ] Seed 5: open Menu, card details (I on a hand card), the civilization modal, an event and game over: each a
  paper sheet with an ink bar, title (context right), body and a footer under a rule, buttons right.
- [ ] Civilization modal → a card's details (or Revolt…, 205): the second sheet lands +8,+8 like paper on paper; compare with the specimen in both
  palettes and at ¼ speed in `transitions.html`.

## Log
- Specced 2026-10-02 from the notes list. Decided 2026-10-02: the sheet's rise and stack transition are part of this
  item.
- 2026-10-02: Built. `Modal` builds the sheet (`GameTheme`'s `Sheet` variation, `GameTheme.SHEET_SHADOW`), the title block
  (`title`, `context`), `aside`, `body`, and `add_footer_button(button, primary)`; `enter(stacked)` / `leave()` run the
  motion and `ModalStack` calls them (`ModalStack.has`, `Modal.is_open()`: a closing sheet is still drawn but not open).
  `GameMenu` and `GameOverOverlay` are Modals; the game-over sheet isn't dismissable and closes any sheet still open
  when it comes (the last turn's event). The top modal now lets keys through to its own focused control (the menu's
  Tab loop, Enter on Exit), and main's card keys wait while any modal is open.
- Existing tests changed by AC1/AC2: `test_theme::test_overlay_panels_use_dark_panel` → `…_and_modals_the_sheet` (modals
  use `Sheet` with an ink rule, the event modal included); `test_key_sounds`' two menu key tests count sounds after the
  menu's sheet-open; `test_start_screen::test_menu_new_game_opens_the_new_game_screen` checks the stack (the menu is
  still lifting off); `test_button_widths::test_tech_tiles_fill_their_era_column` skips the footer.
