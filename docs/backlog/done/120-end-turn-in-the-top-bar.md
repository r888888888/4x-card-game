---
id: 120
title: End turn moves to the top bar
type: feature
status: done
branch: feat/120-end-turn-in-the-top-bar
---

## Goal
End turn sits bottom-right under the Deck/Discard counts. Move it into the top bar, with the other actions, as the
last control before Menu... the primary action you press every turn, always in the same place.

## Acceptance criteria
<!-- UI tests in the real main.tscn at 1920×1080. -->
- [x] AC1: Given a game at 1920×1080, then End turn is a button in the top bar, right of Log (L) and left of Menu (Esc),
  fully on screen, with its AccentButton look, and no End turn button is beside the hand.
- [x] AC2: It keeps its behavior: E and a click end the turn; it is disabled with `end_turn_error()` as its tooltip
  while the turn can't end; while the hand is over its limit it reads "Discard N (hand limit M)" (the whole text
  shown, no truncation, the top bar still fitting at 1920 with that text); otherwise "End turn (E)".
- [x] AC3: Every top-bar control is on screen and each button fits its text with the text at its longest (a long
  civilization name, "Discard 3 (hand limit 5)").
- [x] AC4: (moved to 121) The Deck/Discard counts stay beside the hand for now, so the hand's row is the hand then the
  counts, still reaching the right edge; the hand itself reaches it once 121 moves the counts.

## Out of scope
- Moving the Deck/Discard counts (121); changing End turn's size beyond what the top bar needs.

## Design notes
- UI only: `TurnBox` loses End turn (the counts stay in it until 121); `TopBar` owns the button (`end_turn_button`).
  `test_board_layout` AC3 tests (End turn right of the hand) are replaced by the top-bar ones; `test_territory_view` and
  `test_details_modal` reference "End turn" by text and keep working. Name changed tests at the red checkpoint.
- Top bar budget: 119 frees ~100 px by merging two buttons; End turn adds ~190 px. Build 119 first.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_board_layout::test_end_turn_is_in_the_top_bar_between_log_and_menu` (replaces `test_end_turn_sits_right_of_the_hand_on_screen`) |
| AC2 | `test_board_layout::test_end_turn_is_disabled_with_the_reason_while_the_turn_cant_end`, `test_end_turn_still_ends_the_turn_and_shows_a_pending_discard` (guard) |
| AC3 | `test_board_layout::test_the_top_bar_fits_with_its_longest_texts` (guard: passes before the move, must still pass after) |
| AC4 | changed: `test_board_layout::test_no_side_panel_and_the_board_spans_the_window` measures the hand's row by the pile counts, not End turn |

## Manual check
- [ ] With 8+ cards in hand and a pending discard, "Discard N (hand limit M)" fits and nothing in the bar is cut off.

## Log
- At its longest (Phoenicia · Theocracy, "Discard 3 (hand limit 7)") the bar needed ~2010 of 1884 px. Agreed with the
  user: the top-bar buttons drop their "(S)", "(T)", "(L)", "(E)", "(Esc)" suffixes and each tooltip starts with
  "Shortcut: X." (a disabled End turn shows only its reason). New test
  `test_board_layout::test_top_bar_buttons_put_their_key_in_the_tooltip_not_the_text`; tests that named the old
  labels changed (`test_log_drawer`, `test_toasts`: "Log" / "Log •"; `test_board_labels`: "Buy Cards";
  `test_tech_tree_modal`: the Knowledge tooltip). Modal Close buttons keep "(Esc)".
- `TopBar.end_turn_button` replaces `TurnBox.end_turn`; `TurnBox` keeps only the pile counts until 121 removes it.
