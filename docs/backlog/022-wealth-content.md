---
id: 022
title: Move premium buildings and trade cards to wealth
type: feature
status: done
branch: feat/022-wealth-content
---

## Goal
Give wealth a job in the real game. Culture buildings, the wonder and the Forge cost a mix of food and
wealth. The Capital and trade cards produce wealth. Growing your people and building your
civilization then draw on different resources. Depends on 021.

## Acceptance criteria
<!-- Content tests check shape, not balance numbers (see tests/test_content.gd). -->
- [x] AC1: The real data (`data/*.json`) loads with no errors or warnings, and at least one card in the
  deck costs wealth and at least one tableau card (Capital) produces wealth at upkeep.
- [x] AC2: Every card that costs wealth also has at least one wealth source in the deck or the starting
  tableau, so no card needs wealth the game can't produce. (A loader-level check isn't needed; this is a
  content test.)
- [x] AC3: Scripted smoke game on real data (the existing `play_scripted_game`), 3 seeds: the game
  finishes, wealth never goes negative, and in at least one seed a card costing wealth is played.

## Out of scope
- New cards. Wealth VP at game end. Food/wealth conversion. Maintenance.
- Tuning beyond these first numbers. Playtesting sets them later.

## Design notes
Data only. Starting numbers (to be tuned by playtesting):

| Card | Now | New |
|---|---|---|
| Capital | ⟳ +2 food | ⟳ +2 food, +1 wealth |
| Caravan | 1 food: +2 food per city | 1 food: +2 wealth per city |
| Market | 3 food: ⟳ +1 VP (+1 on Gold) | 3 food: ⟳ +1 wealth (+1 on Gold) |
| Temple | 4 food | 2 food + 2 wealth |
| Monument | 5 food | 2 food + 3 wealth |
| Pyramids | 12 food | 6 food + 6 wealth |
| Forge | 4 food | 2 food + 2 wealth |

Starting wealth stays 0. Wealth in the first turns comes from the Capital (+1 per turn).
Caravan and Market stop producing food and VP respectively; check in playtesting whether the food
economy is now too tight.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_data_loader::test_real_data_loads` (existing guard), `test_content::test_real_deck_has_wealth_costs_and_capital_makes_wealth` |
| AC2 | `test_content::test_every_wealth_cost_has_a_wealth_source` (passes now: no card costs wealth yet) |
| AC3 | `test_content::test_scripted_games_spend_wealth_and_never_go_negative` (seeds 1–3) |

## Manual check
Run `godot --path .`.
- [ ] Play a full game: wealth builds up from the Capital, and Temple/Monument/Pyramids can be afforded
  at a reasonable point. Record the final score and impressions in the Log.

## Log
- Data changed exactly as in the table above. No engine or UI change. Suite: 186 → 189 tests.
- The AC3 test disconnects its signal lambdas after each game: they hold the engine, and the cycle
  leaked it at exit.
- Scripted-bot numbers (20 seeds, scratch run, not committed; the bot plays the first playable card,
  so this is only a rough signal):
  - Wealth-cost cards were played in 16 of 20 seeds (1–3 per game).
  - Unspent wealth at game end: 26–60 (mean ~36). Wealth builds up much faster than 6 wealth-cost
    cards in the deck can use it.
  - Mean score fell from ~43 to ~21. Most likely causes: Market no longer scores, Caravan no longer
    gives food, and wealth is left unspent.
  - Follow-up for playtesting: more wealth sinks (more wealth-cost cards, or wealth for growth or VP),
    or less wealth income (Capital +1 per turn alone gives ~20 per game).
