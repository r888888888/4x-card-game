---
id: 008
title: Drag cards from hand to play them, with animations
type: feature
status: review
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
| all | Manual (UI only; no engine change). Also exercised by a scratch driver that plays the real UI with synthetic mouse input and checks engine state and that every view comes to rest (not committed). |

## Manual check
Run `godot --path .`, type seed `7` and press Restart.
- [ ] **Deal:** 5 cards fly in one after another from the Deck counter and settle in the hand.
- [ ] **Hover:** a hand card lifts, grows a little and gets a white border and shadow. Moving off
  it lowers it again.
- [ ] **AC1, building:** drag the Farm up into the tableau. The tableau lights up gold, and a faint outline
  appears where the Farm will land. The card follows the cursor with a little lag and tilts when you move
  sideways. Let go: it shrinks into the outlined slot with a small squash, "−2 food" flies from the
  counter to the card, and the rest of the hand slides left to close the gap.
- [ ] **AC1, action:** drag Forage into the tableau. It pops, then shrinks and fades into the Discard
  counter, "+2 food" flies to the Food counter, and the counter pulses.
- [ ] **AC2:** pick up a card and press Esc; pick one up and right-click; pick one up and drop it back
  on the hand. Each time the card flies back to its own slot and nothing is played.
- [ ] **AC3:** drag the Settler (5 food, greyed out) over the tableau. There is no gold highlight, and its
  border turns red. Let go: it flies back and shakes, and "Settler needs 5 food (you have …)"
  appears over it and fades.
- [ ] **AC4:** a single click on a card does nothing. A double-click on Scout plays it: it goes
  to the discard pile, and 2 new cards fly in from the deck.
- [ ] **AC5:** play Settler once you can afford it: food flies to the card, and the new City pops onto the tableau.
- [ ] **AC6:** pick up a card and press Enter mid-drag. The drag ends, the hand is discarded
  to the pile, and a new hand is dealt, with no card left floating. Press Restart twice quickly during
  the deal: the board ends up clean.
- [ ] Nothing jitters or jumps, and lifted or flying cards never go under the game-over overlay.

## Log
- Movement is state-based rather than one-off tweens. Each card view chases a target every frame:
  its slot at rest, the cursor while dragged, or a new slot when flying. Interrupting an animation
  (End turn, Restart, another play) just changes the target, so no card can get stuck mid-flight (AC6).
  Tweens are used only for effects that can't be interrupted: squash, shake, pop-in, and the fly to the discard pile.
- Cards rest inside slot Controls in the hand and tableau containers, so scrolling and clipping keep
  working. When a slot moves (the row relayouts), the card keeps its place on screen and slides into the
  new spot.
- Found while testing: a card whose text needs more height than the nominal tableau size (the Capital needs
  181px, not 150) stretched to the full tableau height, and could never "land". Cards now size to fit
  their text, and the slot follows.
- The drop zone is the tableau area. Dropping anywhere else (the hand, the log) cancels.
- Review: the hovered card's border was clipped by the hand box. There is now 40px of room above the hand row and 24px on each side.
- Not done (out of scope or left for later): fanned hand, counters that tick up when the token arrives,
  a reduce-motion setting (all timings are in `ui/anim.gd`), end-turn upkeep tokens.
