---
id: 006
title: Territory content and balance pass
type: feature
status: red-review
branch: feat/006-territory-content
---

## Goal
The real game uses territories well: there is a varied territory deck, buildings that care about
keywords, and a deck and costs tuned so a 20-turn game has a satisfying explore → settle → build
rhythm.

## Acceptance criteria
- [ ] AC1: `data/cards.json` and `data/config.json` load with no errors or warnings. A loader test on the real
  data guards this.
- [ ] AC2: The territory deck has at least 10 territories covering at least 5 keywords. Every keyword in config
  is used by at least one territory and at least one card.
- [ ] AC3: Given the real data and seeds 1–20, when a scripted "play the first playable card each step"
  loop runs 20 turns, then every game ends with no runtime errors, and at least one City beyond the Capital
  gets founded in most seeds. (This is a smoke test, not a balance assertion.)

## Out of scope
- A headless bot or statistical balance tooling (PLAN.md › Later).

## Design notes
- **Keywords (decided by the user, 2026-09-28):** `fresh_water`, `flood_plain`, `mountain`, `jungle`, `coastal`,
  `forest`, `hills`, `desert`, `grassland`, `iron`, `gold`. Already in `data/config.json` (005). Keywords are
  mostly features, so a territory can have several. Holy Site was dropped: it should come from an event
  (threat design, later), not be printed on a territory.
  AC2 ("every keyword is used by a territory and a card") applies to this whole list.

Proposed starting content, to be tuned by playtesting:
- **Territories:**
  - River Valley (2; Fresh Water, Flood Plain)
  - Lakeshore (2; Fresh Water)
  - Grassland (2)
  - Plains (2)
  - Hills (3; Mountain)
  - Rainforest (1; Jungle)
  - Floodplain Delta (2; Flood Plain)
  - Highlands (2; Mountain, Fresh Water)
  - …
- **Cards:**
  - Farm: +1 more food on Flood Plain
  - Irrigation: requires Fresh Water
  - Temple: +1 VP on Mountain
  - new Mine: requires Mountain
  - new Lumber Camp: requires Jungle
  - Scout: explore + draw 1
  - Settler cost review

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_data_loader::test_real_data_loads` (exists) |
| AC2 | `test_content::test_territory_deck_has_at_least_10_territories`, `test_content::test_territory_deck_covers_at_least_5_keywords`, `test_content::test_every_keyword_is_on_a_territory_and_a_card` |
| AC3 | `test_content::test_scripted_games_run_and_found_cities` (">= 11 of 20" is "most") |

## Manual check
- [ ] Play 2–3 full games. Expanding feels necessary by mid-game, and placement choices feel meaningful.

## Log
- 2026-09-28: red. AC2 tests fail (7 territories, 3 keywords covered). The AC3 smoke test already passes
  (a City founded in 20 of 20 seeds, no runtime errors); it guards the new content. The starting
  territory counts as "a territory" for keyword coverage.
