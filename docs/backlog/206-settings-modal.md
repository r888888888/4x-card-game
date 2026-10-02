---
id: 206
title: A Settings modal, opened from the menu and the title screen
type: feature
status: ready
branch: feat/206-settings-modal
---

## Goal
Settings live in one place: a Settings modal opened from the game menu and from the title screen. The menu shrinks to
game actions (Restart, New game, Settings, Close, Exit), and the seed field moves into Settings with its Restart.

## Acceptance criteria
- [ ] AC1: Given a game in progress and the menu open, then the menu shows, in order: Restart, New game, Settings,
  Close, Exit, as a `UIKit.button_column`; it no longer shows the seed field, Reduce motion, Day mode or sound rows.
- [ ] AC2: When Settings is pressed in the menu, then a `SettingsModal` opens stacked on the menu, with: Reduce motion,
  Day mode, Interface sounds and a volume slider per bus (the rows from 182, 183, 185), and a "Game" section with
  the seed field (showing the current game's seed) and "Restart with seed".
- [ ] AC3: Given the seed field holds 42, when "Restart with seed" is pressed (or Enter in the field), then a new game
  starts on seed 42 with the same civilization and every modal closes; given it holds "abc" or is empty, the button is
  disabled and Enter does nothing.
- [ ] AC4: The menu's Restart restarts on the current game's seed (no field needed).
- [ ] AC5: Given the title screen, when Settings is pressed, then the same `SettingsModal` opens over the title screen,
  without the Game section; the Settings screen (`SettingsScreen`, 099) is gone and nothing pushes it.
- [ ] AC6: Changing a setting in the modal saves it and applies at once (Day mode switches the open menu and modal,
  183's AC4); Esc, Close or a click outside closes only the Settings modal, leaving the menu open.

## Out of scope
- New settings.

## Design notes
- `ui/settings_screen.gd` goes (remove its tests in this item); its rows move to `ui/settings_modal.gd`.
- `GameMenu.start_requested(seed_value)` splits into restart (current seed) and the modal's restart-with-seed.
- Styling follows 207 when that lands.

## Test plan
| AC | Test |
|---|---|

## Manual check
- [ ] Menu → Settings → toggle Day mode: both sheets switch and stay open; Esc closes Settings, then the menu.

## Log
- Specced 2026-10-02 from the notes list. Decided 2026-10-02: one modal for the menu and the title screen; the seed
  field moves into it with its own Restart.
