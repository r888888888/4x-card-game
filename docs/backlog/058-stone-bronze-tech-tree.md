---
id: 058
title: Stone Age and Bronze Age tech tree; gate cards behind techs
type: feature
status: in-progress
branch: feat/058-stone-bronze-tech-tree
---

## Goal
Rebuild the tech content as a Stone Age (era 1) → Bronze Age (era 2) tree (TODO 7). Most buildings and the Caravan
move out of the starting deck: each comes from a tech, as 1 free copy plus an unlocked supply pile (057). The starting
deck shrinks to the basics. The iron-age and classical techs move to era 3, kept in the data but out of the game for
now. Research rules are unchanged: reveal 2, passes, and prereqs only give a discount. The tree is a view (059).

## Acceptance criteria
<!-- Content invariants; exact names and prices are under Manual check. -->
- [ ] AC1: `research_deck` has at least 6 era-1 and 6 era-2 techs, and an era-1 tech adds era 2 (existing test).
  No tech in `research_deck` has era ≥ 3, and no card anywhere has `add_era` with era ≥ 3.
- [ ] AC2: The era-3 techs (Philosophy, Iron Working, Mathematics, Monarchy, Astronomy, Engineering) are still defined
  in `cards.json`, but not in `research_deck`. The real data loads with no warnings.
- [ ] AC3: For every tech in `research_deck`, each non-wonder card it creates is a locked supply pile that the same
  tech unlocks. Wonders (tag `wonder`) are created only, with no pile.
- [ ] AC4: Caravan, Temple, Mine, Market and Granary join `UNLOCKED`. None of them is in the starting deck, and a
  tech in `research_deck` creates each (existing test, list extended).
- [ ] AC5: The existing content tests stay green: prereqs are in the research deck, techs create no techs, a tech
  unlocks the Library, every keyword is used, the growth cards, and the 20-seed sweep.
  `test_real_deck_has_wealth_costs_and_capital_makes_wealth` changes to "cards that cost wealth are reachable (deck,
  supply or a tech), and the Capital makes wealth", because Temple leaves the starting deck. This is flagged here for
  approval.

## Out of scope
- Rule changes to research (tree view is 059; hard prereqs were rejected).
- Governments (065) and new building effects beyond what's listed.
- Era 3 content and a way to reach it.

## Design notes
Proposed tree (for review at approval; names and prices can change):

| Era | Tech | Prereq | Gives (create 1 + unlock pile) | Other effect |
|---|---|---|---|---|
| 1 Stone | Pottery | — | Granary | |
| 1 Stone | Animal Husbandry | — | Pasture | |
| 1 Stone | Mining (new) | — | Mine | |
| 1 Stone | Mysticism (new) | — | Temple | |
| 1 Stone | The Wheel (new) | — | Caravan | |
| 1 Stone | Masonry | Mining | Monument | |
| 1 Stone | Bronze Working | Mining | Forge | adds era 2 (replaces Philosophy as the gate) |
| 2 Bronze | Writing | — | Library | |
| 2 Bronze | Currency | Bronze Working | Market | |
| 2 Bronze | Sailing | — | Harbor | |
| 2 Bronze | Priesthood (new) | Mysticism | Pyramids (wonder: create only) | |
| 2 Bronze | Code of Laws (new) | Writing | — | ⟳ +1 wealth (a government comes in 065) |
| 2 Bronze | Calendar (new) | Pottery | — | 3 VP |

- Starting deck after: Farm 4, Irrigation 1, Settler 2, Scout 2, Forage 2, Lumber Camp 2, Harvest Festival 2,
  Insight 1 (16 cards, down from 22). Unlocked supply: Scout, Settler, Insight.
- Writing moves to era 2, so the Library (more Insight cards) arrives later. Check the sim for the research pace.
- `era_unlocks` "2" stays.
- 023 (more wealth sinks, draft) overlaps: Temple and Monument copies now come from supply piles. Propose closing 023
  as `wontfix` (superseded) once this ships.
- Run the `balance` skill and record the numbers in the Log.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_content::test_research_deck_has_6_techs_in_each_of_eras_1_and_2` (existing), `test_no_era_3_tech_is_researchable_or_added` (passes today: guard) |
| AC2 | `test_content::test_era_3_techs_are_defined_but_not_in_the_research_deck`, `test_real_data_loads_without_warnings` (existing) |
| AC3 | `test_content::test_every_card_a_tech_gives_is_a_locked_pile_it_unlocks` |
| AC4 | `test_content::test_every_card_moved_out_of_the_deck_is_unlocked_by_a_tech` (`UNLOCKED` extended) |
| AC5 | existing content tests unchanged; `test_real_deck_has_wealth_costs_and_capital_makes_wealth` needs no change (Farm costs wealth since 076) |

## Manual check
- [ ] Review the tree table above before the build starts.
- [ ] In a full game, researching Mysticism puts a Temple in the discard, and Buy Cards then sells Temples.
- [ ] Era 2 arrives through Bronze Working or the thresholds; era 3 never does.
- [ ] Sim: mean score, wealth left at the end, and techs researched per game, before and after, in the Log.

## Log
