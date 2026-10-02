---
id: 201
title: The resource strip in the specimen's style
type: feature
status: ready
branch: feat/201-resource-strip
---

## Goal
The top bar reads as the mock's strip (`docs/design/transitions.html`, `.dstrip`): a turn plate, then each resource as
a large glyph and figure, with next upkeep's change beside it as a separate, quieter value instead of in parentheses.

## Acceptance criteria
- [ ] AC1: Given seed 5 (Sumer) on turn 1 of 3, then the turn shows as a plate: the figure in the mono numeral face on a
  `well` (`Palette.FIELD`) inset, text "T 001" (three digits, zero-padded); with a turn limit it still shows only the
  current turn, and the limit moves to its tooltip ("Turn 1 of 3").
- [ ] AC2: Given food 6 with upkeep forecast +4, then the food counter's figure reads "6" and a separate forecast label
  beside it reads "+4" (signed, no parentheses), in `TEXT_DIM` at `TYPE_NUMERAL_S`, separated from the figure by
  `Tokens.SPACE_1` padding; the same for wealth, insight and unrest. A resource with no forecast entry shows no
  forecast label. `counter_text("food")` returns "6" and a new `forecast_text("food")` returns "+4".
- [ ] AC3: Given unrest 0 of limit 5 with forecast +0, then the unrest figure reads "0 / 5" and its forecast "+0".
- [ ] AC4: Score and pop show glyph and figure with no forecast label.
- [ ] AC5: Figures use `Tokens.TYPE_NUMERAL` and glyphs 20 px (the mock's strip); the odometer roll and the +N change
  tag after a change (181) still play.
- [ ] AC6: The strip keeps Buy Cards, Knowledge, Log and Menu at its right; the civilization button and End turn leave it
  (202, 203).

## Out of scope
- The sidebar (202) and End turn (203).

## Design notes
- `TopBar._forecast_text` goes; the forecast becomes its own Label per counter. Test hooks `counter_text` /
  `forecast_text`.
- Build after 202 and 203 (or with AC6 waiting for them), so the civ button and End turn have somewhere to go.

## Test plan
| AC | Test |
|---|---|

## Manual check
- [ ] Compare with `docs/design/transitions.html`'s strip in both palettes: plate, figure size, forecast spacing.

## Log
- Specced 2026-10-02 from the notes list. Decided 2026-10-02: keep the forecast inline without parentheses, padded as a
  separate value; keep pop.
