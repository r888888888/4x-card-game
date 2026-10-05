---
id: 272
title: Era-1 farming and accounting techs (Irrigation, The Plough, Weaving, Clay Tokens)
type: feature
status: ready
branch: feat/272-era-1-farming-and-accounting-techs
---

## Goal
The Stone Age tree skips the advances that made cities possible. Farms come in the starting deck, but nothing after
them grows the food supply: irrigation canals, the ox-drawn plough, or cloth woven from flax and wool, which was the
biggest pre-modern industry after farming. Writing also appears from nothing, when it actually grew out of clay
counting tokens. Add four era-1 techs, make Writing and Sailing build on them, and give Animal Husbandry the eureka
every other tech has. Content only: no engine change. From the tech review (docs/TODO.md line); follows 263–265.

## Acceptance criteria
- [ ] AC1 (invariant): Every tech in `research_deck` above era 1 has a `prereq`. Fails today: Writing and Sailing.
- [ ] AC2 (invariant): Every tech in `research_deck` has a `eureka`. Fails today: Animal Husbandry.
- [ ] AC3 (invariant): At least 3 buildings tagged `farm` are unlocked by era-1 techs in `research_deck`. Fails today:
  only Pasture (Animal Husbandry).
- [ ] AC4: The existing content invariants stay green, in particular `test_every_card_a_tech_gives_is_a_locked_pile_it_unlocks`,
  `test_every_eureka_counts_cards_the_player_can_get`, `test_only_food_buildings_cost_food_and_at_most_1`,
  `test_every_tech_has_flavor_and_a_quote_and_every_event_flavor` and `test_real_data_loads_without_warnings`.

## Out of scope
- Weights and Measures, Coinage and Bureaucracy (273); the tier-2 techs (274, 275).
- Retuning era-1 pacing for 11 techs instead of 7: a balance item.
- Engine rules: a tech with two prereqs, "no fresh water" requirements.

## Design notes
Data only (`data/cards.json`, `data/config.json`). Each new tech goes into `research_deck` (count 1), with a `flavor`
and a real, attributed `quote` (check the wording when implementing). New locked piles are `{"price": 3, "count": 6,
"locked": true}`. Each tech that gives a building creates 1 copy in the discard and unlocks its pile, as Pottery does.

| Tech | Era | Prereq | Cost | VP | Eureka (off 2) | Gives |
|---|---|---|---|---|---|---|
| Irrigation (`irrigation`) | 1 | — | 6 insight | 0 | 2 Farms | Irrigation Canals |
| The Plough (`the_plough`) | 1 | Animal Husbandry | 8 insight | 0 | 2 Pastures | Ploughed Fields |
| Weaving (`weaving`) | 1 | — | 6 insight | 0 | 1 Pasture | Weavers' Workshop |
| Clay Tokens (`clay_tokens`) | 1 | Pottery | 6 insight | 0 | 1 Granary | ⟳ +1 insight |

| Building | Needs | Cost | VP | Tags | Does |
|---|---|---|---|---|---|
| Irrigation Canals (`irrigation_canals`) | fresh water | 1 food + 3 wealth | 0 | `farm` | `housing` 1; ⟳ +1 food; ⟳ +1 more food on desert |
| Ploughed Fields (`ploughed_fields`) | grassland | 1 food + 4 wealth | 0 | `farm` | ⟳ +3 food |
| Weavers' Workshop (`weavers_workshop`) | anywhere | 3 wealth | 0 | `trade` | ⟳ +1 wealth; ⟳ +1 more wealth on grassland (wool) |

Changes to existing techs:
- Writing: `prereq` `clay_tokens` (cuneiform grew out of counting tokens).
- Sailing: `prereq` `weaving` (a sail is woven cloth).
- Animal Husbandry: `eureka` `{"card": "hunters_camp", "count": 1, "off": 2}` (hunters tamed the herds first).

Possible quotes: Irrigation, Herodotus on Egypt as "the gift of the river" (Histories 2.5); The Plough, "He that by the
plough would thrive, himself must either hold or drive" (Benjamin Franklin, Poor Richard's Almanack, from an older
English proverb); Weaving, "She seeketh wool, and flax, and worketh willingly with her hands" (Proverbs 31:13);
Clay Tokens, "God made the integers; all else is the work of man" (Leopold Kronecker).

The bot needs no change: it learns the cheapest tech it can afford and builds buildings generically.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_content::test_…` |

## Manual check
- [ ] Review the tables' numbers and names in `data/cards.json` and `data/config.json`.
- [ ] The Knowledge screen's Stone Age band shows 11 techs. The Plough reads "needs Animal Husbandry" until that is
  learned, and Writing reads "needs Clay Tokens".
- [ ] Learn Irrigation and build Irrigation Canals on an Oasis: housing goes up by 1 and the forecast shows ⟳ +2 food.
- [ ] Card text reads well for Irrigation Canals (housing plus two food lines) and Weavers' Workshop.

## Log
- Balance worries for a later balance item: era 1 grows from 7 to 11 techs (12 after 274), so era 1 lasts longer than
  the ~18 turns 143 tuned for. Clay Tokens' ⟳ +1 insight speeds up the rest of era 1. Ploughed Fields (+3 food) may
  make Pasture pointless once it's unlocked. Sailing now needs Weaving, which slows Phoenicia's Harbor.
