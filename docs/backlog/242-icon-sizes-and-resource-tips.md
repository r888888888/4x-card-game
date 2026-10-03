---
id: 242
title: Bigger top-bar glyphs, a pop-figure meter, a green Grow sprout, and tooltips that name each resource
type: feature
status: red-review
branch: feat/242-icon-sizes-and-resource-tips
---

## Goal
The top bar's glyphs (20 px) sit small beside their figures (`TYPE_NUMERAL`, 26 px). The territory view's pop meter
uses plain round pips where the rest of the game shows pop as the figure glyph, and Grow's food sprout is untinted
while food is green everywhere else. Hovering a top-bar counter tells you about the forecast but never what the
resource is. After this the glyphs match their text, pop reads as pop everywhere, and each tooltip opens by naming
its resource.

## Acceptance criteria
- [ ] AC1: Given the top bar, then each counter's glyph (food, wealth, insight, unrest, score, pop) is
  `Tokens.TYPE_NUMERAL` px square, the size of the figure beside it.
- [ ] AC2: Given a territory view with population on and pop 2 of housing 4, then its meter is 4 pop glyphs
  (`Icons.RESOURCES[TopBar.POP]`), each `Tokens.TYPE_BODY` px square (the stats line's text size): the first 2
  tinted `Palette.POP`, the other 2 a dimmer tint. After a Grow, 3 are tinted `Palette.POP`.
- [ ] AC3: Given a territory view, then Grow's food icon is drawn in `Palette.GAIN` (enabled), in Night and in Day.
- [ ] AC4: Given the top bar after a refresh, then each counter's tooltip starts by naming its resource and saying
  what it is for: Food (feeds your pop at upkeep, pays for Grow), Wealth (buys cards from the Supply), Insight (pays
  for techs), Unrest (civil unrest, with the limit as now), Score (victory points), Pop (your people: they work and
  house in your territories). The existing forecast, famine and limit sentences stay.

## Out of scope
- The Supply screen's counters (they carry a word prefix, not just a glyph).
- Resizing card-face or log glyphs.

## Design notes
- `TopBar.GLYPH` becomes `Tokens.TYPE_NUMERAL`.
- The meter's pips become TextureRects from `Icons.glyph(TopBar.POP, Tokens.TYPE_BODY)`; filled vs empty is the
  tint (`self_modulate`), replacing the `PipFilled`/`PipEmpty` Panel variations, which go. `test_grow_meter`'s
  `filled()` hook reads the tint instead of the variation.
- Grow's icon tint: the button's `icon_*_color` theme colours set to `Palette.GAIN`, repainted on a palette change.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_counters::test_each_top_bar_glyph_is_the_size_of_its_figure` |
| AC2 | `test_grow_meter::test_the_meter_pips_are_pop_glyphs_the_size_of_the_stats_text`; the existing meter tests via `filled()` (now the POP tint) |
| AC3 | `test_grow_meter::test_grows_food_icon_is_drawn_in_gain_in_night_and_day` |
| AC4 | `test_counters::test_each_top_bar_tooltip_names_its_resource_and_what_it_is_for` |

## Manual check
- [ ] Top bar: glyphs look about as tall as the figures, in Night and Day.
- [ ] Territory view: the pop figures line up with the stats line; filled vs empty is easy to tell; Grow's sprout is
  green; growing pops the new figure in.
- [ ] Hover each top-bar counter: the tooltip opens by naming the resource.

## Log
