---
id: 080
title: Five early-game cards (Barter, Storyteller, Fishing Huts, Quarry, Shrine)
type: feature
status: ready
branch: feat/080-early-game-cards
---

## Goal
Before any tech is researched, the player has little to do: only fresh-water and forest/jungle land takes a
building, the Capital is the only wealth source, and spare food has no use besides growth. Five data-only cards
give the early turns more choices. Barter turns food into wealth, Storyteller draws cards, and three cheap
buildings are available from the start of the game. Fishing Huts and Quarry give coastal land and hills/mountain
something to build, and Shrine can go on any territory.

## Acceptance criteria
<!-- Content item: criteria are invariants of data/*.json; the shipped numbers are under Manual check. -->
- [ ] AC1 (Barter): the real data has an `action` card `barter` whose cost is food only (≥ 1) and whose only
  effect is a `play` `gain` of wealth.
- [ ] AC2 (Storyteller): the real data has an `action` card `storyteller` whose cost is food only (≥ 1) and whose
  only effect is a `play` `draw` of 2 or more cards.
- [ ] AC3 (buildings): the real data has `building` cards `fishing_huts` (requires `coastal`; an `upkeep` `gain` of
  food), `quarry` (requires `hills` or `mountain`, or both) and `shrine` (no `requires`; tag `culture`; printed vp ≥ 1).
- [ ] AC4 (placement): the starting `deck` has at least 1 `barter` and at least 1 `storyteller`. `supply` has piles
  for `fishing_huts`, `quarry` and `shrine`, and none of them is `locked`. None of the five cards is created or
  unlocked by a tech.
- [ ] AC5 (reachable land): Given a new game on the real data, then every territory in `territory_deck` can take
  at least one building that is in the starting deck or in an unlocked supply pile (its `requires` is empty or
  shares a keyword with the territory's printed keywords).
- [ ] AC6 (still plays): the scripted 20-seed sweep (`test_scripted_sweep_over_20_seeds`) still passes with the new
  cards in the deck and supply.

## Out of scope
- New effect ops: `gain_per_keyword` is 081 and `trash` is 082.
- Oasis Camp (desert) and Trading Post, and any bot changes to prefer the new cards.
- A tag on Quarry for a later Masonry synergy.

## Design notes
- Data only, using the existing ops `gain`, `draw` and `score`. No engine or loader change is expected. If a test
  shows one is needed, stop and split it into its own item.
- Planned data (reviewed under Manual check, not pinned in tests):
  - `barter`: action, cost 2 food, play +2 wealth. Deck ×1.
  - `storyteller`: action, cost 1 food, draw 2. Deck ×1.
  - `fishing_huts`: building, cost 1 food + 1 wealth, requires `coastal`, upkeep +1 food. Supply price 2, count 2.
    Harbor (Sailing) is the +2 food upgrade.
  - `quarry`: building, cost 2 wealth, requires `hills`/`mountain`, play +1 VP (like Lumber Camp). Supply price 2,
    count 2. Mine (Mining) is the upkeep upgrade.
  - `shrine`: building, cost 2 wealth, vp 1, tag `culture`, no effects. Supply price 2, count 2. Feeds Mathematics'
    per-`culture` wealth later. Temple (Mysticism) is the upgrade.
- The building costs follow 076: a food producer costs 1 food + wealth, and every other building costs wealth only.
- AC5 checks printed keywords only, not rolled resource keywords (gold, tin, copper).
- Adding 2 cards to the starting deck lowers the chance of drawing Farms early. More wealth also means techs
  come sooner, which shortens the early game. Run the `balance` skill before closing.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_content::test_…` |

## Manual check
- [ ] Review the shipped numbers in Design notes against `scripts/sim.sh` before/after (`balance` skill): era-2 turn,
  final score, wealth curve.
- [ ] In a game, the Supply screen shows Fishing Huts, Quarry and Shrine from turn 1. A Quarry can go on Hills and
  Fishing Huts on a Bay.

## Log
