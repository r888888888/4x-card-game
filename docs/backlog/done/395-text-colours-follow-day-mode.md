---
id: 395
title: Glossary terms and log notes are written in fixed colours that vanish on Day's paper
type: bug
status: done
branch: fix/395-text-colours-follow-day-mode
---

## Reproduction
- Seed: any (seen on `--civ sumer --seed 5`)
- Steps:
  1. Settings → Day mode on.
  2. Open the Granary's details (or any card with a "How it works" section).
- Expected: the glossary terms ("Housing", "Famine Guard", "Workers") read clearly on the cream sheet.
- Actual: they are pale yellow `#ffd966`, 1.25:1 against Day's `RAISED` (the guide asks 4.5:1 for text).

The same fixed BBCode colours write three log notes: a refused action's error (`#e88`, card_actions.gd), a drag
hint (`#ffd966`, drag_controller.gd) and a log drawer heading (`#e8c547`, log_drawer.gd). None follow Day mode, and
the suite's colour-literal check (`test_theme::test_no_colour_literals_outside_the_palette`) only looks for
`Color(...)`, so BBCode hex slips past it.

## Acceptance criteria
- [x] AC1 (role): `Palette.EMPHASIS` is a text role for gold text that stands out (a glossary term, a hint, a log
  heading): Night `#ffd966` (unchanged), Day `#7a5200`. In each mode it has at least 4.5:1 contrast on `RAISED` and
  on `PANEL`.
- [x] AC2 (terms): `CardDetailsModal.body_bbcode` writes each term in `Palette.EMPHASIS` of the current mode: in Day
  its `[color=…]` is Day's value, in Night Night's.
- [x] AC3 (log notes): the refused action's error is written in `Palette.COST`, the drag hint and the log drawer's
  heading in `Palette.EMPHASIS`, each in the current mode (covered by AC4's scan plus the manual check).
- [x] AC4 (check): the colour-literal check also fails on a BBCode colour written as a literal (`[color=#…]` or
  `[color=<name>]`) in any `ui/` script but `palette.gd`; `ui/` has none after the fix.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_day_mode::test_emphasis_text_reads_on_sheets_and_the_log_in_both_modes` |
| AC2 | `test_day_mode::test_glossary_terms_are_written_in_the_modes_emphasis` |
| AC4 | `test_theme::test_no_bbcode_colour_literals_outside_the_palette` |

## Root cause
Rich text was coloured by writing a hex into the BBCode string (`[color=#ffd966]`), chosen when the game only had
Night. Day mode (183) swapped every `Palette` role but couldn't reach a hex inside a string, and the colour-literal
check (`test_theme`) only matched `Color(...)` calls, so nothing flagged them. Now `Palette.bbcode(text, role)` writes
the role's current value, and the check also rejects `[color=…]` literals outside `palette.gd`.

## Manual check
- [ ] `godot --path . -- --civ sumer --seed 5`, Day mode on: open the Granary's details; the terms under "How it
  works" are dark ochre and easy to read. Switch to Night: they are the old pale gold.
- [ ] In Day, drag a card you can't play onto the realm: the log's error note is red and readable; a drag hint is
  ochre.

## Log
- 2026-10-07: specced from the 381 screenshots (the user asked for the fix).
- 2026-10-07: green (2444 → 2447). The "Game over" log heading moves from `#e8c547` to `EMPHASIS` (`#ffd966` in
  Night), a shade lighter. Log lines already written keep the colour of the mode they were written in; a switch
  doesn't recolour the log's history (follow-up if it matters). CLAUDE.md's colour rule names BBCode.
