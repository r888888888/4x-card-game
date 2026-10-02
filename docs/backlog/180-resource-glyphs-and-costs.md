---
id: 180
title: Resource glyphs in the top bar and glyph costs on cards
type: feature
status: ready
branch: feat/180-resource-glyphs-and-costs
---

## Goal
Resources are named by their glyphs, not words ([docs/design/mcm-style-guide.md](../design/mcm-style-guide.md) §4.5,
§6.7, §8): the top bar shows a sprout, a coin, a book, a bolt, a star and a figure beside plain figures, and a hand
card shows its cost at the top right as one glyph + figure per resource, with any resource the player is short of in
the warning colour. The shapes tell food from wealth without relying on colour, and the cost is where the eye looks
first.

## Acceptance criteria
- [ ] AC1: `GameEngine.play_shortfall(uid)` lists the resources of hand card uid's play cost (after discounts, as
  `play_cost`) that the player has less of than that cost, in the cost's order. Given 1 food and 5 wealth and a
  Guildhall (2 food, 2 wealth) in hand, it is `["food"]`; given 0 food and 0 wealth, `["food", "wealth"]`; given 2 food
  and 2 wealth, `[]`; for a uid not in the hand, `[]`.
- [ ] AC2: The top bar's food, wealth, insight, unrest, score and pop counters each show their glyph left of the figure
  (`assets/icons/` food sprout, wealth cash coin, insight open book, unrest solid bolt, score starburst, pop figure),
  tinted `GAIN`, `WEALTH`, `INSIGHT`, `UNREST`, `TEXT` and `POP`; the figure is `TEXT` (or `WARN` as today when food
  would starve or unrest is at its limit). A counter's glyph hides with its counter (unrest off, population off).
- [ ] AC3: The counters drop their words: given 3 food with +1 forecast, `counter_text(GameEngine.FOOD)` is "3 (+1)";
  unrest 2 of 5 with +1 forecast is "2 / 5 (+1)"; score 4 is "4"; pop 2 is "2". The turn counter stays "Turn 1 / 100".
- [ ] AC4: A hand card's cost sits on its name's line, at the right: one entry per resource with a cost above 0, in the
  order food, wealth, insight (any other resource after them as "N name"), each a 20 px glyph then its figure, 3 px
  apart, entries 12 px apart, no box. Given a Guildhall in hand, the entries are a food glyph with "2" then a wealth
  glyph with "2"; a Scout (no cost) shows no entries and no "Free". The type line no longer holds the cost.
- [ ] AC5: Each figure of a resource in `play_shortfall` is `WARN`, the rest `TEXT`: given 1 food, 5 wealth and a
  Guildhall in hand, the food "2" is `WARN` and the wealth "2" is `TEXT`; when food rises to 2, after the refresh both
  are `TEXT`.
- [ ] AC6: The Grow pip's food icon (124) is the new sprout, so food has one glyph everywhere.

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

## Manual check
- [ ] Seed 5, Egypt: the six glyphs read at a glance in the top bar; Lumber Camp shows sprout 1, coin 2 at its top
  right; a card you can't afford shows the missing resource's figure in red.

## Log
- 2026-10-01: Specced from the mid-century style guide and the `spike/mcm-godot` spike. Assumption: the forecast stays
  inline as "(+1)" (decided 2026-10-01; the guide's two-line cells can come later).
