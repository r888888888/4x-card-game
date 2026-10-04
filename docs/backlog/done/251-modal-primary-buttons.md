---
id: 251
title: Modal footers show their primary action in the signal colour
type: feature
status: done
branch: feat/251-modal-primary-buttons
---

## Goal
A modal's footer reads like the MCM specimen's (`docs/design/mcm-specimen.html`, the "Choose a government" sheet;
guide §7.1, §7.14): the action the modal exists for is a primary key in the signal colour, at the right end, and the
way out (Cancel, Keep, Close, New game) is a plain steel key left of it. Today `add_footer_button(…, true)` only
orders the primary; it looks the same as the others.

## Acceptance criteria
- [x] AC1: Given the theme, then the `AccentButton` variation (the guide's primary button) has an `ACCENT` fill,
  `TEXT_ON_ACCENT` label in the semibold label face, a **3 px** `TEXT` (ink) border, `RADIUS_1` corners and the 2,2
  plinth (today its border is 2 px; specimen `.btn.primary` and §7.1 say 3); its disabled look is the plain
  `Button`'s disabled look.
- [x] AC2: Given any modal, when a button is added with `add_footer_button(button, true)`, then its
  `theme_type_variation` is `AccentButton`; a button added without `primary` keeps the default `Button` look.
- [x] AC3: Given each action modal open and settled, then its footer reads left to right as below, the last one the
  only `AccentButton` among its visible footer buttons:
  - Rename territory: Cancel · **Rename**
  - Revolution: Keep <government> · **Revolt**
  - Card details of a playable hand card: Close (Esc) · **Play**; of a tech on the Knowledge screen: Close (Esc) ·
    **Learn**
  - Drawn event: **OK (Enter)** (its only button)
  - Game over: New game · **Replay this seed**
- [x] AC4: Given a modal with no action to take — Settings, the civilization and government modal, the menu (Close
  (Esc) · Exit), card details of a card that is neither playable from hand nor a learnable tech — then no visible
  footer button is an `AccentButton` (at most one primary per view, none when there is nothing to do).
- [x] AC5: Given Rename or Play is disabled by its engine error, then the primary key shows the disabled look (no
  `ACCENT` fill) and keeps its error tooltip.
- [x] AC6: Given the theme, then a `LineEdit` (the Rename field, the seed fields) draws no focus ring: its `focus`
  stylebox draws nothing, in pointer and keyboard mode alike; its caret and selection show where typing goes. (Added
  2026-10-04: Godot draws a field's focus box even when FocusRing hides the focus, so Rename's field always showed the
  teal ring.)

## Out of scope
- Renaming dismiss buttons to "Cancel" (each keeps its current label: user's call, 2026-10-04).
- The menu's body column (Restart, New game, Settings) and buttons outside modals (the start screen's big keys, End
  turn).
- The specimen's disabled look (dashed `rule` border on `well`): a separate restyle if wanted.
- Button sound pitch for a primary (§7.1 "a key one size heavier"): note for a later sound item.

## Design notes
- `Modal.add_footer_button` sets `theme_type_variation = &"AccentButton"` when `primary`; no subclass styles its own.
- `GameTheme._controls`: `AccentButton`'s border goes from 2 to 3 px. Its content margins are set explicitly (16, 8),
  so it stays the same size as a plain button beside it; `test_theme.gd`'s AccentButton box check moves to 3 px with
  this item.
- Decisions (user, 2026-10-04): close-only modals keep one plain Close; primaries are the buttons already marked
  primary today; the menu's Exit stays plain.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_theme::test_the_accent_button_is_signal_orange` (3 px; disabled = Button's disabled) |
| AC2 | `test_modal_sheets::test_a_primary_footer_button_wears_the_accent_look_and_the_others_stay_plain` |
| AC3 | `test_rename_modal::test_rename_is_the_primary_and_disabled_it_loses_the_accent`, `test_revolt_modal::test_revolt_opens_a_confirmation_with_the_flavor_and_the_summary`, `test_modal_sheets::test_card_details_is_a_sheet_titled_with_the_card_and_its_type`, `test_knowledge_screen::test_research_in_a_techs_details_learns_it_and_closes_the_details`, `test_modal_sheets::test_the_event_modal_is_a_sheet_with_the_turn_as_context`, `test_modal_sheets::test_game_over_is_a_sheet_on_the_modal_stack_that_stays` |
| AC4 | `test_modal_sheets::test_settings_and_board_card_details_have_no_primary`, `…::test_the_civilization_modal_is_a_sheet`, `…::test_the_menu_is_a_sheet_on_the_modal_stack` (pass already: they pin that close-only modals stay plain) |
| AC6 | `test_theme::test_a_field_draws_no_focus_ring` |
| AC5 | `test_rename_modal::test_rename_is_the_primary_and_disabled_it_loses_the_accent`, `test_details_modal::test_play_button_is_disabled_with_the_reason_for_an_unplayable_hand_card` |

## Manual check
- [ ] `godot --path . -- --civ egypt --seed 5`: open the home territory, Rename…: Cancel plain, Rename orange with a
  thick ink border, same height; clear the field: Rename turns the plain disabled grey. Repeat in Day mode (Settings).
- [ ] Sidebar civilization card → Revolt…: Keep <government> plain, Revolt orange.
- [ ] I on a playable hand card: Close (Esc) plain, Play orange; hover and press it: the border stays thick.
- [ ] End turns until an event: OK (Enter) orange. Knowledge (T) → a tech: Learn orange.
- [ ] Rename…'s field shows its caret and selected name but no teal ring, clicked open or tabbed into; so do the seed
  fields in Settings and New game.
- [ ] Settings, the civilization modal and the menu show no accent key in the footer.

## Log
- Every enabled state of `AccentButton` (normal, hover, pressed, latched) has the 3 px border, so it doesn't thin on
  hover; disabled stays the plain 2 px disabled look.
- Follow-up (not in this item): §7.1's heavier key sound for a primary (`ui.button.press` pitched −2), and the
  specimen's dashed disabled look.
- AC6 added after review: fields draw no focus ring at all (keyboard mode too); the caret shows the focus.
