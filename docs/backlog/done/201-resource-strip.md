---
id: 201
title: The resource strip in the specimen's style
type: feature
status: done
branch: feat/201-resource-strip
---

## Goal
The top bar reads as the mock's strip (`docs/design/transitions.html`, `.dstrip`): a turn plate, then each resource as
a large glyph and figure, with next upkeep's change beside it as a separate, quieter value instead of in parentheses.

## Acceptance criteria
- [x] AC1: Given seed 5 (Sumer) on turn 1 of 3, then the turn shows as a plate: the figure in the mono numeral face on a
  `well` (`Palette.FIELD`) inset, text "T 001" (three digits, zero-padded); with a turn limit it still shows only the
  current turn, and the limit moves to its tooltip ("Turn 1 of 3").
- [x] AC2: Given food 6 with upkeep forecast +4, then the food counter's figure reads "6" and a separate forecast label
  beside it reads "+4" (signed, no parentheses), in `TEXT_DIM` at `TYPE_NUMERAL_S`, separated from the figure by
  `Tokens.SPACE_1` padding; the same for wealth, insight and unrest. A resource with no forecast entry shows no
  forecast label. `counter_text("food")` returns "6" and a new `forecast_text("food")` returns "+4".
- [x] AC3: Given unrest 0 of limit 5 with forecast +0, then the unrest figure reads "0 / 5" and its forecast "+0".
- [x] AC4: Score and pop show glyph and figure with no forecast label.
- [x] AC5: Figures use `Tokens.TYPE_NUMERAL` and glyphs 20 px (the mock's strip); the odometer roll and the +N change
  tag after a change (181) still play.
- [x] AC6: The strip keeps Buy Cards, Knowledge, Log and Menu at its right; the civilization button and End turn leave it
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
| AC1 | `test_counters::test_the_turn_shows_as_a_plate_with_the_limit_in_its_tooltip`; changed: `test_counters::test_each_counter_text_is_that_counters_text`, `test_resource_glyphs::test_the_counters_read_figures_only` ("T 001") |
| AC2 | `test_counters::test_each_resource_shows_its_forecast_as_a_separate_quieter_figure`; changed to figure + `forecast_text`: `test_counters::test_the_food_counter_text_is_the_reading_the_bar_shows`, `test_resource_glyphs::test_the_counters_read_figures_only`, `test_insight::test_the_top_bar_shows_insight_with_its_forecast_and_tags_its_change`, `test_resource_tokens::test_a_refresh_rolls_the_figure_and_the_reading_changes_at_once` |
| AC3 | changed: `test_unrest::test_the_top_bar_shows_unrest_out_of_the_limit_and_tags_its_change` ("2 / 5", "+1"), `test_the_top_bar_shows_unrest_alone_without_a_limit` |
| AC4 | `test_counters::test_score_and_pop_show_no_forecast` |
| AC5 | `test_counters::test_the_figures_are_numerals_beside_20_px_glyphs`; the roll and tags: existing `test_odometer`, `test_resource_tokens` |
| AC6 | `test_counters::test_the_strip_keeps_buy_cards_knowledge_log_and_menu_at_its_right` (passes once 203 has moved End turn) |

Decisions: the plate is a Label in a new `Plate` variation (tabular numerals on a FIELD well) and is
`counter(TopBar.TURN)`; `main.forecast_text(key)` is "" for a counter with no forecast; tests read it through a
`forecast(main, key)` helper so a missing hook fails the test without crashing the rest of the run.

## Manual check
- [ ] Compare with `docs/design/transitions.html`'s strip in both palettes: plate, figure size, forecast spacing.

## Log
- Specced 2026-10-02 from the notes list. Decided 2026-10-02: keep the forecast inline without parentheses, padded as a
  separate value; keep pop.
- 2026-10-02: Built. The turn is a `Plate` label ("T 001", the limit in its tooltip); `Counter` has its own
  `Forecast` label (`set_forecast`, `forecast_text`; a new `Forecast` theme variation), and the top bar's counters use
  `Stat` (TYPE_NUMERAL) beside 20 px glyphs; `main.forecast_text(key)`. The Odometer carries its variation so its size
  reads as its digits'. Test lib: `counter_tag` skips the `Forecast` label (it reads like a tag). Changed:
  `test_ui_smoke::test_the_turn_counter_shows_turn_37_of_100_untruncated` finds the plate by `counter(TURN)` ("T 037").
