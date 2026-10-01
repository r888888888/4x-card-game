---
id: 139
title: Insight, a third resource that pays for techs
type: feature
status: in-progress
branch: feat/139-insight-resource
---

## Goal
Science gets its own economy. Techs cost Insight instead of wealth, so researching no longer competes with buildings
and the supply for the same pool, and the player builds up an Insight income (the Capital, the Library, Research
cards) like any other. First step of the research redesign tried on `spike/research-insight` (commit c575e41; see
Design notes); research stays reveal-2 until 140.

## Acceptance criteria
- [ ] AC1: Given a tech with cost `{"insight": 2}`, then it loads. Given a tech with cost `{"wealth": 2}`, `{}`,
  `{"insight": 0}` or `{"insight": 2, "wealth": 1}`, then loading fails with
  `cards.json: card '<id>': cost: a tech must cost insight only, at least 1 (like {"insight": 2})`.
- [ ] AC2: Given a game with 2 insight and 20 wealth, and Pottery (2 insight) and Writing (3 insight) revealed, when
  the player buys Pottery, then insight is 0, wealth is still 20 and Pottery is in `researched`.
- [ ] AC3: Given 1 insight and Pottery (2 insight) revealed, then `buy_tech_error` for Pottery is
  `"Pottery needs 2 insight (you have 1)."`, and `buy_tech` returns false and changes nothing.
- [ ] AC4: Given a civilization with discounts `[{"type": "tech", "insight": 1}]`, then `tech_cost` of a revealed
  Writing (3 insight) is 2. `tech_tree()` reports each tech's `cost` in insight (the printed insight for a tech in a
  future era), and a revealed tech's details read `"Costs 2 insight now (printed 3, −1 civilization)"`.
- [ ] AC5: Given a building in the tableau with `⟳ +1 insight`, then `upkeep_forecast()` has `insight: 1`, and the
  top bar shows an Insight counter, `"Insight: 0 (+1)"`, that floats its change like Food and Wealth (126). The top
  bar still fits 1920 px with its longest texts.

## Out of scope
- How techs are bought: still reveal-2 with passes until 140. The Research card still reveals.
- Eurekas (141), diffusion (142), Iron Age content and pacing (143).
- Era thresholds keep using pop and wealth.

## Design notes
- `EngineCore.INSIGHT := "insight"`, a built-in resource beside `FOOD` and `WEALTH`. The tech-cost rule in
  `DataLoader` checks `INSIGHT`; `Research.cost` and `buy_error` use it, and civilization tech discounts take insight.
- Content (real data): config `resources` adds `insight`, starting insight 0; the Capital gets `⟳ +1 insight`; the
  Library's effect becomes `⟳ +2 insight` (instead of creating a Research card); Babylon's discount becomes
  `{"type": "tech", "insight": 1}`; tech costs move from wealth to insight at the spike's prices (era 1: 6–10, era 2:
  15–22). The `research` card's name becomes "Research" (it stays id `research`).
- Fixtures: `tech_case.gd` TECHS cost insight (same numbers), test configs list `insight`, and `tech_engine` starts
  with 20 insight as well as 20 wealth.
- Top bar: the spike made room by moving the era name from the Knowledge button to its tooltip (`"…\nEra: Stone
  Age."`) and narrowing the bar's spacing from 20 to 16. Colour `Palette.INSIGHT`.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_insight::test_a_tech_costing_insight_loads`, `test_a_tech_must_cost_insight_only`; `test_research::test_tech_with_an_insight_cost_loads`, `test_tech_card_validation` (cases now in insight) |
| AC2 | `test_insight::test_buying_a_tech_spends_insight_and_leaves_wealth`; `test_research::test_buying_a_tech_pays_for_it_and_moves_it_to_researched` (now insight) |
| AC3 | `test_insight::test_a_tech_needs_enough_insight`; `test_research::test_cannot_afford_a_tech` (now insight) |
| AC4 | `test_insight::test_a_civilization_tech_discount_takes_insight`, `test_the_tech_tree_reports_costs_in_insight`, `test_a_revealed_techs_details_name_its_insight_price_and_the_civilization_discount`; `test_discounts::test_discount_text`, `test_a_tech_discount_lowers_tech_cost_and_what_buy_tech_charges`; `test_card_details::test_revealed_tech_explains_its_price_now` (now insight) |
| AC5 | `test_insight::test_the_forecast_includes_insight`, `test_the_top_bar_shows_insight_with_its_forecast_and_floats_its_change`; `test_board_layout::test_the_top_bar_fits_with_its_longest_texts` (asserts the Insight counter too) |

## Manual check
- [ ] `godot --path . -- --civ babylon --seed 5`: the top bar shows Insight with its forecast (+1 from the Capital),
  floating up when it changes; nothing overflows at 1920 px.
- [ ] Shipped numbers: Capital +1 insight, Library +2, Babylon −1 insight on techs, tech prices as listed above.

## Log
