---
id: 006
title: Territory content and balance pass
type: feature
status: ready
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

## Manual check
- [ ] Play 2–3 full games. Expanding feels necessary by mid-game, and placement choices feel meaningful.

## Log
