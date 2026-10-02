---
id: 180
title: Resource glyphs in the top bar and glyph costs on cards
type: feature
status: review
branch: feat/180-resource-glyphs-and-costs
---

## Goal
Resources are named by their glyphs, not words ([docs/design/mcm-style-guide.md](../design/mcm-style-guide.md) §4.5,
§6.7, §8): the top bar shows a sprout, a coin, a book, a bolt, a star and a figure beside plain figures, and a hand
card shows its cost at the top right as one glyph + figure per resource, with any resource the player is short of in
the warning colour. The shapes tell food from wealth without relying on colour, and the cost is where the eye looks
first.

## Acceptance criteria
- [x] AC1: `GameEngine.play_shortfall(uid)` lists the resources of hand card uid's play cost (after discounts, as
  `play_cost`) that the player has less of than that cost, in the cost's order. Given 1 food and 5 wealth and a
  Guildhall (2 food, 2 wealth) in hand, it is `["food"]`; given 0 food and 0 wealth, `["food", "wealth"]`; given 2 food
  and 2 wealth, `[]`; for a uid not in the hand, `[]`.
- [x] AC2: The top bar's food, wealth, insight, unrest, score and pop counters each show their glyph left of the figure
  (`assets/icons/` food sprout, wealth cash coin, insight open book, unrest solid bolt, score starburst, pop figure),
  tinted `GAIN`, `WEALTH`, `INSIGHT`, `UNREST`, `TEXT` and `POP`; the figure is `TEXT` (or `WARN` as today when food
  would starve or unrest is at its limit). A counter's glyph hides with its counter (unrest off, population off).
- [x] AC3: The counters drop their words: given 3 food with +1 forecast, `counter_text(GameEngine.FOOD)` is "3 (+1)";
  unrest 2 of 5 with +1 forecast is "2 / 5 (+1)"; score 4 is "4"; pop 2 is "2". The turn counter stays "Turn 1 / 100".
- [x] AC4: A hand card's cost sits on its name's line, at the right: one entry per resource with a cost above 0, in the
  order food, wealth, insight (any other resource after them as "N name"), each a 20 px glyph then its figure, 3 px
  apart, entries 12 px apart, no box. Given a Guildhall in hand, the entries are a food glyph with "2" then a wealth
  glyph with "2"; a Scout (no cost) shows no entries and no "Free". The type line no longer holds the cost.
- [x] AC5: Each figure of a resource in `play_shortfall` is `WARN`, the rest `TEXT`: given 1 food, 5 wealth and a
  Guildhall in hand, the food "2" is `WARN` and the wealth "2" is `TEXT`; when food rises to 2, after the refresh both
  are `TEXT`.
- [x] AC6: The Grow pip's food icon (124) is the new sprout, so food has one glyph everywhere.

## Out of scope
- The card details modal, the Relieve famine / Restore order buttons and supply prices keep their text costs
  (`CardFace.cost_text` stays for them).
- Rolling figures and +N tags (181).

## Design notes
- New engine query `play_shortfall(uid) -> Array[String]`; the UI never compares resources with costs itself
  (CLAUDE.md). `price_error` already knows which resources fall short; share the comparison.
- Glyphs: white SVGs on the guide's 24 grid (stroke 2, square caps, mitred joins), tinted at run time as `Icons` does;
  paths in [docs/design/icon-options.html](../design/icon-options.html) (sprout, cash coin, curved-page book, solid bolt
  drawn 20% smaller). `assets/icons/food.svg` is replaced by the sprout.
- `TopBar` gives each counter its glyph in the label's left margin (a `TextureRect` child), as the spike did, so the
  glyph shows and hides with the label.
- Builds on 177 (`counter_text`) and 178 (palette).

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_ui_queries::test_play_shortfall_lists_the_resources_the_player_is_short_of_in_cost_order`, `test_play_shortfall_is_empty_for_a_card_not_in_the_hand` |
| AC2 | `test_resource_glyphs::test_each_counter_shows_its_glyph_in_its_hue_left_of_an_ink_figure`, `test_the_food_figure_warns_when_pop_would_starve`, `test_a_hidden_counter_hides_its_glyph`; `test_unrest::test_the_top_bar_shows_unrest_out_of_the_limit_and_floats_its_change` (figure now `TEXT` below the limit) |
| AC3 | `test_resource_glyphs::test_the_counters_read_figures_only`; changed: `test_counters::test_the_food_counter_text_is_the_reading_the_bar_shows`, `test_unrest` (both top-bar tests), `test_insight::test_the_top_bar_shows_insight_with_its_forecast_and_floats_its_change`, `test_grow_meter::test_pressing_grow_fills_the_pip_and_moves_grow_to_the_next` |
| AC4 | `test_resource_glyphs::test_a_hand_cards_cost_is_glyphs_and_figures_on_its_name_line`, `test_a_free_card_shows_no_cost`, `test_cost_entries_go_food_wealth_insight_then_others_by_name` |
| AC5 | `test_resource_glyphs::test_a_figure_the_player_is_short_of_is_red_until_they_have_it` |
| AC6 | `test_resource_glyphs::test_the_grow_pip_uses_the_top_bars_food_glyph` |

## Manual check
- [ ] Seed 5, Egypt: the six glyphs read at a glance in the top bar; Lumber Camp shows sprout 1, coin 2 at its top
  right; a card you can't afford shows the missing resource's figure in red.

## Log
- 2026-10-01: Specced from the mid-century style guide and the `spike/mcm-godot` spike. Assumption: the forecast stays
  inline as "(+1)" (decided 2026-10-01; the guide's two-line cells can come later).
- 2026-10-02: Built. Engine: `shortfall(cost)` in `EngineCore` (now behind `can_pay`) and `play_shortfall(uid)`. UI:
  `Icons.RESOURCES`, `Icons.hue` and `Icons.glyph`; the six glyph SVGs from the spike in `assets/icons/` (the sprout
  replaces `food.svg`); `TopBar` counters carry their glyph in the label's left margin; `CardFace.cost_glyphs` and
  `show_shortfall`, refreshed by `BoardViews` through `CardView.set_shortfall`. Two more tests still found the score
  counter by its text ("Score", without the colon, so 177's guard missed them): `test_board_layout` and
  `test_identity_lines` (the latter would have passed vacuously); both now use `main.counter(TopBar.SCORE)`.
  Follow-up idea: widen 177's guard to `begins_with("<Word>")` lookups.
