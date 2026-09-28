---
id: 028
title: First tech content (era 1 and 2 techs, Library)
type: feature
status: review
branch: feat/028-tech-content
---

## Goal
Put techs in the real game: an era-1 and era-2 research deck, a Library, and some current deck cards
(Pyramids, Forge) moved behind techs so research unlocks them. The numbers are a first draft to
playtest. Depends on 025–027.

## Acceptance criteria
<!-- Content tests check shape, not balance numbers (see tests/test_content.gd). -->
- [x] AC1: The real data loads with no errors or warnings. `research_deck` has at least 6 era-1 techs
  and at least 6 era-2 techs, and at least one era-1 tech has an `add_era` 2 effect.
- [x] AC2: Every tech's `prereq` is in `research_deck`, and every `create` target of a tech is a
  non-tech card.
- [x] AC3: A Library exists and is reachable: a tech creates it (it isn't in the main deck).
- [x] AC4: Every card taken out of the starting deck (Pasture, Harbor, Monument, Pyramids, Forge) is
  created by some tech in `research_deck`. (That tech can still be lost to passes; then the card is gone
  for the game. That's intended: the player chose not to prioritize it.)
- [x] AC5: The scripted smoke game on real data (`play_scripted_game`, extended to research each turn
  and buy the cheapest tech it can afford), 3 seeds: the game finishes, wealth never goes negative,
  and in at least one seed a tech is bought.
- [x] AC6: The existing content tests stay green (City smoke test, wealth smoke test, wealth-source
  coverage).

## Out of scope
- Balance targets in tests. Record the scripted-bot numbers in the Log only.
- Era 3. The event/threat deck.
- Wealth VP at game end, and 023 (more wealth sinks): rerun the wealth numbers after this, then decide.

## Design notes
Data only (`data/cards.json`, `data/config.json`), plus the smoke-bot change in `tests/test_content.gd`.
Numbers are a first draft for playtesting.

| Era | Tech | Cost | Prereq | Effect |
|---|---|---|---|---|
| 1 | Pottery | 2 | — | 1 VP, ⟳ +1 food |
| 1 | Animal Husbandry | 3 | — | add a Pasture to your discard |
| 1 | Bronze Working | 3 | — | add a Forge to your discard |
| 1 | Writing | 3 | — | add a Library to your discard |
| 1 | Masonry | 4 | Pottery | add Pyramids to your discard |
| 1 | Currency | 4 | Bronze Working | ⟳ +1 wealth |
| 1 | Philosophy | 5 | Writing | 2 VP, adds era 2 techs |
| 2 | Iron Working | 5 | Bronze Working | 2 VP, ⟳ +1 VP |
| 2 | Mathematics | 5 | Currency | ⟳ +1 wealth per `culture` card |
| 2 | Sailing | 4 | — | add a Harbor to your discard |
| 2 | Monarchy | 6 | Philosophy | 3 VP, ⟳ +1 wealth |
| 2 | Astronomy | 6 | Mathematics | 4 VP |
| 2 | Engineering | 6 | Masonry | add a Monument to your discard |

- Unlock techs use `create` with `"zone": "discard"`.
- Main deck: Pasture ×2, Harbor ×2, Monument ×2, Pyramids ×1 and Forge ×1 leave it (36 → 28 cards). Each
  unlock tech gives back one copy, so this is a real cost of skipping the tech. Playtest whether to give
  some copies back.
- Library: building, 1 food + 2 wealth, 1 VP, no tag. ⟳ +1 research.
- Mathematics counts culture cards on the tableau (Temple, Monument), using `gain_per_tag` on upkeep.
- 023 (more wealth sinks) may be superseded. Rerun its wealth stats (mean score, unspent wealth, wealth-cost
  plays per game) before and after, and put them in the Log.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_content::test_research_deck_has_6_techs_in_each_of_eras_1_and_2`, `test_real_data_loads_without_warnings` (already passes: guard), `test_data_loader::test_real_data_loads` (existing) |
| AC2 | `test_every_tech_prereq_is_in_the_research_deck`, `test_techs_only_create_cards_that_are_not_techs` |
| AC3 | `test_a_tech_unlocks_the_library` |
| AC4 | `test_every_card_moved_out_of_the_deck_is_unlocked_by_a_tech` |
| AC5 | `test_scripted_games_buy_techs_and_never_go_negative` (`play_scripted_game` now researches and buys the cheapest affordable tech) |
| AC6 | existing: `test_scripted_games_run_and_found_cities`, `test_scripted_games_spend_wealth_and_never_go_negative`, `test_every_wealth_cost_has_a_wealth_source` |

## Manual check
Run `godot --path .`.
- [ ] The Research button (R) shows above End turn from turn 1 ("1 left · deck 7 · era 1").
- [ ] Buying Writing puts a Library in your discard; it shows up after the next reshuffle.
- [ ] Buying Philosophy (or emptying the deck) moves the button to era 2.
- [ ] Over a full game, record techs bought, techs lost, final score and wealth left in the Log.

## Log
- Scripted bot (20 seeds, `play_scripted_game` researching every turn and buying the cheapest affordable tech):

  | | Mean score | Wealth left | Techs bought | Techs lost | Era 2 reached | First buy |
  |---|---|---|---|---|---|---|
  | Before (main data) | 20.7 | 36.2 | 0 | 0 | 0/20 | — |
  | After | 41.5 | 36.0 | 12.4 of 13 | 0.6 | 20/20 | turn 2.5 |

  The bot buys nearly every tech and still ends with ~36 wealth: techs are far too cheap for the wealth the game
  makes. Balance is deferred to playtesting, but raising tech costs (or cutting wealth income) is the obvious lever.
- `play_scripted_game` now researches (see test plan); existing smoke tests stayed green.
- Suite: 289 → 296 tests. No engine or UI change.
- Spec review: losing an unlock tech (and so its card) is intended. Balance issues (Library value, Mathematics
  with few culture cards, Currency/Pottery as default picks, costs vs. total wealth) are deferred to playtesting.
