---
id: 261
title: The grow op can pick its territory and cap how many it grows
type: feature
status: in-progress
branch: feat/261-grow-best-and-count
---

## Goal
Growth cards that aren't buildings (actions, events, techs) can add pop where it helps most, and a card that grows
several territories can be capped so it doesn't scale with a wide empire. Item 262 builds Bread and Beer and Land
Grants on this (spike `spike/growth-cards`).

## Acceptance criteria
Fixtures: population on, food_upkeep 0; Homeland (housing 7) first in the tableau, Grassland (housing 4) and Hills
(housing 5) settled after it.

- [ ] AC1: `where: "best"` grows the settled territory with idle buildings first: given Homeland 3 pop with 2
  buildings, and Grassland 1 pop with 2 buildings (one idle), when a card with `{op: grow, amount: 1, where: best}`
  resolves, then Grassland has 2 pop and Homeland stays 3.
- [ ] AC2: with no idle buildings anywhere, `best` grows the lowest pop with room: Homeland 3, Grassland 1, Hills 2 →
  Grassland 2. On a tie of the lowest pop (Grassland 2, Hills 2), the first in tableau order grows (Grassland). Among
  several territories with idle buildings, the lowest pop (then tableau order) goes first.
- [ ] AC3: `best` skips full territories (Grassland 4 of 4 with an idle building, Homeland 3 of 7 → Homeland grows),
  and does nothing (no pop change, no error) when every territory is full, during a Famine, or with population off.
  `amount: 2` adds 2 to the one chosen territory, capped by its housing.
- [ ] AC4: `where: "each"` with `count: 3` grows at most 3 territories, smallest pop first among those with room (ties:
  tableau order): given 4 settled territories with pop 1, 2, 2, 3 (all with room), the three with 1, 2, 2 grow and
  the one with 3 doesn't. With 2 territories with room it grows both. Without `count`, `each` still grows every
  territory (unchanged).
- [ ] AC5: The loader reads `where: "best"` on any card type (actions, buildings, units, events, techs: it needs no
  territory of its own) and `count` as an integer ≥ 1. It reports an error naming the card and field for `count` 0 or
  not an integer, and for `count` with a `where` other than `each`.
- [ ] AC6: Card text: `best` reads "+1 pop" short and "+1 pop where it's needed most" long; `each` with count 3 reads
  "+1 pop on 3 territories" short and "+1 pop on each of your 3 smallest territories with room" long. The rules text
  for these is generated, so no card names a count by hand.

## Out of scope
- New cards in data: that's 262.
- Player-chosen targets for action cards (an action that targets a territory).
- Balance.

## Design notes
- `grow_effect.gd`: `WHERE` gains `"best"`; new optional field `count` (int ≥ 1, `each` only). `needs_own_territory()`
  stays true only for `here`. `upkeep_ok()` stays true (it changes only pop).
- "Idle buildings": `Territories.workers_on(e, uid).size() > pop`, the rule `Population.is_idle` already uses.
- The pick is a static query on the effect (or `Population`), so the bot and UI never re-derive it.
- Spike version: `spike/growth-cards`, `engine/effects/grow_effect.gd` (`best_territory`, `count`).

## Test plan
All in `tests/test_growth_cards.gd` (fixture cards `GROW_CARDS`: Bread `best` 1, Banquet `best` 2, Grants `each`
count 3; `make_engine` gained an `extra_cards` argument).

| AC | Test |
|---|---|
| AC1 | `test_best_grows_the_territory_with_idle_buildings` |
| AC2 | `test_best_without_idle_buildings_grows_the_lowest_pop`, `test_best_breaks_a_tie_in_tableau_order`, `test_best_among_idle_territories_picks_the_lowest_pop` |
| AC3 | `test_best_skips_full_territories`, `test_best_does_nothing_when_it_cannot_grow`, `test_best_adds_the_whole_amount_to_one_territory_capped_by_housing` |
| AC4 | `test_each_with_count_grows_the_smallest_territories_with_room`, `test_each_with_count_skips_full_territories`, `test_each_without_count_still_grows_every_territory` |
| AC5 | `test_best_loads_on_any_card_type`, `test_count_loads_with_each`, `test_count_validation` |
| AC6 | `test_best_and_count_text` |

## Log
