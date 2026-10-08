---
id: 414
title: Irrigation Canals and Salt Pans boost the farms and huts on their own territory
type: feature
status: red-review
branch: feat/414-farms-here
---

## Goal
406 made Irrigation Canals and Salt Pans stand-alone buildings with flat food. They should reward specialising a
territory: Irrigation Canals waters every farm beside it, and Salt Pans works the shore beside every Fishing Huts. A
territory of farms becomes a breadbasket because its buildings feed each other, not only because each makes food.

Follow-up to 406.

## Acceptance criteria
Fixtures: `TEST_CARDS` Farm (tag `farm`, ⟳ +1 food), Canal (a building tagged `farm`, ⟳ +1 food per other farm here:
`{"op": "gain_per_tag", "resource": "food", "amount": 1, "tag": "farm", "where": "here", "trigger": "upkeep"}`, no
other effect) and Fat Plough (an upgrade of Farm tagged `farm`). Population on, no food upkeep.

- [ ] AC1 (counts its own territory): Given Homeland with 3 pop holding a Farm, a Farm and a Canal, all working, and
  Grassland holding a working Farm, when upkeep runs, then the Canal makes 2 food (the two other farms on Homeland: not
  itself, not Grassland's Farm), and food rises by 2 + 3 (the three Farms) + the Capital's.
- [ ] AC2 (only working base buildings count): Given Homeland with 2 pop holding a Canal, a Farm and a second Farm
  that is idle (no worker), and a Fat Plough on the working Farm, when upkeep runs, then the Canal makes 1 food: an
  idle building and an upgrade don't count. With the Canal itself idle, it makes nothing.
- [ ] AC3 (the forecast): In AC1's setup, `upkeep_breakdown("food")` has a Canal row of +2 before upkeep, and
  `upkeep_forecast()` matches what upkeep then does.
- [ ] AC4 (the loader): `where` on `gain_per_tag` is optional and, when given, must be `"here"`; any other value is a
  load error naming the card and the field. `"where": "here"` with a `zone` other than the tableau, or on a card that
  isn't a building, is a load error.
- [ ] AC5 (card text): The Canal's effect reads "+1 food per other farm here" on its face and "+1 food per other farm
  card on its territory" in its details. A `gain_per_tag` without `where` reads as today.
- [ ] AC6 (real data): Every `gain_per_tag` with `"where": "here"` counts a tag that some other base building carries,
  and some territory a game can hold meets both buildings' `requires`.

## Out of scope
- Other buildings using `here` (a Mine counting mines, a Market counting trade). Later content items can.
- Balance tuning beyond the numbers below; a sim run belongs to the user (Manual check).

## Design notes
- Effect: `gain_per_tag` gets an optional `where` (only `"here"`). With it, it counts the working base buildings (not
  upgrades, not idle, fallen-back or unfinished ones; `Modifiers.working_cards`) on the source's territory that carry
  the tag, other than the source itself. `per` still divides the count. `reads_zones` stays the tableau.
- Text: face "+%d %s per other %s here", details "+%d %s per other %s card on its territory".
- Data (`data/cards.json`), agreed 2026-10-08:
  - Irrigation Canals: ⟳ +2 food (+1 on desert), +1 food per other farm here; housing 1; keeps the `farm` tag (so a
    Canal beside a Canal counts it). Farm + Canals on River Meadow: 4 + 3 = 7 food; alone on an Oasis: 3 (+1 desert).
  - Salt Pans: ⟳ +1 food, +1 wealth (it still pays its upkeep), +1 food per Fishing Huts here.
  - Fishing Huts gain a new `fishing` tag (keeping `port`), and Salt Pans counts `fishing`, so a Shipyard or Harbor
    never feeds it.
- GenericBot sees it with no change: the bonus is an upkeep gain, so `turn_forecast` counts it.
- PLAN.md: the effect op list (gain_per_tag's `where`) and 406's food line.

## Test plan
In `tests/test_gain_per_tag.gd` unless named.

| AC | Test |
|---|---|
| AC1 | `test_here_counts_the_other_farms_on_its_own_territory` |
| AC2 | `test_here_counts_only_working_base_buildings`, `test_an_idle_here_card_makes_nothing` |
| AC3 | `test_the_forecast_counts_the_farms_here` |
| AC4 | `test_where_here_is_a_building_count_on_the_tableau` |
| AC5 | `test_here_text_names_the_other_farms_here` |
| AC6 | `test_content::test_every_here_count_has_a_building_to_count_beside_it` |

## Manual check
- [ ] Irrigation Canals in `data/cards.json`: ⟳ +2 food, +1 on desert, +1 per other farm here, housing 1, tag `farm`.
- [ ] Salt Pans: ⟳ +1 food, +1 wealth, +1 food per other fishing building here. Fishing Huts carries `port` and
  `fishing`.
- [ ] New game with a fresh-water home: build a Farm, then Irrigation Canals beside it. The food forecast rises by 3 for
  the Canals (2 + 1 for the Farm), and its card reads "+1 food per other farm here".
- [ ] Balance (the user runs it): `scripts/sim.sh --level 3 --compare <main checkout>`. Sumer (which also gains per
  farm) and coastal civilizations' food.

## Log
- 2026-10-08: specced from the user's request after 406 shipped the two as flat-food buildings. Assumed, not asked:
  the count excludes the source itself and counts only working base buildings (an upgrade like Ploughed Fields carries
  `farm` but isn't a farm of its own).
- 2026-10-08: red tests written. `test_an_idle_here_card_makes_nothing` passes already (an idle card never resolves
  its upkeep). `upgrade_on` moved from `test_building_upkeep.gd` to `tests/lib/test_case.gd`, since these tests use it
  too. A here count on a tech is refused by the existing own-territory check (`needs_own_territory`); one on an action
  (or a city or civilization) gets a new error.
