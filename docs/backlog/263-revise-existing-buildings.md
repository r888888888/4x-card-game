---
id: 263
title: Revise existing buildings (Quarry out, Hunters' Camp, Harbor, Temple, Mine)
type: feature
status: review
branch: feat/263-revise-existing-buildings
---

## Goal
Tighten the current building slate before new buildings arrive (264, 265). Quarry goes: it held a slot and a worker
for a one-time point and was strictly weaker than Shrine. Lumber Camp becomes Hunters' Camp and can be bought, so a
second forest has a building. Harbor becomes a trade building instead of a bigger Fishing Huts. Temple stops being a
VP engine and is kept for calming unrest. Mine rewards the gold, tin and copper that hills and mountains roll.
Content only: no engine change.

## Acceptance criteria
- [x] AC1 (invariant): Every building in the starting `deck` also has a supply pile (open or locked). Fails today:
  Lumber Camp has none.
- [x] AC2 (invariant): Every real building gives something that lasts: printed VP ≥ 1, an `upkeep` effect, or a
  standing field (`modifiers`, `housing`, `famine_guard`, `defense`, `training`). An effect that only scores on play
  doesn't count. Fails today: Quarry.
- [x] AC3 (invariant): Every resource keyword in config `resource_keywords` is the `keyword` of an `upkeep` wealth
  gain on some reachable building. Fails today for tin and copper.
- [x] AC4: The existing content invariants stay green, in particular
  `test_every_eureka_counts_cards_the_player_can_get` and `test_real_data_loads_without_warnings`: no card, eureka
  or config entry names `quarry` or `lumber_camp` afterwards.

## Out of scope
- New buildings (264) and wonders (265).
- Shrine removing unrest each turn (separate TODO line).
- Balance tuning beyond the numbers below; the sim isn't run here.

## Design notes
Data changes only (`data/cards.json`, `data/config.json`), plus PLAN.md lines that name these cards:
- **Quarry**: removed from cards and `supply`. Eurekas that counted it change:
  Mining → `{"tag": "wall", "count": 1}` (a Palisade), Masonry → `{"card": "mine", "count": 2}`,
  Engineering → `{"card": "monument", "count": 1}`. Each keeps its `off`.
- **Lumber Camp → Hunters' Camp**: id `hunters_camp`, name "Hunters' Camp" (the request said "Hunters Camp"; the apostrophe
  is an assumption). Same cost and effects (forest; 1 food + 2 wealth;
  ⟳ +1 food; +1 VP on play). The starting deck keeps 1; new open supply pile `{"price": 2, "count": 6}`.
- **Harbor**: ⟳ +1 food and ⟳ +2 wealth (was ⟳ +2 food). Cost unchanged (1 food + 3 wealth, coastal, via Sailing).
- **Temple**: drops the base ⟳ +1 VP; keeps 1 printed VP, ⟳ −1 unrest and ⟳ +1 VP on a mountain.
- **Mine**: ⟳ +1 wealth, plus ⟳ +1 wealth each for gold, tin and copper (three `keyword` effects, like Forge). A
  tin-and-copper mountain Mine makes +3.
- Lands before 264 and 265, which edit the same techs. 262 also edits `cards.json`; expect a merge on `main`.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_content::test_every_starting_deck_building_has_a_supply_pile` |
| AC2 | `test_content::test_every_building_gives_something_lasting` |
| AC3 | `test_content::test_every_resource_keyword_raises_a_buildings_upkeep_wealth` |
| AC4 | existing: `test_content::test_every_eureka_counts_cards_the_player_can_get`, `test_real_data_loads` |

## Manual check
- [ ] Review the shipped numbers above in `data/cards.json`: Hunters' Camp pile, Harbor yields, Temple, Mine.
- [ ] Start a game as Phoenicia (Cedar Coast home): the starting Hunters' Camp shows its new name, and the supply
  sells Hunters' Camp from turn 1 with no Quarry pile.
- [ ] The Knowledge screen shows Mining's eureka as a Palisade, Masonry's as 2 Mines, Engineering's as a Monument.

## Log
- Balance worries for a later balance item: Temple without ⟳ +1 VP may now lose to Shrine; Mine on a tin-and-copper
  mountain (+3 wealth) may be the best wealth building in era 1.
- Green: data only (`data/cards.json`, `data/config.json`); no code referenced Quarry or Lumber Camp. Suite 1722 → 1725.
