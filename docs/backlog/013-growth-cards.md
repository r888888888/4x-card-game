---
id: 013
title: Growth cards (grow op, Granary, Harvest Festival)
type: feature
status: ready
branch: feat/013-growth-cards
---

## Goal
Cards can add pop without paying the food cost of buying growth, giving a second path to grow alongside
010. Depends on 009 (and on 012 for idle Granaries).

## Acceptance criteria
- [ ] AC1: Loader. A `grow` op takes `amount` (int ≥ 1) and `where` (`"here"` or `"each"`, default
  `"here"`). Any other `where` gives an error naming the file, card and field. Generated text:
  `here` → "+1 pop here", `each` → "+1 pop in each territory" (with the usual "Upkeep: " prefix).
- [ ] AC2: `where: "here"` on a building (Granary, upkeep +1): given its territory has pop 2 and housing 7,
  when upkeep resolves, then that territory has pop 3 and no food is spent.
- [ ] AC3: `where: "each"` on an action (Harvest Festival, +1): given Homeland pop 2 and a settled T with
  pop 1, when played, then Homeland has pop 3 and T has pop 2.
- [ ] AC4: Growth from cards never goes above housing. A territory at housing stays unchanged, and other
  territories still grow. A `here` effect on a card with no territory does nothing.
- [ ] AC5: With no `population` block, `grow` does nothing.

## Out of scope
- A growth action that targets one chosen territory (needs a territory-only target filter; later).

## Design notes
- New op `grow`: follow the `add-effect` skill.
- Real data (numbers to be tuned by playtesting): Granary, a building costing 3 food with upkeep +1 pop
  here; Harvest Festival, an action costing 2 food with +1 pop in each territory. Add them to the deck
  (Granary ×2, Harvest Festival ×2).
- Pop gained from a played card could be added to the `card_played` outcome later for UI animation; not
  needed now.

## Test plan
| AC | Test |
|---|---|

## Manual check
- [ ] Granary and Harvest Festival card text reads correctly, and pop counters go up when they fire.

## Log
- 2026-09-28: spec'd with the user (growth = buy with food + cards).
