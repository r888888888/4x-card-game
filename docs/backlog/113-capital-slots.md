---
id: 113
title: Balance the Capital's building slots
type: feature
status: review
branch: feat/113-capital-slots
---

## Goal
The Capital adds +4 slots to its territory, but on the starting River Meadow (3 slots, housing 5) that makes 7 slots
while workers (pop, capped by housing) allow at most 5 buildings, 6 with a Granary. One or two of the Capital's slots
can never be filled. Lower the Capital to +3 so its territory has 6 slots: a Granary plus five buildings, each with a
worker once pop grows to the Granary-raised housing of 6.

## Acceptance criteria
- [x] AC1: the real data loads with no loader errors (`test_real_data_loads`) and the full suite, including the
  seed smoke sweep, stays green.

## Out of scope
- Other slot, housing or territory numbers; the ordinary City (still no slots).
- Improving the sim bot so it can measure Capital slots (it builds on the first valid territory and founds ~55 cities,
  so Capital slots never bind for it: a 40-seed sweep of +0…+6 gave identical results).

## Design notes
- Data only: `capital.slots` 4 → 3 in `data/cards.json`. No format or rule change, no new tests (balance skill:
  content tests check invariants, not numbers).

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_content::test_real_data_loads` and the smoke sweep (existing) |

## Manual check
- [ ] `data/cards.json`: Capital has `"slots": 3`.
- [ ] New game: the starting territory shows 6 slots (River Meadow 3 + Capital 3).

## Log
- Chosen by reasoning, not the sim (option 1): the sim bot is blind to Capital slots.
- +3 rather than +2: +2 (5 slots = housing 5) would leave a Granary's extra housing with no slot to use on the Capital.
- Worry: 111 (civilization home territory) will put the Capital on other lands. On a 1-slot, housing-6 land (e.g.
  Floodplain Delta) +3 gives 4 slots against 6 workers; on a 3-slot, housing-4 land 6 slots against 4 workers.
  Revisit once 111 lands.
