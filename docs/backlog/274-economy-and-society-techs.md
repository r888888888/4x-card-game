---
id: 274
title: Economy and society techs (Fermentation, Olive and Vine, Medicine, Credit)
type: feature
status: ready
branch: feat/274-economy-and-society-techs
---

## Goal
Add four techs that shaped everyday life and trade in the ancient world. Fermentation: beer and wine kept grain
edible and paid workers' wages in Sumer and Egypt. Olive and Vine: long-lived crops shipped in amphorae were the
backbone of Minoan, Greek and Phoenician exports, and they give the hills a second building. Medicine: Egyptian
temple schools (the House of Life) kept medical texts and healed the sick. Credit: Mesopotamian loans at interest
grew wealth and also bred debt slavery, so the tech pays wealth at a cost in unrest, a trade-off no tech offers yet.
Content only: no engine change. Follows 272 and 273.

## Acceptance criteria
- [ ] AC1 (invariant): At least 2 reachable buildings set `famine_guard`. Fails today: only Granary.
- [ ] AC2 (invariant): Some tech in `research_deck` has an `upkeep` gain of wealth or insight and an `upkeep` gain of
  unrest. Fails today: no tech costs unrest.
- [ ] AC3 (invariant): At least 2 reachable non-wonder buildings have `hills` in `requires`. Fails today: only Mine.
- [ ] AC4: The existing content invariants stay green, in particular `test_every_card_a_tech_gives_is_a_locked_pile_it_unlocks`,
  `test_every_building_gives_something_lasting`, `test_every_eureka_counts_cards_the_player_can_get`,
  `test_every_tech_has_flavor_and_a_quote_and_every_event_flavor` and `test_real_data_loads_without_warnings`.

## Out of scope
- Alphabet, Qanat and Navigation (275). The Chariot is left to 167.
- Plague events that Medicine could answer (270's territory).
- Balance tuning; the sim isn't run here.

## Design notes
Data only. Each tech goes into `research_deck` with a `flavor` and a real, attributed `quote`. New locked piles are
`{"price": 3, "count": 6, "locked": true}`. A tech that gives a building creates 1 copy in the discard and unlocks it.

| Tech | Era | Prereq | Cost | VP | Eureka | Gives |
|---|---|---|---|---|---|---|
| Fermentation (`fermentation`) | 1 | Pottery | 6 insight | 0 | 3 `farm` cards (off 2) | Brewery |
| Olive and Vine (`olive_and_vine`) | 2 | Pottery | 16 insight | 0 | 1 `trade` card (off 4) | Olive Groves |
| Medicine (`medicine`) | 2 | Writing | 19 insight | 0 | 1 Bathhouse (off 4) | House of Life |
| Credit (`credit`) | 2 | Writing | 16 insight | 0 | 2 `trade` cards (off 4) | ⟳ +2 wealth, ⟳ +1 unrest |

| Building | Needs | Cost | VP | Tags | Does |
|---|---|---|---|---|---|
| Brewery (`brewery`) | anywhere | 4 wealth | 0 | — | `famine_guard` 1; ⟳ +1 wealth |
| Olive Groves (`olive_groves`) | hills | 4 wealth | 1 | `trade` | ⟳ +1 wealth; ⟳ +1 more wealth on coastal |
| House of Life (`house_of_life`) | anywhere | 5 wealth | 0 | — | `housing` 1; ⟳ +1 insight |

- Credit's unrest is an `upkeep` `gain` of `unrest`, which `upkeep_ok()` allows (it changes only a resource). The
  review called it "Credit and Contracts"; the shorter name fits the tech tile.
- Olive Groves makes no food, so it costs wealth only (`test_only_food_buildings_cost_food_and_at_most_1`).

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_content::test_…` |

## Manual check
- [ ] Review the tables' numbers and names in `data/cards.json` and `data/config.json`.
- [ ] Learn Credit: the upkeep forecast shows +2 wealth and +1 unrest every turn after.
- [ ] Build Olive Groves on Coastal Hills (Greece's home): ⟳ +2 wealth.
- [ ] Card text reads well for Brewery (famine guard plus wealth), House of Life, and Credit's two upkeep lines.

## Log
- Balance worries for a later balance item: Credit's unrest has no off switch, so it may be a trap or a must-pick
  depending on the unrest limit. Brewery may outclass Granary. House of Life stacks insight with Library.
