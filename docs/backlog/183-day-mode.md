---
id: 183
title: Day mode: the Paper palette, switched at once
type: feature
status: ready
branch: feat/183-day-mode
---

## Goal
The player can switch the whole game to the style guide's Paper palette ([docs/design/mcm-style-guide.md](../design/mcm-style-guide.md)
§4: warm off-white sheets, charcoal ink, the same support hues darkened to read on paper), the drafting desk by day,
with a Day mode legend key beside Reduce motion. The switch takes effect at once, mid-game, on every open screen.
Night shift (178) stays the default.

## Acceptance criteria
- [ ] AC1: The settings file keeps `day_mode` (default false) under `[ui]`, saved and loaded like `reduce_motion`; a
  value that isn't true or false falls back to false with the warning "settings file '<path>': [ui] 'day_mode' must
  be true or false, got <value>; using false". `Settings.set_day_mode(on)` saves it and emits `changed`.
- [ ] AC2: Every `Palette` colour has a Night value (178's) and a Day value (the guide's Paper column, mapped in Design
  notes), and reads the Day value while day mode is on: given day mode on, `BACKGROUND` is efe8da, `RAISED` f8f4ec,
  `CONTROL` dcd3c2, `TEXT` 22211f, `ACCENT` a8401b; given it off, 178's values. In both modes `test_theme` checks the
  guide's contrast: `TEXT` and `TEXT_DIM` on `RAISED` and on `BACKGROUND` at least 4.5:1, `TEXT_ON_ACCENT` on `ACCENT`
  at least 4.5:1, and `CONTROL_BORDER` and each glyph hue (`GAIN`, `WEALTH`, `INSIGHT`, `UNREST`, `POP`) on `RAISED`
  at least 3:1.
- [ ] AC3: Given a game in progress (turn 3, five cards in hand, the top bar showing), when day mode is turned on, then
  without a restart main's theme is rebuilt from the Day values (a `Button`'s normal box fill is dcd3c2), the board's
  background, every card view's panel and band, the top bar's glyphs and figures and the log use Day values; the turn,
  the hand, the resources and the log's lines are unchanged. Turning it off brings back every Night value the same way.
- [ ] AC4: Screens and modals open when the switch happens (the game menu, the settings screen, a card's details, the
  tech tree) take the new values at once too, and stay open.
- [ ] AC5: The settings screen and the game menu show a "Day mode" row (a label and a `LegendKey`, as 182's Reduce
  motion row) under Reduce motion; it shows the current setting when opened, toggling it calls `Settings.set_day_mode`,
  and changing it on one shows on the other. It is in both focus loops.
- [ ] AC6: Nothing under `ui/` keeps a colour from before a switch: no script holds a `Palette` colour in a constant
  (`const X := Palette.Y`), which `test_ui_structure` checks; the colours read at the time of drawing (or are reapplied
  on the switch).

## Out of scope
- Following the computer's light or dark setting; a separate Paper set of card art (there is none); the HTML pages in
  `docs/design/` (they already have both modes).

## Design notes
- `Palette` keeps one name per role and two values per name: for example `static var BACKGROUND: Color` set from a
  `NIGHT` or `DAY` table by `Palette.use(day: bool)`, called at start-up from `Settings` and on `Settings.changed`.
  Today ten `const X := Palette.Y` aliases (`TopBar.FOOD_COLOR`, `CardView.TYPE_COLORS`, `UIKit.COST_COLOR`, …) freeze a
  colour at load time; they become functions or read `Palette` directly (AC6).
- On the switch, main rebuilds its theme (`GameTheme.build()`) and refreshes its components; views that set colours in
  code (card views, the top bar's glyphs, the log's text) reapply them. The engine is untouched.
- Day values (guide §4, Paper): `BACKGROUND` efe8da · `RAISED`, `TILE` f8f4ec · `FIELD`, `PANEL`, `STRIP_BG`,
  `CONTROL_DISABLED` e3daca · `CONTROL` dcd3c2 · `CONTROL_BORDER` 6f685c · `CONTROL_DISABLED_BORDER` cfc6b5 · `TEXT`,
  `STRIP_TEXT`, `LOG_TEXT`, `EDGE`, `SHADOW` 22211f · `TEXT_DIM`, `PILES` 57534b · `TEXT_DISABLED` 7a7468 · `ACCENT`
  a8401b · `TEXT_ON_ACCENT` fbf6ec · `GAIN` 4e6b47 · `COST`, `WARN`, `UNREST` 9b3424 · `FOCUS`, `POP` 1f6a68 · `WEALTH`
  a07514 (the guide's icon-only gold) · `INSIGHT` 35597c · card types (the planes) `ACTION` 8aa7c4, `BUILDING` a3aa6a,
  `CITY` d9a441, `TERRITORY` 9db592, `TECH` 5e9c97, `EVENT` c9705c · tech tree `RESEARCHED` 1f6a68, `AVAILABLE`
  22211f, `FUTURE` 7a7468, `LOCKED` 6f685c · `DIM_BG` e8e1d3, `DIM_BORDER` b9af9c, `FRONTIER_BG` efe8da. The
  see-through layers (`DIMMER`, `SCRIM`, `FRONTIER_HATCH`, `GHOST_*`, `DROP_BG`, `HINT_BG`, `OUTLINE`, `FAINT_EDGE`)
  take ink at low alpha instead of white (scrim: ink at 40%).
- Builds on 178 (Night values, theme) and 182 (the legend key row).

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|

## Manual check
- [ ] Seed 5, Egypt, mid-game: switch Day mode on from the menu; the board, cards, top bar, log, tech tree, supply
  screen, a modal and the game-over sheet all read on warm paper with charcoal ink, and switching back restores Night.
- [ ] Hatching on a frontier territory, the drag ghost and the drop highlight are still visible on paper.
- [ ] The wealth coin reads as gold, not brown, in Day mode.

## Log
- 2026-10-01: Specced. Decided 2026-10-01: chosen with a Day mode legend key (not Day / Night / Follow system), and the
  switch applies at once, mid-game, rather than on the next screen.
