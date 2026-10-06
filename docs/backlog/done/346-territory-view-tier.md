---
id: 346
title: The territory view shows the settlement tier
type: feature
status: done
branch: feat/346-territory-view-tier
---

## Goal
A territory's settlement tier (281: Hamlet, Village, Town, Metropolis) decides its extra slots and which buildings
it can take (301), but the territory view never says which tier it is at; only the Realm card's tooltip does. After
this the view shows the tier and the pop the next one needs, next to the pop meter, so the player can see what
growing will unlock.

## Acceptance criteria
- [x] AC1: Given tiers Hamlet 0, Village 4, Town 8, Metropolis 13 and a settled territory at pop 5, then
  `tier_line(uid)` is "Village: a Town at 8 pop".
- [x] AC2: Given that territory at pop 13 (the top tier), then `tier_line(uid)` is "Metropolis".
- [x] AC3: Given tiers off (no `population.tiers`), population off, or a uid that is not a settled territory, then
  `tier_line(uid)` is "".
- [x] AC4: Given the territory view open on that territory at pop 5, then it shows "Village: a Town at 8 pop" beside
  the pop meter; when its pop grows to 8 the shown line becomes "Town: a Metropolis at 13 pop" without reopening.
- [x] AC5: Given tiers off, then the view shows no tier line.
- [x] AC6: The Realm card's tooltip still names the tier as before (it now reads `tier_line`).

## Out of scope
- The Realm's territory cards stay as they are (tier only in the tooltip).
- No change to tiers' rules.

## Design notes
- New engine API: `tier_line(uid) -> String` on `territory_queries.gd`, the public form of
  `Territories._tier_line` (which the tooltip uses now), returning "" with no tier.
- UI: a `Caption`-like dim line in the view's stats bar after the pop meter; hook `tier_text()` on `TerritoryView`.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_tiers::test_the_tier_line_names_the_tier_and_the_next_one` |
| AC2 | `test_tiers::test_the_tier_line_at_the_top_tier_is_its_name` |
| AC3 | `test_tiers::test_no_tier_line_without_tiers_or_population_or_for_other_cards` |
| AC4 | `test_territory_view::test_the_view_shows_the_tier_and_follows_pop` |
| AC5 | `test_territory_view::test_without_tiers_the_view_shows_no_tier` |
| AC6 | `test_tiers::test_the_territory_tooltip_has_a_tier_line` (existing, unchanged) |

## Manual check
- [ ] `godot --path . -- --civ egypt --seed 5`: click your home territory. Beside the pop pips it reads e.g.
  "Hamlet: a Village at 4 pop" in the dim caption style; grow it (or end turns) and the line follows pop.

## Log
- `Territories._tier_line` moved to `Population.tier_line` (public `tier_line(uid)`); the tooltip calls it.
