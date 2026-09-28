---
id: 017
title: Play the whole game from the keyboard
type: feature
status: in-progress
branch: feat/017-keyboard-play
---

## Goal
Everything a mouse can do can also be done from the keyboard, with a visible focus ring:
play cards, pick targets, choose an explored territory, grow, end the turn, and restart. Today only
Enter (end turn) works, and all buttons are set to `FOCUS_NONE`.

## Acceptance criteria
<!-- UI-only item. Checked in the running game. Engine calls are the same ones the mouse uses. -->
- [ ] AC1: Given a hand of 5 and nothing focused, when I press Right (or Left), then the first (or
  last) hand card gets focus. Left and Right then move focus along the hand without wrapping. The
  focused card lifts like a hovered card and shows a 3px or thicker focus ring that is distinct from
  the gold target highlight.
- [ ] AC2: Given a focused playable card that needs no target, or has exactly 1 valid target, when I
  press Enter or Space, then it is played (same result and animation as a double-click). Focus moves
  to the card that is now in its place, or to the new last card.
- [ ] AC3: Given a focused card with 2 or more valid targets, when I press Enter, then targeting mode
  starts with the first target focused. Left and Right cycle through the lit targets only. Enter plays
  on the focused target. Esc cancels and returns focus to the hand card.
- [ ] AC4: Given a focused unplayable card, when I press Enter, then nothing is played, the card shakes,
  and the `play_error` reason is shown (same as a refused drop).
- [ ] AC5: Given an explore choice is pending, then focus moves to the first choice card, Left and
  Right move between the choice cards, and Enter keeps the focused one. Hand keys do nothing while
  the choice is open.
- [ ] AC6: Given any time no choice is pending, when I press E, then the turn ends. Tab and Shift+Tab
  move through the buttons (seed field, Restart, New game, each Grow, End turn), each with a visible
  focus ring. Enter or Space on a focused button presses it. Enter no longer ends the turn unless End
  turn is focused. The End turn label reads "End turn (E)".

## Out of scope
- Screen reader support (Godot 4.7 AccessKit): worth a separate item.
- Rebinding keys.
- Gamepad.

## Design notes
- No engine change: the keys call `play_card`, `choose`, `grow` and `end_turn`, like the mouse.
  Target order is the order of `valid_targets`.
- The hand focus index lives in `main.gd`. `CardView` gets `set_focused(on)`, which shares the hover
  lift. The focus ring colour is separate from `HIGHLIGHT_COLOR` (gold = valid target) and
  `WARN_COLOR`.
- Buttons stop using `FOCUS_NONE`. `_unhandled_key_input` handles Left/Right/Enter/Space/Esc/E only
  when the seed LineEdit doesn't have focus.
- Changing End turn from Enter to E is a deliberate change of the existing shortcut. Update PLAN.md
  and the hand heading text.

## Test plan
| AC | Test |
|---|---|
| all | Manual (UI only). Can also be exercised by a scratch driver that sends synthetic key events (not committed). |

## Manual check
Run `godot --path .` and don't touch the mouse.
- [ ] **AC1–AC2:** press Right, move to Forage, and press Enter: Forage is played, and focus stays in the hand.
- [ ] **AC3:** with 2 settled territories, focus a Farm and press Enter. Arrows step through the lit
  territories, and Enter places the Farm there. Try again and press Esc: nothing is played.
- [ ] **AC4:** Enter on a card you can't afford: it shakes and shows the reason.
- [ ] **AC5:** play Scout from the keyboard, pick a territory with the arrows, and press Enter.
- [ ] **AC6:** press E to end the turn. Tab through the buttons and press Grow and Restart from the keyboard.

## Log
