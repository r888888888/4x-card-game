---
id: 228
title: Unrest limit moves to the tooltip; the glyph breathes when Anarchy is a turn away
type: feature
status: in-progress
branch: feat/228-unrest-limit-in-tooltip
---

## Goal
The top bar's Unrest counter shows just the figure ("2", not "2 / 5"), so the bar reads like the other resources.
The limit goes in the counter's tooltip. The bar still warns you before you reach the limit, quietly: the unrest
glyph breathes when the next upkeep would bring unrest to the limit, the point where the next turn falls into
Anarchy unless you calm it first.

## Acceptance criteria
- [ ] AC1: Given unrest on, a government with limit 5 and unrest 2, when the top bar refreshes, then the Unrest
  counter's text is "2" (no " / 5"), and its tooltip contains "5".
- [ ] AC2: Given unrest on and a government with no limit (council), when the top bar refreshes, then the counter's
  text is "2" and its tooltip says the government sets no limit (unchanged from today).
- [ ] AC3: Engine query `anarchy_ahead() -> bool`: true when the government has a limit L ≥ 0 and
  unrest + the next upkeep's unrest change (`upkeep_forecast()[UNREST]`, 0 if absent) ≥ L; else false. Cases:
  limit 5, unrest 4, forecast +1 → true; unrest 3, forecast +1 → false; unrest 5, forecast 0 → true;
  unrest 5, forecast −1 → false; no limit → false; unrest off → false; under Anarchy → false.
- [ ] AC4: Given `anarchy_ahead()` true, when the top bar refreshes, then the Unrest glyph is breathing (a looping
  opacity tween on the glyph); given false, it is not breathing and the glyph is at full opacity.
- [ ] AC5: Given `anarchy_ahead()` true and Reduce motion on, when the top bar refreshes, then the glyph doesn't
  breathe and stays at full opacity; turning Reduce motion off while it's still true starts the breathing.
- [ ] AC6: The figure still turns `Palette.WARN` at the limit (unrest ≥ limit) and is ink below it (unchanged).

## Out of scope
- Other near-limit cues from the brainstorm (forecast tint, caution colour, hairline gauge).
- Counting the era's unrest (`unrest.era_unrest`, added at an era unlock before the Anarchy check) in the forecast.
- The Unrest stat on other screens.

## Design notes
- New engine API: `GameEngine.anarchy_ahead()` (in `Modifiers` or beside `at_unrest_limit()`), so the UI doesn't
  work out the threshold itself.
- `Counter` gets a way to breathe its glyph (e.g. `set_breathing(on: bool)`), with the tween paused under
  `Settings.reduce_motion`, like `DragController`'s drop pulse. The period and opacity floor go in `Anim`.
- Tooltip, e.g.: "Civil unrest. Your government tolerates at most 5: a turn that starts there falls into Anarchy.
  Beside it: the change at the next upkeep." When `anarchy_ahead()`, add a line saying the next upkeep brings it to
  the limit.
- `test_unrest.gd::test_the_top_bar_shows_unrest_out_of_the_limit_and_rolls_its_change_with_no_tag` asserts
  "2 / 5". This item changes that criterion on purpose (the user's request), so the test is updated to "2".

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_unrest::test_the_top_bar_shows_unrest_alone_with_the_limit_in_its_tooltip_and_rolls_its_change_with_no_tag` (renamed from `…out_of_the_limit…`) |
| AC2 | `test_unrest::test_the_top_bar_shows_unrest_alone_without_a_limit` (tooltip check added; passes already) |
| AC3 | `test_unrest::test_anarchy_ahead_when_the_next_upkeep_brings_unrest_to_the_limit`, `test_anarchy::test_no_anarchy_ahead_while_anarchy_rules` |
| AC4 | `test_unrest::test_the_unrest_glyph_breathes_while_anarchy_is_ahead` |
| AC5 | `test_unrest::test_the_unrest_glyph_holds_still_with_reduce_motion` |
| AC6 | `test_unrest::test_the_top_bar_shows_unrest_alone_with_the_limit_in_its_tooltip_and_rolls_its_change_with_no_tag` (unchanged colour asserts) |

## Manual check
- [ ] The breathing reads as subtle: slow (around 2 s a cycle), never fully fading, not distracting over several turns.
- [ ] With Reduce motion on, the glyph is still.
- [ ] Hovering the counter shows the limit.

## Log
- Brainstorm of near-limit cues offered: forecast tint, caution colour one step below, breathing glyph, hairline
  gauge (also mentioned: tick sound pitch, End Turn lamp flicker). The user chose the breathing glyph, and "near" as
  "the next upkeep reaches the limit".
