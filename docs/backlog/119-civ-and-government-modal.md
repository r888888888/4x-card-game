---
id: 119
title: One top-bar button opens a Civilization and Government modal
type: feature
status: done
branch: feat/119-civ-and-government-modal
---

## Goal
The top bar spends two buttons on the civilization and the government, each opening its own details. Replace them
with one button that opens a single modal showing both, freeing top-bar width.

## Acceptance criteria
<!-- UI tests in the real main.tscn on the real data (Egypt, Chiefdom at the start). Hook: main.identity_modal. -->
- [x] AC1: Given a game with a civilization and a government, then the top bar has one button, "<civ name> ·
  <government name>" (e.g. "Egypt · Chiefdom"), where the two buttons were (after the stats, before Buy Cards), and no
  separate civilization or government button. Its tooltip is "Your civilization and government."
- [x] AC2: Pressing it opens a modal with two sections, civilization then government. The civilization section shows
  what its details show today (name, flavor, quote with who said it, then rules; tooltip rules text is not repeated);
  the government section shows its name and rules ("No bonus." when it has none). Esc or Close closes it; it opens
  above the log drawer like the other modals, and the board's keys are blocked while it is open.
- [x] AC3: Given a game with only one of them (or neither), then the button names the one there is ("Egypt"), and with
  neither it is hidden; the modal shows only the section that exists.
- [x] AC4: Given a government is played (Kingship), then the button reads "Egypt · Kingship", the card flies to the
  button, and an open modal shows Kingship's rules.
- [x] AC5: A civilization or government with no flavor or quote shows no empty lines (guard).

## Out of scope
- Opening a card's full details from the modal; a government choice or swap UI.
- Showing other zones (techs, wonders).

## Design notes
- UI only (`ui/top_bar.gd`, a new `IdentityModal` like `TechTreeModal`/`CardDetailsModal`; `main.identity_modal`).
  `main.identity_buttons()` / `identity_lines()` hooks go: `test_identity_lines` is rewritten around the one button and
  modal (its civilization-details tests keep their flavor/quote/rules-order assertions, now on the modal's body).
- `TopBar.identity_point("government")` becomes the one button's point. Name the changed tests at the red checkpoint.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_identity_lines::test_one_top_bar_button_names_the_civilization_and_government`; changed: `test_board_layout::test_the_top_bar_holds_identity_supply_and_knowledge_before_menu` |
| AC2 | `test_identity_lines::test_pressing_it_opens_one_modal_with_the_civilization_then_the_government`, `test_esc_and_close_close_it_and_it_blocks_the_board_keys`, `test_it_opens_above_the_log_drawer` |
| AC3 | `test_identity_lines::test_with_only_a_civilization_the_button_and_modal_show_it_alone`, `test_with_only_a_government_the_button_and_modal_show_it_alone`, `test_with_neither_the_button_is_hidden` |
| AC4 | `test_identity_lines::test_playing_a_government_updates_the_button_and_an_open_modal` (the flight to the button: Manual check) |
| AC5 | `test_identity_lines::test_a_civilization_without_flavor_or_quote_shows_no_empty_lines` |
| changed | `test_start_screen::test_details_in_play_have_no_play_as_button` opens a hand card's details instead of the civilization's |

## Manual check
- [ ] Open the modal at the start (Egypt, Chiefdom) and after playing a government; try Esc, Close, and the log drawer open.
- [ ] A long civilization name plus government still fits the top bar at 1920×1080.

## Log
- `IdentityModal` (`ui/identity_modal.gd`, `main.identity_modal`) builds each section with the details modal's body
  (`CardDetailsModal.body_bbcode`, made public from `_body_text`), under the card's name and type; "No bonus." when a
  card has no text. It refreshes while open. `TopBar` has one `_identity` button (`identity_button()`,
  `identity_point()`); `main.identity_buttons()` / `identity_lines()` are gone.
- The top bar is ~100 px narrower than after 115 (two buttons became one), which 120 (End turn) needs.
