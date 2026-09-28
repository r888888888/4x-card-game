---
id: 018
title: Move New game, Restart, seed and Reduce motion into a settings menu
type: feature
status: review
branch: feat/018-settings-menu
---

## Goal
The top bar is crowded with controls you use once per game (seed field, Restart, New game, Reduce
motion) next to the stats you read every turn. Put those controls in a menu modal, opened from a
button or Esc, so the top bar shows only the game state.

## Acceptance criteria
<!-- UI-only item. Checked in the running game. Engine calls are the same ones the buttons use today. -->
- [x] AC1: Given a game in progress, then the top bar shows the stats (turn, food, score, population,
  piles), the current seed as read-only text ("Seed 4242"), and a "Menu (Esc)" button, and nothing
  else. The seed field, Restart, New game and Reduce motion are not in the top bar.
- [x] AC2: Given the modal is closed, when I click "Menu (Esc)" or press Esc while nothing else uses
  Esc (no targeting, no drag, no focused card), then a centred modal opens over a dimmed board. It
  contains, in order: the seed field (holding the current seed), Restart, New game, the Reduce motion
  toggle, and Close. The seed field has keyboard focus.
- [x] AC3: Given the modal is open, when I press Restart, then a new game starts with the seed in the
  field (a random seed if the field is not a whole number), and the modal closes. New game starts a
  game with a random seed and closes the modal. The top bar seed text shows the new seed in both cases.
- [x] AC4: Given the modal is open, when I press the Reduce motion toggle, then the setting changes,
  is saved, and takes effect at once (same behaviour as 016), and the modal stays open.
- [x] AC5: Given the modal is open, when I press Esc, click Close, or click the dimmed area outside the
  panel, then it closes, the game is unchanged (same turn, hand and food), and keyboard focus returns
  to where it was before it opened (the focused card, or the Menu button).
- [x] AC6: Given the modal is open, then game input is blocked: E does not end the turn, arrows don't
  move card focus, and cards can't be clicked or dragged. Tab and Shift+Tab cycle only through the
  modal's controls, each with the 017 focus ring.

## Out of scope
- New settings (volume, UI scale, text size).
- Pausing anything: the game is turn-based and has no timers.
- A confirmation before abandoning a game.
- A start/title screen.

## Design notes
- No engine or autoload change: Restart and New game call `_start_game`, the toggle calls
  `Settings.set_reduce_motion`, as today. So there are no new tests; the test count stays at 159.
- Build the modal with the existing `_overlay()` helper, like the explore choice and game-over panels.
  z-order: above the explore choice, so it can open during a choice; the game-over overlay's own
  "Replay this seed" and "New game" stay as they are.
- Esc precedence (unchanged first, new last): cancel targeting → cancel drag → drop card focus →
  open the menu. When open, Esc closes it before anything else sees it.
- Builds on 017 (keyboard focus). Merge `feat/017-keyboard-play` into `main` first, then branch.

## Test plan
| AC | Test |
|---|---|
| all | Manual (UI only). Also run by a scratch driver (not committed) that sends synthetic keys and clicks through the real UI and checks engine state: 28 checks covering AC1–AC6, all passing. |

## Manual check
Run `godot --path .`.
- [ ] **AC1:** the top bar shows only the stats, "Seed NNNN" and "Menu (Esc)".
- [ ] **AC2:** press Esc: the menu opens with the seed field focused, holding the current seed.
- [ ] **AC3:** type `4242`, press Restart: the menu closes, the top bar reads "Seed 4242", turn 1.
  Open it again and press New game: a different seed, turn 1.
- [ ] **AC4:** open the menu, toggle Reduce motion: the label changes and the menu stays open. Close it
  and hover a card: no lift. Relaunch: still on.
- [ ] **AC5:** play a card, focus another with →, press Esc twice (drop focus, then open), and close with
  Esc: same turn and hand. Focus a card with →, then click "Menu (Esc)" and click Close: the ring is
  back on that card. Clicking the dim area also closes it.
- [ ] **AC6:** with the menu open, press E and →: nothing happens on the board. Tab cycles only
  through the menu's controls.

## Log
- Enter in the seed field presses Restart (not in the ACs).
- Opening the menu resets the seed field to this game's seed, so a seed typed and then abandoned doesn't
  stick. For the same reason, the game-over "Replay this seed" now replays `engine.seed_value`, not the
  field.
- Clicking the Menu button moves the Godot focus before `pressed` fires, which drops the card focus.
  `_on_gui_focus_changed` remembers the card when the focus goes to the Menu button, so Close can give it back.
- A click anywhere on the dimmed area closes the menu and nothing under it gets the click. That includes
  a card: the click is used up, and the card isn't played or dragged.
- Tab, Shift+Tab and Up/Down wrap inside the menu through explicit `focus_next`/`focus_previous`/neighbour
  paths. Left/Right point to the control itself, so they can't leave the menu.
- Opening the menu cancels targeting (it's UI state; the game is unchanged).
- UI only; test count unchanged (159).
