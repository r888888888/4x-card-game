---
id: 324
title: The data-load-error overlay's lines are white on paper in Day mode
type: bug
status: in-progress
branch: fix/324-day-mode-load-error-text
---

## Reproduction
- Seed: not needed.
- Steps:
  1. Turn Day mode on (Settings → Day mode), quit.
  2. Break a card in `data/cards.json` (e.g. an unknown op) and run `godot --path .`.
  3. Read the overlay "Game data has errors — fix data/*.json and restart".
- Expected: the error lines read in `Palette.TEXT` on the overlay's panel, in either mode.
- Actual: in Day mode they are white on the paper panel, almost unreadable. `UIKit.message_overlay` builds its body
  as a plain `RichTextLabel` with no theme variation, so it draws in Godot's default white (found while fixing 323).

## Acceptance criteria
- [ ] AC1: Given Day mode on and `Game.load_errors` holding one error, when main opens, then the overlay shows that
  error, and its text reads `Palette.TEXT`'s Day value (`22211f`).
- [ ] AC2: Given Night mode and the same error, when main opens, then the overlay's error text reads `Palette.TEXT`'s
  Night value (`ede6d6`).

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_day_mode::test_bug_324_load_errors_read_on_paper_in_day_mode` |
| AC2 | `test_day_mode::test_bug_324_load_errors_read_text_in_night_mode` |

## Root cause
<!-- Filled in by Claude after the fix. -->

## Manual check
- With a broken `data/cards.json`, the overlay's error lines read dark on paper in Day mode and light on the dark
  panel in Night mode, at the body text size.

## Log
- 2026-10-05: specced from 323's follow-up. Likely fix: give the body the `RichBody` variation, which reads
  `Palette.TEXT` since 323 (it also sets the body text size). Tests open main with `Game.load_errors` set and put it
  back after.
