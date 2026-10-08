---
id: 404
title: The claimants - five factions for wide, tall, research, coastal and military play
type: feature
status: ready
branch: feat/404-claimant-content
---

## Goal
Put real claimants in the game (content for 401–403): five factions, each backing a strategy, with one claimant per era.
A faction's boon grows with the realm it fits (per city, per port, per learning building), and its court passive with
rank, so the claimant you back says how you mean to play. Also give the insight buildings a shared `learning` tag so
research play has something to count.

Builds on 400 (the `strength` modifier), 401, 402 and 403.

## Acceptance criteria
Content invariants on the real data (`tests/test_content.gd`); per-card numbers are under Manual check.

- [ ] AC1 (a full line per faction): Every faction in `unrest.court.claimants` has exactly one claimant for each era
  from 1 to the highest era of the research deck's techs, and every claimant card in `data/cards.json` is in the court
  pool. There are more factions than `dealt`, so a deal can differ.
- [ ] AC2 (each has both halves): Every claimant has at least one play effect (its boon) and at least one upkeep effect
  or modifier (its court passive).
- [ ] AC3 (what it counts exists): Every tag a claimant's `gain_per_tag` counts is carried by at least one card the
  player can get (in the deck, the supply, a build-menu unlock, or created by a card), and every keyword a
  `gain_per_keyword` counts is printed on at least one territory.
- [ ] AC4 (the learning tag): Every building whose upkeep gains insight carries the `learning` tag.
- [ ] AC5 (it loads): The real data loads with no errors or warnings, and Anarchy's card text names the claimants'
  rule.

## Out of scope
- The engine rules (401–403); the `strength` modifier (400).
- Card art: the briefs go in `docs/design/card-art.md` here; the pictures come from the `card-art` skill, which asks
  before spending.
- Balance beyond the first numbers below; a balance item tunes them.

## Design notes
- Factions: `frontier` (wide), `builders` (tall), `sages` (research), `sea_lords` (coastal), `warlords` (military).
  A sixth (a Temple faction: unrest and VP) is a candidate if play shows the same three dealt too often.
- `learning` goes on Scribal School, Library, House of Life, Stone Circle, the Great Library and the Oracle of Delphi
  (every building with an upkeep insight gain, so AC4 holds).
- The first numbers (for review; the per-rank passive applies once per rank, 402):

| Faction | Era | Claimant | Boon when backed | In court, per rank |
|---|---|---|---|---|
| Frontier | 1 | Pathfinder | a Settler to your hand | +1 administers |
| | 2 | Land Baron | a Settler to your hand; +1 wealth per city | +1 administers, +1 food |
| | 3 | Satrap | 2 Settlers to your hand | +1 administers, +1 wealth per 2 cities |
| Builders | 1 | Master Mason | grow 1 (best) | +1 housing |
| | 2 | Magistrate | grow 2 (best) | +1 housing, −1 unrest |
| | 3 | Architect | grow 2 (best), +1 VP | +1 housing, +1 VP |
| Sages | 1 | Star-Watcher | +3 insight | +1 insight |
| | 2 | Archivist | +2 insight, +1 insight per learning building | +2 insight |
| | 3 | Philosopher | +2 insight per learning building | +1 insight per gain |
| Sea Lords | 1 | Fisher Chief | +2 food per coastal territory | +1 wealth per 2 ports |
| | 2 | Merchant Admiral | Sea Trade to your hand; +2 wealth per port | +1 wealth per port |
| | 3 | Thalassocrat | +3 wealth per port | +1 wealth per port, +1 VP |
| Warlords | 1 | War Chief | Warriors to your hand | +1 food per 2 units |
| | 2 | General | Spearmen to your hand | +1 strength |
| | 3 | Conqueror | Chariots to your hand | +1 strength, +1 wealth per unit |

- Ops used: `create` (zone `hand`), `grow` (`where: best`), `gain`, `gain_per_tag` (with `per`), `gain_per_keyword`,
  `score`; modifiers `administers`, `housing`, `insight_per_gain`, `strength` (400). No new op.
- Watch: the Philosopher's +1 insight per gain at rank 3 (+3 per gain; Alphabet gives +1) and the per-port passives
  stacking with rank; the balance item may make some passives flat.
- Names and flavor follow the style guide's §18 (read it before writing any).
- `GenericBot` values boons and passives through its rollouts and `turn_forecast`; nothing new for it.

## Test plan
| AC | Test |
|---|---|
| AC1 | |

## Manual check
- [ ] The 15 claimants carry the numbers in the table above, and their faces read well (When backed / In court, per
  rank).
- [ ] An Anarchy in each era deals that era's claimants.
- [ ] Balance worries (for the user to run): which factions the `wide` and `tall` bots back, and how strong a rank-3
  court is. `scripts/sim.sh --level 2 --compare <main checkout>` (score, revolts; a court-faction tally in `SimStats`
  would show the backing).

## Log
