---
id: 100
title: Buttons fit their text; stacked menu buttons share one width
type: feature
status: in-progress
branch: feat/100-buttons-fit-their-text
---

## Goal
Almost every button stretches across its panel today, because a `Button` in a `VBoxContainer` fills the column by
default. Apply the UI design rule in CLAUDE.md: a button sizes to its text plus padding. A stacked column of buttons
in a menu or a screen shares one width, the widest button's, with the column centred. List rows and content tiles
may still fill.

## Acceptance criteria
<!-- UI tests in the real main scene (tests/test_button_widths.gd), measured after layout (wait_frames) at
1920×1080. "Fits its text" means the button's width equals its minimum width (get_combined_minimum_size().x) ±1px. -->
- [ ] AC1: Stacked columns. On the title screen (New game, Settings, Exit), the settings screen (Reduce motion,
  Back), the new game screen (Start, Back), the menu (Restart, New game, Reduce motion, Close, Exit) and the
  game-over overlay (Replay this seed, New game), every button in the column has the same width, equal to the
  widest button's minimum width ±1px, and the column's horizontal centre is within 1px of its panel's centre.
- [ ] AC2: Modal and choice buttons fit their text: Close in the card details, Close in Buy Cards, Close in the
  Knowledge modal, OK in the drawn-event modal, and Decline in the research choice.
- [ ] AC3: Board buttons fit their text: the top bar's Menu, the Realm heading's Collapse all, the Relieve Famine
  button, and each territory group's toggle and grow buttons (these already do; the test keeps them that way).
- [ ] AC4: Side panel. Buy Cards, Knowledge and End turn fit their text, with their left edge at the side panel's
  left edge (±1px). The civilization and government lines still span the side panel's width (±1px).
- [ ] AC5: Tech tiles in the Knowledge modal still fill their era column: every tech button in a column has the
  column's width (±1px).
- [ ] AC6: A seed field still fills its row on the new game screen and in the menu (the rule is for buttons only):
  the seed field's right edge is within 1px of its row's right edge.

## Out of scope
- Restyling buttons (colours, fonts, padding) or reordering them.
- Card views and anything that isn't a `Button`.

## Design notes
- UI only; the engine doesn't change.
- Suggested: `UIKit.button()` sets `size_flags_horizontal = SIZE_SHRINK_BEGIN` so a button never fills by default,
  and `UIKit.button_column(parent)` returns a `VBoxContainer` with `SIZE_SHRINK_CENTER` whose buttons use `SIZE_FILL`
  (so they share the widest width). Row and tile buttons (identity lines, techs) set `SIZE_FILL` explicitly.
- End turn keeps its height (60) and font; it just stops stretching.
- Each overlay needs to be open to be laid out: the tests open them one at a time (title, settings, new game, the
  menu, game over via `play_seed_1`, Buy Cards, card details, Knowledge, the research choice and the event modal
  through a fixture game if the real data doesn't reach them quickly).

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_button_widths::test_…` |

## Manual check
- [ ] Run `godot --path .`: on the title, new game and settings screens the buttons form a neat centred column of
  one width, not a bar across the panel.
- [ ] Start seed 1: Buy Cards, Knowledge and End turn in the side panel are only as wide as their text; the
  civilization line still spans the panel.
- [ ] Open the menu (Esc), Buy Cards (S), Knowledge (T) and a card's details (I): the buttons look deliberate, not
  stretched, and nothing is cut off.

## Log
- 2026-09-30: Specced with the new CLAUDE.md "UI design" rule. The user chose: fix all buttons now; stacked menu
  columns are the exception; side-panel action buttons fit their text left-aligned while the civilization and
  government lines stay full width (list rows); tech tiles are exempt.
