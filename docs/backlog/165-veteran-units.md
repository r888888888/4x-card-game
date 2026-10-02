---
id: 165
title: Units that repel a raid become veterans
type: feature
status: ready
branch: feat/165-veteran-units
---

## Goal
Units that win get better: each working unit on a territory that repels a raid gains a veteran counter worth +1
strength, up to a cap. Gives a reason to keep a garrison alive rather than recruit fresh ones. Follows 162 and 164.

## Acceptance criteria
- [ ] AC1 (config): Config `veteran_max` (int ≥ 0, default 0: no veterans) loads; a negative or non-int value is a
  config error.
- [ ] AC2 (gain): With `veteran_max` 2, when a raid on Hills is repelled, each working unit stationed on Hills gains 1
  counter (`unit_veterancy(uid)`), and `unit_strength` rises by 1 each; idle units and units elsewhere gain none.
  `raid_resolved`'s outcome lists them as `veterans`.
- [ ] AC3 (cap): A unit at 2 counters gains no more from later repelled raids.
- [ ] AC4 (keep and lose): Moving keeps the counters; a unit that leaves the tableau (disbanded or lost in a raid)
  loses them, so if it is played again it starts at 0.
- [ ] AC5 (text): Card details show "Veteran 1 (+1 strength)" on a unit with 1 counter.

## Out of scope
- Veterancy from anything but repelled raids.

## Design notes
- Uses `CardInstance.counters` (already copied by `copy()`), reset when a unit leaves the tableau.
- New API `unit_veterancy(uid)`; `unit_strength` = printed + training + veterancy.

## Test plan
| AC | Test |
|---|---|

## Manual check
- [ ] Shipped `veteran_max` 2. A veteran unit shows its counters (pips or chevrons) in the territory view.

## Log
