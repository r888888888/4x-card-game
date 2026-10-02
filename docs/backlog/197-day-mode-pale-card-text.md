---
id: 197
title: Day mode: card type lines and territory keywords are pale on paper
type: bug
status: review
branch: fix/197-day-mode-pale-card-text
---

## Reproduction
- Seed: 5, Sumer (any game).
- Steps:
  1. Turn Day mode on; start a game (`godot --path . -- --civ sumer --turns 3 --seed 5`).
  2. Look at the hand cards' type line ("◆ Action · explore", "■ Building") and Delta Marsh's keyword line in the Realm
     ("Marsh · Fresh Water · Flood …").
- Expected: both read as secondary ink on paper, like the rest of the card's text.
- Actual: they are near-white on the off-white card (Paper `TERRITORY` 9db592 lightened 50% is about cedad8 on f8f4ec,
  about 1.3:1).

Cause found while speccing: `CardFace` draws the type line and the keyword line in the card type's plane colour
lightened 50% (`color.lightened(0.5)`, `ui/card_face.gd` lines 57 and 102), and a settled territory's keywords in
`CardView.HIGHLIGHT_COLOR.lightened(0.6)` (line 183). Lightening reads on Night's dark sheets and washes out on Paper.

## Acceptance criteria
- [x] AC1: Given Day mode on and seed 5 (Sumer), when the hand and the Realm show, then every card face's type line and
  keyword line (hand cards, the settled Delta Marsh, a frontier territory, a supply card) is drawn in a colour with
  at least 4.5:1 contrast on the card's panel colour (`Palette.RAISED`), measured with `test_theme`'s contrast helper.
- [x] AC2: Given Night mode, the same lines also have at least 4.5:1 on the card's panel colour.
- [x] AC3: Given a game in progress, when Day mode is switched on and off, then the type and keyword lines take the new
  mode's colour at once (183's AC3), without a restart.
- [x] AC4: No `ui/` script derives a text colour by lightening or darkening a `Palette` colour (`.lightened(`,
  `.darkened(` on a colour passed as a font or `default_color`); `test_ui_structure` checks for `lightened(` /
  `darkened(` in `card_face.gd` text colours. (If a palette role is missing, add one, e.g. `TEXT_DIM`.)

## Out of scope
- Restyling the type line otherwise (size, caps): 198 and the board redesign handle the card look.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_day_mode::test_bug_197_type_and_keyword_lines_read_on_paper_in_day_mode` (hand, Delta Marsh, a frontier card, every supply card) |
| AC2 | `test_day_mode::test_bug_197_type_and_keyword_lines_read_on_night_sheets` |
| AC3 | `test_day_mode::test_bug_197_type_and_keyword_lines_switch_with_day_mode_mid_game` |
| AC4 | `test_ui_structure::test_bug_197_card_faces_derive_no_text_colour_by_lightening_or_darkening` |

## Manual check
- [ ] Day mode, seed 5 Sumer: the hand's type lines, Delta Marsh's keywords and a frontier card's keywords and "▢N ⌂N"
  read as grey ink on paper; in Night they read as before (a little less tinted).

## Root cause
`CardFace` derived its secondary text colours from the card type's plane colour (`color.lightened(0.5)`) and the
gold highlight (`HIGHLIGHT_COLOR.lightened(0.6)`). Lightening a mid-tone keeps contrast on Night's dark sheet but
lands near white on Paper. They now use the palette's secondary ink, `Palette.TEXT_DIM` (4.5:1 on `RAISED` in both
modes, guarded by 183's contrast test), and repaint with the face on a mode switch. The frontier keyword line is now a
Label named `Keywords`, like the settled one.

## Log
- Specced 2026-10-02 from the notes list ("white text on beige background in day mode"). Found the cause by rendering
  the board in Day mode offscreen (`--write-movie` under a scratch `HOME`).
- 2026-10-02: Fixed with `TEXT_DIM`; the frontier's printed "▢N ⌂N" line was lightened too and moved to it as well.
