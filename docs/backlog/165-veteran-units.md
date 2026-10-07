---
id: 165
title: Units that repel a raid become veterans
type: feature
status: red-review
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
| AC1 | `test_veterans::test_veteran_max_defaults_to_0_and_rejects_bad_values` |
| AC2 | `test_working_units_on_a_territory_that_repels_a_raid_become_veterans`, `test_idle_units_and_units_elsewhere_dont_become_veterans`, `test_no_veterans_when_veteran_max_is_0_or_the_raid_pillages` |
| AC3 | `test_a_unit_at_veteran_max_gains_no_more` |
| AC4 | `test_a_veteran_keeps_its_counters_when_it_moves`, `test_a_disbanded_veteran_starts_again_at_0`, `test_a_veteran_lost_in_a_raid_starts_again_at_0`, `test_unit_veterancy_is_0_for_anything_but_a_unit_in_the_tableau` |
| AC5 | `test_veteran_details_show_its_counters` |

## Manual check
- [ ] Shipped `veteran_max` 2. A veteran unit shows its counters (pips or chevrons) in the territory view.

## Log
