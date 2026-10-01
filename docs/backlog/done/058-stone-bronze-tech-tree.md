---
id: 058
title: Stone Age and Bronze Age tech tree; gate cards behind techs
type: feature
status: done
branch: feat/058-stone-bronze-tech-tree
---

## Goal
Rebuild the tech content as a Stone Age (era 1) → Bronze Age (era 2) tree (TODO 7). Most buildings and the Caravan
move out of the starting deck: each comes from a tech, as 1 free copy plus an unlocked supply pile (057). The starting
deck shrinks to the basics. The iron-age and classical techs move to era 3, kept in the data but out of the game for
now. Research rules are unchanged: reveal 2, passes, and prereqs only give a discount. The tree is a view (059).

## Acceptance criteria
<!-- Content invariants; exact names and prices are under Manual check. -->
- [x] AC1: `research_deck` has at least 6 era-1 and 6 era-2 techs, and an era-1 tech adds era 2 (existing test).
  No tech in `research_deck` has era ≥ 3, and no card anywhere has `add_era` with era ≥ 3.
- [x] AC2: The era-3 techs (Philosophy, Iron Working, Mathematics, Monarchy, Astronomy, Engineering) are still defined
  in `cards.json`, but not in `research_deck`. The real data loads with no warnings.
- [x] AC3: For every tech in `research_deck`, each non-wonder card it creates is a locked supply pile that the same
  tech unlocks. Wonders (tag `wonder`) are created only, with no pile.
- [x] AC4: Caravan, Temple, Mine, Market and Granary join `UNLOCKED`. None of them is in the starting deck, and a
  tech in `research_deck` creates each (existing test, list extended).
- [x] AC5: The existing content tests stay green: prereqs are in the research deck, techs create no techs, a tech
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
| Bug | `test_sim::test_bug_058_bot_ends_the_turn_when_a_free_card_only_redraws_itself` |
| AC5 | existing content tests unchanged; `test_real_deck_has_wealth_costs_and_capital_makes_wealth` needs no change (Farm costs wealth since 076) |

## Manual check
- [x] Review the tree table above before the build starts (approved with the changes in the Log).
- [ ] In a full game, researching Mysticism puts a Temple in the discard, and Buy Cards then sells Temples.
- [ ] Era 2 arrives through Bronze Working or the thresholds; era 3 never does.
- [x] Sim: mean score and techs researched per game, before and after, in the Log (the sim doesn't report wealth
  left at the end).

## Log
- 2026-09-29: Shipped (approved at red). Era 1: Pottery (2 wealth, 1 VP; Granary, drops its +1 food), Animal
  Husbandry (3; Pasture), Mining (2, new; Mine), Mysticism (2, new; Temple), The Wheel (3, new; Caravan), Masonry (4,
  prereq Mining; Monument), Bronze Working (4, prereq Mining; Forge, adds era 2). Era 2: Writing (3; Library),
  Currency (4, prereq Bronze Working; Market, drops its +1 wealth), Sailing (4; Harbor), Priesthood (5, prereq
  Mysticism; Pyramids, no pile), Code of Laws (5, prereq Writing; +1 wealth each upkeep), Calendar (5, prereq
  Pottery; 3 VP). Era 3 (not in the deck): Philosophy (no longer adds era 2), Iron Working, Mathematics, Monarchy,
  Astronomy, Engineering.
- Locked piles [price × count]: Granary 2×4, Pasture 2×2, Mine 2×2, Temple 3×2, Caravan 2×2, Monument 3×1, Forge 3×1,
  Library 3×1, Market 3×2, Harbor 3×2. Open piles: Scout, Settler, Insight (unchanged).
- Starting deck: Farm 4, Irrigation 1, Settler 2, Scout 2, Lumber Camp 2, Insight 2 (13 cards, from 19). The spec's
  Forage and Harvest Festival are events since 069, so they aren't in it; Insight is 2 (not 1) so research keeps pace.
- Granary pile 3 → 4 to keep 4 growth cards reachable (`test_real_deck_has_growth_cards`); the deck copy left.
- Bug found by the sweep: with the thin deck two free Scouts redraw each other through the reshuffle forever, so the
  bot never ended seeds 4, 6 and 10. Rules unchanged (a player gains nothing from it); `ScriptedBot` now ends the turn
  after 40 plays (`MAX_PLAYS_PER_TURN`), with a reproduction test.
- AC5: `test_real_deck_has_wealth_costs_and_capital_makes_wealth` needed no change (Farm costs wealth since 076).
- Balance, `scripts/sim.sh 20` (main → this branch). Big moves: cities ×2 (the thin deck draws Settlers and Scouts
  far more often, and the territory deck runs out: max 11), pop +52%, techs +17% with the min down to 3. Score +4%.
  Worth a look in 066's balance pass.

  | metric | main mean (min–max) | 058 mean (min–max) | Δ mean |
  |---|---|---|---|
  | score | 59.25 (27–103) | 61.70 (33–89) | +2.45 |
  | cities | 5.35 (0–11) | 10.35 (4–11) | +5.00 (+93%) |
  | pop | 9.30 (4–16) | 14.15 (11–16) | +4.85 (+52%) |
  | techs | 7.50 (5–12) | 8.75 (3–13) | +1.25 (+17%) |
  | bought | 0 | 0 | 0 |
  | era | 2 | 2 | 0 |
- Proposed: close 023 (more wealth sinks) as `wontfix`, superseded by the locked piles. Not done; waiting for you.
