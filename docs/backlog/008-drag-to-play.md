---
id: 008
title: Drag cards from hand to play them, with animations
type: feature
status: in-progress
branch: feat/008-drag-to-play
---

## Goal
Playing a card feels physical: you pick it up, carry it into the play area and drop it, and it
animates into place. The player sees what each play did because costs, gains and drawn cards
move across the screen. This replaces click-to-play; double-click is kept as a way to play
without dragging.

Depends on 007 (`card_played` outcome).

## Acceptance criteria
<!-- UI-only item. Each criterion is checked in the running game (see Manual check). If any
     rule or derived value is needed, it goes into the engine under TDD first. -->
- [ ] AC1: Given a playable card in hand, when I drag it and release it anywhere above the hand
  area, then it is played (same result as `play_card`). Buildings and cities animate into their
  tableau slot; actions animate to the discard pile.
- [ ] AC2: Given a card being dragged, when I release it over the hand area, or press Esc or
  right-click during the drag, then nothing is played and the card animates back to its slot.
- [ ] AC3: Given an unplayable card (can't afford it), when I drop it above the hand area, then
  nothing is played, the card animates back with a short shake, and the `play_error` reason is
  shown next to it.
- [ ] AC4: Given a playable card, when I double-click it, then it is played with the same
  animation as a drop. A single click plays nothing.
- [ ] AC5: Given a play that pays, gains, draws or creates (per the 007 outcome), when it
  resolves, then paid resources fly from the counter to the card, gains fly from the card to the
  counter (the counter pulses), drawn cards slide from the Deck counter into the hand, and
  created cards appear on the tableau.
- [ ] AC6: Given an animation is running, when I press Enter, click End turn or start another
  drag, then the game stays consistent: the action waits until the animation finishes, or the
  animation jumps to its end state. No card is duplicated, lost or left stuck mid-flight.

## Out of scope
- Dropping onto a specific territory (comes with Territories, 001–006).
- Animations for end turn (upkeep, discarding the hand, drawing a new hand) beyond
  what AC6 needs.
- Sound.
- A reduce-motion setting (keep all durations as constants in one place so it is easy to add later).

## Design notes
- **Card views that stay alive:** replace clear-and-rebuild in `main.gd::_refresh` with a
  `uid → CardView` map. Only add, move or free the views that changed, so tweens are not cut off.
- **Drag layer:** a top-level `Control`/`CanvasLayer`. On pickup, the card moves to it and an
  empty placeholder keeps its place in the hand.
- **Feel:** card lifts on hover (about 20px up, 1.08× scale, shadow). Pickup keeps the grab
  offset and scales to 1.1×. The card follows the cursor with a slight lag
  (`lerp` with `1 - exp(-k * delta)`) and tilts with horizontal speed (up to ±12°). The play area
  lights up while a playable card is dragged. For a building or city, a ghost outline shows the
  tableau slot it will land in. Landing uses `TRANS_BACK`/`EASE_OUT` with a small squash.
- **Where the card goes:** use `card.def.is_permanent()`. No rule is copied into the UI.
- **Territories (001–006):** if 003 lands first, dropping a card that needs a target should use
  `valid_targets` (drop onto a highlighted target, or auto-target when there is only one). Double-click
  then starts 003's target selection. 002's choice panel should block drags while a choice is pending.
- The engine API is unchanged apart from 007. `ui/` calls only `play_error`, `play_card` and
  reads the `card_played` outcome.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| all | Manual (UI only; no engine change) |

## Manual check
- [ ] AC1–AC6 each tried in the running game (`godot --path .`).
- [ ] Hover, pickup, dragging and landing feel smooth, with no jitter or jumps. The other hand
  cards close up and spread without snapping.
- [ ] Hand relayouts (after a play or a draw) are animated.
- [ ] Nothing looks wrong after Restart or New game in the middle of an animation.

## Log
