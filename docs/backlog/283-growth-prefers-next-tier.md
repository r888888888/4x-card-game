---
id: 283
title: Growth "where needed most" prefers a territory one pop short of its next tier
type: feature
status: ready
branch: feat/283-growth-prefers-next-tier
---

## Goal
With settlement tiers (281), the pop that lifts a territory into its next tier is worth the most: a new slot, and maybe
idle buildings back at work. A `grow` with `where: "best"` (Bread and Beer) should spend its pop there, instead of on
the smallest territory, unless a territory has idle buildings. Needs 281.

## Acceptance criteria
Fixtures: 281's tiers (hamlet 0, village 4, town 8, metropolis 13), population on, `TEST_CARDS` territories (Grassland
housing 4, Hills housing 5, Jungle housing 3), and a `grow` action with `where: "best"`, amount 1.

- [ ] AC1: Given the Homeland at pop 2, Grassland at pop 1 and Hills at pop 3 (one short of Village, with room), when
  the grow action is played, then Hills is at 4 and the others are unchanged (`best_to_grow` would have picked
  Grassland before this item).
- [ ] AC2: Idle buildings still come first: given AC1, plus Grassland with 2 buildings at pop 1 (one worker-idle), when
  the grow action is played, then Grassland is at 2 and Hills stays at 3.
- [ ] AC3: Several one short: given Hills at pop 3 and the Homeland at pop 7 with a Silo (housing 8, one short of Town),
  when the grow action is played, then Hills (the smaller pop) grows. With two territories one short at the same pop,
  the first in tableau order grows.
- [ ] AC4: One short but full doesn't count: given Jungle at pop 3 (housing 3), Grassland at pop 1, and every other
  territory at pop 2 or more and not one short, when the grow action is played, then Grassland grows (smallest pop, as
  before).
- [ ] AC5: No tiers, no change: given the AC1 territories and a config with no `population.tiers`, when the grow action
  is played, then Grassland grows (today's rule). The top tier has no next tier: a Metropolis is never "one short".

## Out of scope
- Letting the player choose the growth target.
- `where: "each"` with a count (Land Grants) keeps its smallest-first rule (261).
- Bot: it already plays a growth card only when that adds pop and keeps food at +1 (262 AC4), so it needs no new rule.

## Design notes
- `Population.best_to_grow`: among `smallest_with_room`, first one with worker-idle buildings (unchanged). Then the
  first one whose `next_tier_pop(uid) == pop + 1` (the list is already smallest-first, ties in tableau order). Then
  the smallest. Update its doc comment and the grow op's card-text tooltip if it describes the target ("where it's
  needed most" can stay).

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_growth_cards::test_…` |

## Log
- 2026-10-04: specced with the user as a follow-up to the tier critique ("prefer crossing" over a player choice).
