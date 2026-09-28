---
id: 017
title: Play the whole game from the keyboard
type: feature
status: review
branch: feat/017-keyboard-play
---

## Goal
Everything a mouse can do can also be done from the keyboard, with a visible focus ring:
play cards, pick targets, choose an explored territory, grow, end the turn, and restart. Today only
Enter (end turn) works, and all buttons are set to `FOCUS_NONE`.

## Acceptance criteria
<!-- UI-only item. Checked in the running game. Engine calls are the same ones the mouse uses. -->
- [x] AC1: Given a hand of 5 and nothing focused, when I press Right (or Left), then the first (or
  last) hand card gets focus. Left and Right then move focus along the hand without wrapping. The
  focused card lifts like a hovered card and shows a 3px or thicker focus ring that is distinct from
  the gold target highlight.
- [x] AC2: Given a focused playable card that needs no target, or has exactly 1 valid target, when I
  press Enter or Space, then it is played (same result and animation as a double-click). Focus moves
  to the card that is now in its place, or to the new last card.
- [x] AC3: Given a focused card with 2 or more valid targets, when I press Enter, then targeting mode
  starts with the first target focused. Left and Right cycle through the lit targets only. Enter plays
  on the focused target. Esc cancels and returns focus to the hand card.
- [x] AC4: Given a focused unplayable card, when I press Enter, then nothing is played, the card shakes,
  and the `play_error` reason is shown (same as a refused drop).
- [x] AC5: Given an explore choice is pending, then focus moves to the first choice card, Left and
  Right move between the choice cards, and Enter keeps the focused one. Hand keys do nothing while
  the choice is open.
- [x] AC6: Given any time no choice is pending, when I press E, then the turn ends. Tab and Shift+Tab
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
| all | Manual (UI only). Also run by a scratch driver (not committed) that sends only synthetic key events through the real UI and checks engine state: 31 checks covering AC1–AC6 and game over, all passing. |

## Manual check
Run `godot --path .`, type seed `4242`, press Restart, then move the mouse off the cards and leave it.
- [ ] **AC1:** press → : Forage lifts and gets a blue ring. →/← move along the hand and stop at the ends.
- [ ] **AC2:** on Forage, press Enter: it is played (+2 food), and the ring moves to the card now in its
  place. Move to Pasture and press Space: it goes onto Grassland, the only territory.
- [ ] **AC4:** on Granary (3 food, which you can't afford), press Enter: it shakes, and the reason pops up.
- [ ] **AC6:** press Enter with no card focused (Esc drops the focus): nothing happens. Press E: the turn ends.
  Tab through Reduce motion, the seed field, Restart, New game, Grow and End turn. Each gets a blue ring,
  and Enter on End turn ends the turn. A button you click with the mouse doesn't keep the ring.
- [ ] **AC5:** play Scout with the keyboard. The first choice card gets the ring, → moves it, and Enter
  keeps that territory.
- [ ] **AC3:** once there are 2 frontier territories, play Settler with Enter. The first territory gets
  a blue ring inside its gold border, and ←/→ cycle through the territories. Esc puts the ring back on
  Settler. Enter again, pick one, and press Enter: that territory is settled.
- [ ] Play to turn 20 with E. The game-over panel opens with "Replay this seed" focused, so Enter replays.

## Log
- Card focus is our own (cards aren't Godot controls). `main.gd` keeps `_focused` and `_hand_index`, and
  `_sync_card_focus` puts the focus back after every refresh: on the first choice card while
  exploring, otherwise on the same hand card, or the one now in its place.
- Keys go through `_unhandled_key_input`, so a focused button or the seed field sees them first.
  Arrows on a focused button move between buttons (Godot's own navigation). Giving a card focus
  releases button focus, and a button getting focus clears the card ring.
- A button clicked with the mouse releases its focus afterwards. Otherwise a later Enter would press
  it again (e.g. Restart).
- Focus ring colour `5ec8ff` (about 9:1 against the page), distinct from gold (target) and red (warning).
  It is drawn outside hand cards, and inside other cards, since the frontier and tableau scroll boxes
  clip anything drawn outside.
- Game over focuses "Replay this seed" (not in the ACs, but otherwise the keyboard dead-ends there).
- Esc with nothing to cancel drops the card focus (not in the ACs).
- Found while testing: when the mouse rests on a card, its hover tooltip is open, and Godot closes it on
  the first Esc, which uses up the key. A second Esc then works. Normal behaviour for Godot tooltips; left as is.
- UI only; test count unchanged (159).
