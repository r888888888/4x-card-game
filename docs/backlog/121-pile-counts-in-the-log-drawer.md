---
id: 121
title: Deck and discard counts move into the log drawer
type: feature
status: done
branch: feat/121-pile-counts-in-the-log-drawer
---

## Goal
The "Deck N · Discard M" readout takes the bottom-right of the board. Show it in the log drawer instead, and let the
cards' deal and discard flights use the top-bar Log button as their pile, so the board loses the readout.

## Acceptance criteria
<!-- UI tests in the real main.tscn at 1920×1080. -->
- [x] AC1: Given a game, then no "Deck … Discard …" text is on the board outside the drawer; `TurnBox` is gone and the
  hand's row spans the full width (the hand reaches the right edge, within 40 px).
- [x] AC2: With the drawer open, its header shows "Deck N · Discard M" for the engine's current counts, updated as they
  change (end a turn: both change).
- [x] AC3: Dealt cards start from, and discarded or played-and-discarded cards fly to, the top-bar Log button (its
  centre) instead of the old readout; with Reduce motion they fade as before. The Log button pulses as a card arrives
  (`UIKit.pulse`), unless Reduce motion.
- [x] AC4: A card that goes back to the deck (not a territory returning to the territory deck, which is unchanged)
  also flies to the Log button.

## Out of scope
- Showing the counts anywhere else (a tooltip on the Log button with the counts is a possible follow-up).
- Event deck counts (122).

## Design notes
- UI only. `LogDrawer` gets a counts label (`refresh(e)`); `TopBar.pile_point()` replaces `TurnBox.pile_point()`
  (the Log button's centre); `main._leave_point` and the deal origin read it. Delete `ui/turn_box.gd` (End turn already
  left in 120) and update `test_board_layout`'s hand-row tests. Build after 120.

## Test plan
| AC | Test |
|---|---|
| AC1 | changed: `test_board_layout::test_no_side_panel_and_the_board_spans_the_window` (no TurnBox, no counts on the board, the hand reaches the right edge) |
| AC2 | `test_log_drawer::test_the_drawer_shows_the_deck_and_discard_counts` |
| AC3 | `test_log_drawer::test_dealt_cards_start_from_the_log_button_and_it_pulses_as_cards_arrive` (dealt cards' start point; the pulse after discards) |
| AC4 | shares AC3's point (`main._leave_point` for the deck); a card going back to the deck is rare: Manual check |

## Manual check
- [ ] End a turn: new cards fly out of the Log button and old ones into it, and it pulses.
- [ ] Open the log: the counts are at the top and match after another turn.

## Log
- `ui/turn_box.gd` is gone; the hand's scroll area is the hand section's row again. `LogDrawer.refresh(e)` shows
  "Deck N · Discard M" under its heading; `TopBar.pile_point()` (the Log button's centre) is where cards deal from and
  where deck/discard departures fly. `CardView.leave` takes an `on_arrival` callable (run as the card arrives, skipped
  with Reduce motion): main pulses the Log button with it, and the supply screen's Discard pulse uses it too instead of
  its own timed tween.
- Test setup fix, agreed with the user at green: `test_the_drawer_shows_the_deck_and_discard_counts` discards 2 cards
  before ending the turn (seed 1 keeps its full hand, so nothing would change). The assertions are unchanged.
