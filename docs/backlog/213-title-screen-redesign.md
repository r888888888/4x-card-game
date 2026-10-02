---
id: 213
title: The title screen as a ledger with large-format buttons
type: feature
status: ready
branch: feat/213-title-screen-redesign
---

## Goal
The title screen looks like the game's front plate, not a menu: option B ("Ledger") of
[title-screen-options.html](../design/title-screen-options.html), with its final art in
[title-screen-ledger-hill.html](../design/title-screen-ledger-hill.html). The title and a column of large-format keys sit
flush left; the right half holds the art (214). The large key is a new control drawn in the specimen's style for the few
places that deserve a big press.

## Acceptance criteria
- [ ] AC1: Given launch, then the title screen is split in two halves: the left holds a caps kicker ("Est. Turn 001"),
  the game's title (the project name, `Display` variation, on two lines as the mock), a caps subtitle ("Civilizations
  in cards"), and the three keys New game, Settings and Exit in one column of one width (`UIKit.button_column`), all
  flush left; the right half is an empty `Control` named `Art` (214 fills it), with a 1 px `CONTROL_DISABLED_BORDER`
  rule on its left edge.
- [ ] AC2: Each key is a `BigButton` (new control): its label in caps (the `BigLabel` variation, `LABEL_SEMIBOLD` at
  `Tokens.TYPE_TITLE`) over a one-line caption (`Caption` variation, `TEXT_DIM`): "Choose a civilization and a seed",
  "Motion, day mode, sound", "Close the game"; a "›" at its right; and a lamp edge `Tokens.SPACE_2` wide along its left
  side, `FIELD` normally and `ACCENT` on the primary key (New game). Its height and paddings are `Tokens` steps
  (judge the size against the mock at the manual check).
- [ ] AC3: The `BigButton` box: `RAISED` fill (`CONTROL` on hover and focus), a 3 px `TEXT` border, `RADIUS_0` (an index
  card), a `SHADOW` plinth offset 4,4. Pressed, it moves +4,+4 and loses the plinth (70 ms snap, as 178's buttons), and
  plays the key sounds of 187 (press on the way down, release on the way up).
- [ ] AC4: New game, Settings and Exit emit `new_game_requested`, `settings_requested` and `exit_requested` as today
  (Settings opens 206's modal once it lands); focus starts on New game; the arrows and Tab move through the column in
  a focus loop; Enter or Space presses the focused key.
- [ ] AC5: Day mode switches the screen at once (183): the keys' fill, border, lamp edge and captions take the Paper
  values while it stays open.

## Out of scope
- The art (214). Other screens' buttons (a `BigButton` is for the title screen only, for now).

## Design notes
- `ui/big_button.gd` (`BigButton extends Button`), its look as `GameTheme` variations (`BigButton`, `BigButtonPrimary`,
  `BigLabel`), not per-control overrides. Sizes are `Tokens` steps; the mock's sizes (420 × 84 at 1280 wide, label
  24 px, caption 15 px) map to the nearest steps.
- `StartScreen` keeps its signals and its `new_game_button` / `settings_button` / `exit_button` test hooks, now
  `BigButton`s.
- The old option pages (`title-screen-options.html`) stay as the record of A and C.

## Test plan
| AC | Test |
|---|---|

## Manual check
- [ ] Launch at 1280×720 and 1920×1080 in Night and Day: the ledger matches the mock's left half (spacing, the keys'
  size, the lamp edges, the press travel).

## Log
- Specced 2026-10-02 from the notes list. Decided 2026-10-02: an options page in `docs/design/` first.
- 2026-10-02: The user picked option B (Ledger) and asked for motion in the right-half graphic, after mid-century
  furniture and light fixtures (`title-screen-ledger-motion.html`: mobile, Sputnik, arc lamp, ball clock).
- 2026-10-02: Those were rejected: the art should be mid-century in style but about the game (dawn of civilization,
  order from chaos, human organization). Tried `title-screen-ledger-themes.html` (census, river fields, ziggurat,
  cuneiform tablet): too literal; the user asked for something more abstract, like a sun rising over a forest.
- 2026-10-02: Four abstract dawns (`title-screen-ledger-dawn.html`); B1 (forest at first light) came closest. Simplified
  to a bare green hill, with the low sun reading as a sunset rather than a dimmed scene
  (`title-screen-ledger-hill.html`); the user chose B1.1, one hill. The superseded pages were deleted. The art is its
  own item, 214; this item is the layout and the keys.
