---
id: 275
title: Iron Age reach techs (Alphabet, Qanat, Navigation)
type: feature
status: review
branch: feat/275-alphabet-qanat-navigation
---

## Goal
Add three Iron Age techs that pushed ancient societies outward. Alphabet: the Phoenician script cut hundreds of
signs to 22, so reading was no longer a scribes-only skill and every source of learning goes further. Qanat: Persian
underground channels carried groundwater under dry land, so the desert and the hills could feed people without a
river. Navigation: steering by the stars, Phoenician ships crossed open sea to Carthage and Gades, so every harbour
gained a network to trade with. Content only: no engine change. Follows 274.

## Acceptance criteria
- [x] AC1 (invariant): Some tech in `research_deck` or reachable building sets `modifiers.insight_per_gain` above 0.
  Fails today: only Theocracy sets it, to −1.
- [x] AC2 (invariant): For each of `desert` and `hills`, some reachable building with an `upkeep` food gain can be
  built on a territory in the territory deck that has that terrain and no `fresh_water`. Fails today for both: Farm
  and Irrigation Canals need fresh water, Mine and Caravanserai make no food.
- [x] AC3 (invariant): Every tag counted by a `gain_per_tag` on a reachable card or a tech in `research_deck` is carried
  by at least 2 reachable cards. Holds today; guards Navigation's new `port` tag.
- [x] AC4: The existing content invariants stay green, in particular `test_every_card_a_tech_gives_is_a_locked_pile_it_unlocks`,
  `test_every_gain_per_tag_tag_is_on_a_reachable_card`, `test_every_eureka_counts_cards_the_player_can_get`,
  `test_only_food_buildings_cost_food_and_at_most_1` and `test_real_data_loads_without_warnings`.

## Out of scope
- Cavalry and the Chariot (167).
- Classical-era techs (concrete, the water mill, crucible steel): a future era 4.
- Balance tuning; the sim isn't run here.

## Design notes
Data only. Each tech goes into `research_deck` with a `flavor` and a real, attributed `quote`. New locked piles are
`{"price": 3, "count": 6, "locked": true}`.

| Tech | Era | Prereq | Cost | VP | Eureka (off 6) | Does |
|---|---|---|---|---|---|---|
| Alphabet (`alphabet`) | 3 | Writing | 27 insight | 0 | 2 Libraries | each insight gain +1 (`modifiers.insight_per_gain` 1) |
| Qanat (`qanat`) | 3 | Mining | 27 insight | 0 | 1 Caravanserai | creates and unlocks the Qanat building |
| Navigation (`navigation`) | 3 | Sailing | 32 insight | 1 | 1 Harbor | ⟳ +1 wealth per `port` card (`gain_per_tag`) |

| Building | Needs | Cost | VP | Tags | Does |
|---|---|---|---|---|---|
| Qanat (`qanat_channel`, name "Qanat") | desert or hills | 1 food + 4 wealth | 0 | `farm` | `housing` 2; ⟳ +1 food |

- New tag `port` on Harbor and Great Harbor of Tyre (both coastal).
- The building's id differs from the tech's, since card ids are unique across types. If the shared name "Qanat" reads
  badly on the Knowledge screen, call the building "Qanat Channel".
- Alphabet and Theocracy's −1 cancel out. Alphabet fits Phoenicia, but no civilization gets it for free.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_content::test_some_tech_or_building_raises_insight_per_gain` |
| AC2 | `test_content::test_dry_desert_and_hills_each_take_a_food_building` |
| AC3 | `test_content::test_every_gain_per_tag_tag_is_on_2_reachable_cards` (passes today: a guard) |
| AC4 | existing `test_content` invariants (unchanged) |

## Manual check
- [ ] Review the tables' numbers and names in `data/cards.json` and `data/config.json`.
- [ ] Learn Alphabet: the Capital's ⟳ +1 insight now gives 2, and a Library gives 3.
- [ ] Build a Qanat on Dunes: housing goes from 2 to 4 and the forecast shows ⟳ +1 food.
- [ ] With 2 Harbors, learn Navigation: the forecast shows ⟳ +2 wealth more (each Fishing Huts adds 1 more).
- [ ] The tech Qanat and the building Qanat read well side by side on the Knowledge screen (else rename the building "Qanat Channel").

## Log
- Balance worries for a later balance item: Alphabet's +1 per gain multiplies with every insight source (Stone Circle,
  Library, Research cards) and may run era 3 out early. With Qanat and Mud-Brick Houses, Dunes may become a good
  territory.

- Built as specced, plus `port` on Fishing Huts (user's choice): 273's `test_every_tech_gain_per_tag_counts_a_tag_on_3_buildings`
  needs 3 buildings with a tech's counted tag, and Harbor and Great Harbor of Tyre were only 2. Balance worry: Navigation
  now pays for cheap Fishing Huts too, marsh ones included. Quotes: John 1:1 (Alphabet), Isaiah 35:6 (Qanat), Psalm
  107:23 (Navigation), all KJV. Suite 1825 → 1828 tests.
