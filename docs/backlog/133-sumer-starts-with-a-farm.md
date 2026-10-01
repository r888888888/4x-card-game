---
id: 133
title: A civilization can start with a building on its home (Sumer starts with a Farm)
type: feature
status: in-progress
branch: feat/133-sumer-starts-with-a-farm
---

## Goal
Sumer's food comes only from Farms (+1 food per Farm), so a game where its opening hand has no Farm makes no food at
all (about 29% of openings with 3 Farms in 16 cards). After this item a civilization can start with a building already
on its home territory, and Sumer starts with its first Farm ("its first canal"), so its start no longer depends on the
draw.

## Acceptance criteria
- [ ] AC1: Given a civilization with the start effect `{ "op": "create", "card": "farm", "zone": "tableau", "trigger":
  "start" }` and a home, when a new game starts as it, then the tableau holds one Farm whose territory is the home (the
  Capital's territory), and the home has 1 free slot fewer than in a game as a civilization without it.
- [ ] AC2: Given that game, when its first turn starts, then the Farm is not idle (the home's starting pop works it)
  and the upkeep forecast's food includes the Farm's upkeep food.
- [ ] AC3: Given a civilization whose start `create` puts a non-building (e.g. a Scout) into the tableau, when the cards
  load, then there's an error naming the card, the effect and the created card id.
- [ ] AC4: Given a listed civilization whose start building `requires` a keyword its home (or `starting.territory`, when
  it has no home) lacks, when the config loads, then there's an error naming the civilization, the building and the
  territory.
- [ ] AC5: Given a listed civilization that starts with more buildings than its home has slots (the territory's slots
  plus the starting tableau's), when the config loads, then there's an error naming the civilization and its home.

## Out of scope
- `create` into the tableau on play (not start): unchanged.
- Other civilizations' starting buildings, and any balance tuning beyond giving Sumer one Farm.

## Design notes
- No new field or op: a civilization's start `create` with `zone: "tableau"` places the building on the home, the
  territory the starting tableau (Capital) sits on. Start effects resolve after the starting tableau is placed (111).
- Loader: start `create` into the tableau must name a building (AC3). Config loader: next to
  `_check_homes_house_start`, check each listed civilization's start buildings against its home's keywords and slots
  (AC4, AC5).
- Content: Sumer gets `{ "op": "create", "card": "farm", "zone": "tableau", "trigger": "start" }`; it keeps its
  Research start gift.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_civ_start_building::test_start_create_puts_the_building_on_the_home` |
| AC2 | `test_civ_start_building::test_start_building_works_from_the_first_turn` |
| AC3 | `test_civ_start_building::test_start_create_into_the_tableau_must_name_a_building` |
| AC4 | `test_civ_start_building::test_start_building_must_fit_the_home_keywords` |
| AC5 | `test_civ_start_building::test_start_buildings_must_fit_the_home_slots` |

## Manual check
- [ ] New game as Sumer: Delta Marsh shows a Farm next to the Capital on turn 1, working (not idle), and the food
  forecast counts it.
- [ ] Sumer's card text reads sensibly for the start Farm (e.g. "Start: Create a Farm").
- [ ] Other civilizations start with no building.

## Log
- From the Sumer balance brainstorm after 132 (idea 5). Branched from `main`; 132 (Farm +2 food, Sumer's Farm discount)
  is a separate branch, so the two touch Sumer's card entry and may need a small merge.
- Green: start buildings go on the home (TurnLoop.new_game), the card loader rejects a non-building, and the config
  loader checks keywords and slots. Giving Sumer the Farm breaks the approved content test
  `test_civilization_start_gifts_are_obtainable_cards_in_the_discard` (107: every start `create` goes to the discard).
  Held back the Sumer data change and asked the user whether 107's rule should allow the tableau for buildings.
