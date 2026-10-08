---
id: 305
title: Rural upgrades (plough, irrigation, harbour, timber, shafts) and building realism fixes
type: feature
status: done
branch: feat/305-rural-upgrades
---

## Goal
With upgrades in the engine (300), restructure the countryside so improvements build on what's already there, as they
did historically: ploughs and irrigation went onto existing farmland, ports grew out of fishing villages, bronze axes
opened forests to logging, iron let mines go deeper. These **rural** upgrades need a tech and no tier, so they help
every strategy alike; the tall payoff comes from the urban items (306, 307). The same pass fixes the building roster's
anachronisms. Content only. Follows 300 (and 295).

## Acceptance criteria
Content tests (`tests/test_content.gd`) assert invariants of the real data, naming no card id:
- [x] AC1: Every building with `upgrade_of` is a `build_menu` entry, and so is its base; every locked upgrade entry is
  unlocked by some tech's `unlock`.
- [x] AC2: Every upgrade can stand somewhere: some territory card in the territory deck (or a civilization's home)
  meets both its base's `requires` and its own (each any-of; an empty list meets anything).
- [x] AC3: No upgrade is unlocked in an earlier era than its base: the era of the tech that unlocks an upgrade is at
  least the era of the tech that unlocks its base (an entry open from turn 1 counts as era 1).
- [x] AC4: 295's invariants still hold (no building in `deck` or `supply`; every locked entry has an unlocking tech),
  and 263's `test_every_building_gives_something_lasting` covers upgrades too (each gives VP, an upkeep effect or a
  standing field). New: every terrain in config `terrains` has a non-upgrade building that can stand on it, so no
  terrain lost its only building to a restructure.

## Out of scope
- Urban (tier-gated) upgrades: 306, 307. New gap buildings: 308.
- Tuning: the numbers below are a first pass, measured and tuned by the balance item after 308.

## Design notes
- Changes in `data/cards.json` and `data/config.json` (each "now" is a first-pass number):
  - **Ploughed Fields** becomes an upgrade of Farm (The Plough): drops its own `requires` (the Farm's territory
    decides) and its effect becomes ⟳ +1 food (Farm +2 and Ploughed Fields +1 is today's Ploughed Fields' +3). Pasture
    stays a building of its own.
  - **Irrigation Canals** becomes an upgrade of Farm (Irrigation): keeps housing 1, ⟳ +1 food, +1 more on desert; no
    longer a stand-alone entry. A Farm can carry both (no limit; the user chose to start without one).
  - **Harbor** becomes an upgrade of Fishing Huts (Sailing): keeps `requires: ["coastal"]` (marsh Huts can't take it)
    and adds ⟳ +2 wealth (Huts' +1 food plus Harbor's +2 wealth is today's Harbor).
  - **Timber Camp** (new): upgrade of Hunters' Camp (Bronze Working), ⟳ +1 wealth. Forest has no wealth building today.
  - **Shaft Mine** (new): upgrade of Mine (Iron Working, which unlocks nothing today), ⟳ +1 wealth, +1 more on gold.
  - **Caravanserai** is renamed **Caravan Station** (id unchanged, so saves and eurekas hold) and unlocked by Animal
    Husbandry instead of The Wheel: desert caravans ran on donkeys, then camels, not wheels; the caravanserai itself is
    a much later Persian building. The Caravan action card keeps The Wheel. The Qanat tech's eureka still counts it.
  - **Granary** opens on turn 1 (an unlocked entry): granaries came before pottery (Dhra', c. 9,000 BC). Pottery keeps
    Courtyard Houses.
- Techs: each tech whose `unlock` now names an upgrade reads "X can now be built on a Y." (300). Eurekas that count
  Harbors (Navigation, Astronomy) or Ploughed Fields still work: an upgrade is a tableau card with its own id.
- The sim bot (`GenericBot`, 314) builds upgrades through `legal_actions` and values them by what they make; no bot change (303 is wontfix).

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_content::test_every_upgrade_and_its_base_are_build_menu_entries_opened_by_a_tech` |
| AC2 | `test_content::test_every_upgrade_can_stand_on_some_territory` |
| AC3 | `test_content::test_no_upgrade_opens_before_its_base` |
| AC4 | `test_content::test_every_terrain_keeps_a_building_that_is_not_an_upgrade` (new); existing `test_buildings_are_in_the_build_menu_not_the_deck_or_supply`, `test_every_locked_build_menu_entry_is_unlocked_by_a_tech_and_back`, `test_every_building_gives_something_lasting` (they already cover every building, upgrades included) |

## Manual check
- [ ] Ploughed Fields: upgrade of Farm, The Plough, cost 1 food + 3 wealth, ⟳ +1 food, no `requires`.
- [ ] Irrigation Canals: upgrade of Farm, Irrigation, cost 1 food + 2 wealth, housing 1, ⟳ +1 food, +1 more on desert.
- [ ] Harbor: upgrade of Fishing Huts, Sailing, requires coastal, cost 3 wealth, ⟳ +2 wealth.
- [ ] Timber Camp: upgrade of Hunters' Camp, Bronze Working, cost 3 wealth, ⟳ +1 wealth.
- [ ] Shaft Mine: upgrade of Mine, Iron Working, cost 5 wealth, ⟳ +1 wealth, +1 more on gold.
- [ ] Caravan Station (was Caravanserai) unlocked by Animal Husbandry; The Wheel unlocks the Caravan card only.
- [ ] Granary is buildable on turn 1; Pottery's text lists only Courtyard Houses.
- [ ] In a game: a Farm on a desert flood plain with both upgrades makes 2 + 1 + 1 + 1 + 1 food from one slot.

## Log
- 2026-10-05: specced from the realism pass of the tall-buildings design. Farm takes both upgrades with no limit.
- 2026-10-06: built (data only). Irrigation Canals also drops its own `requires: ["fresh_water"]` (the Farm already
  needs it), as Ploughed Fields drops grassland; both keep the `farm` tag, so farm-tag eurekas still count them. The
  terrain test (AC4) passed before the change: it guards the restructure. Follow-up: an upgrade's text reads "Builds on
  a Fishing Huts." (`Population.with_article` doesn't know plural names).
