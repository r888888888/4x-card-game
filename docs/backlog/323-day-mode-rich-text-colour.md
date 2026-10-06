---
id: 323
title: Modal rich text (an event's flavour) is near-white on paper in Day mode
type: bug
status: in-progress
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
- [ ] AC1: Given a game in Day mode whose turn start drew Envoys, when the event modal is open, then its rich text
  (the flavour line) reads `Palette.TEXT`'s Day value (`22211f`), not white.
- [ ] AC2: Given a game in progress in Night mode, when Day mode is switched on and then off, then every `RichBody`
  text in main (the event, card details, revolt and abandon modals' text) that sets no colour of its own reads
  `Palette.TEXT` in each mode.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_choice_modal::test_bug_323_the_event_modals_text_reads_on_paper_in_day_mode` |
| AC2 | `test_day_mode::test_bug_323_rich_body_text_follows_day_mode` |

## Root cause
<!-- Filled in after the fix. -->

## Manual check
- Seed 7, Sumer, Day mode: the Envoys flavour line reads dark on the paper sheet; same for a card's details (right
  click a card) and the new-game screen's civilization text. Night mode looks as before.

## Log
- 2026-10-05: specced. The `RichBody` theme variation sets fonts but no `default_color`, so every `RichBody`
  label draws in Godot's default white whatever the mode. Night's dark sheets hid it.
