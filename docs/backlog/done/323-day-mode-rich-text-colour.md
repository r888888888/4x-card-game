---
id: 323
title: Modal rich text (an event's flavour) is near-white on paper in Day mode
type: bug
status: done
branch: fix/323-day-mode-rich-text-colour
---

## Reproduction
- Seed: 7, Sumer (`godot --path . -- --civ sumer --seed 7`), Settings → Day mode on.
- Steps:
  1. Play to about turn 5, when a turn start draws "Envoys from the Hills".
  2. Read the italic flavour line under "A NEW EVENT".
- Expected: the flavour reads in Day text ink on the paper sheet, as everything else on it does.
- Actual: it is near-white on paper, almost unreadable. In Night mode it reads fine.

## Acceptance criteria
- [x] AC1: Given a game in Day mode whose turn start drew Envoys, when the event modal is open, then its rich text
  (the flavour line) reads `Palette.TEXT`'s Day value (`22211f`), not white.
- [x] AC2: Given a game in progress in Night mode, when Day mode is switched on and then off, then every `RichBody`
  text in main (the event, card details, revolt and abandon modals' text) that sets no colour of its own reads
  `Palette.TEXT` in each mode.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_choice_modal::test_bug_323_the_event_modals_text_reads_on_paper_in_day_mode` |
| AC2 | `test_day_mode::test_bug_323_rich_body_text_follows_day_mode` |

## Root cause
`GameTheme.build()` gave the `RichBody` variation its fonts but no `default_color`, so every `RichBody` label (the
event, card details, revolt and abandon modals, the new-game screen's detail pane) drew in Godot's default white in
both modes. No test looked at rich text's colour: 183's and 197's Day-mode checks covered panels, buttons and card
lines. The theme now sets `default_color` to `Palette.TEXT`; it is rebuilt on a Day switch, so it follows.

## Manual check
- Seed 7, Sumer, Day mode: the Envoys flavour line reads dark on the paper sheet; same for a card's details (right
  click a card) and the new-game screen's civilization text. Night mode looks as before.

## Log
- 2026-10-05: specced. The `RichBody` theme variation sets fonts but no `default_color`, so every `RichBody`
  label draws in Godot's default white whatever the mode. Night's dark sheets hid it.
- 2026-10-05: fixed in `ui/game_theme.gd` (one line). Night's rich text moves from pure white to `TEXT` (`ede6d6`).
  Other italic flavour: the identity cards' `Flavor` label variation already reads `TEXT_DIM` from the theme. Not
  covered: `UIKit.message_overlay`'s body (the data-load-error overlay) has no variation, so it stays white on Day's
  paper panel; follow-up: give it `RichBody`.
