---
id: 130
title: Terrain keywords: every territory has exactly one terrain
type: feature
status: ready
branch: feat/130-terrain-keywords
---

## Goal
Territories are one terrain (grassland, hills, desert, …) plus any number of features (fresh water, coastal, flood
plain). The loader enforces that, so the territory set stays orthogonal: a territory's name is its terrain plus its
features, and no two territory types blur into each other. Rolled resources follow the terrain, so every hills-type
territory can roll metals without a separate table for each.

## Acceptance criteria
Fixtures: TEST config with `keywords: ["mountain", "fresh_water", "flood_plain", "plain"]` and `terrains: ["mountain",
"plain"]` (only where a test opts in; with no `terrains` the existing fixtures load unchanged).

- [ ] AC1 (loader, terrains list): config `terrains` is optional, an array of keyword ids, default `[]`. Each must be in
  `keywords`. Given `terrains: ["swamp"]` with no `swamp` keyword, loading fails with an error naming config.json,
  `terrains` and `'swamp'`. Given `terrains: "mountain"` (not an array), loading fails with an error naming config.json
  and `terrains`. The normalized config has `terrains`.
- [ ] AC2 (loader, exactly one terrain): when `terrains` is non-empty, every territory card prints exactly one of them.
  A territory with keywords `["fresh_water"]` is a load error naming the card and `keywords` ("needs exactly one
  terrain"); one with `["mountain", "plain"]` is a load error naming the card and both terrains. A territory with
  `["mountain", "fresh_water", "flood_plain"]` loads. With `terrains` empty, a territory with no keywords still loads.
- [ ] AC3 (terrain roll tables): a `territory_resources` key may be a terrain as well as a territory id. Given
  `territory_resources: {"mountain": [{"keywords": ["gold"], "weight": 1}]}`, every copy of each territory whose
  terrain is mountain (in the territory deck and the starting territory) has `gold`; a territory with another terrain
  rolls nothing. A key that is neither a territory card nor a terrain is still the error
  `territory_resources: unknown card '<key>'`.
- [ ] AC4 (precedence): a territory with a table under its own id rolls only from that table, never also from its
  terrain's. Given tables for both `hills` (the TEST territory, terrain mountain) → `[tin]` and `mountain` → `[gold]`,
  each Hills copy has `tin` and not `gold`. A territory with no table of either kind uses no rng step, as today.
- [ ] AC5 (keyword details): with `terrains` set, the generated detail text for a terrain keyword starts "A terrain."
  and for any other printed keyword starts "A territory feature."; resource keywords keep "A resource some territories
  have.". With `terrains` empty the text stays "A territory keyword.". The "Needed by" and "Bonus on it" parts are
  unchanged.

## Out of scope
- The real territory set, its keywords and numbers (131).
- Civilization home territories (111).
- Showing the terrain separately from features on the territory card or view.

## Design notes
- Data format: config `terrains: [keyword ids]`, a subset of `keywords`. `keywords` stays the full list of printable
  keywords, so `requires`, effect `keyword` and `gain_per_keyword` need no change.
- The exactly-one check needs both cards and config, so it lives in the config loader (it already validates
  `territory_resources` against cards); the message is prefixed with cards.json and the card id, like card errors.
- `Territories.make` looks up the territory's own table first, then its terrain's.
- `CardDetails._keyword_text` reads `config.terrains` to choose the opening sentence.
- PLAN.md: the territory section and `config.json` comment mention `terrains` and terrain-keyed roll tables.

## Test plan
| AC | Test |
|---|---|

## Log
