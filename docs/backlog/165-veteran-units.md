---
id: 165
title: Units that repel a raid become veterans
type: feature
status: review
branch: feat/165-veteran-units
---

## Goal
Units that win get better: each working unit on a territory that repels a raid gains a veteran counter worth +1
strength, up to a cap. Gives a reason to keep a garrison alive rather than recruit fresh ones. Follows 162 and 164.

## Acceptance criteria
- [x] AC1 (config): Config `veteran_max` (int ≥ 0, default 0: no veterans) loads; a negative or non-int value is a
  config error.
- [x] AC2 (gain): With `veteran_max` 2, when a raid on Hills is repelled, each working unit stationed on Hills gains 1
  counter (`unit_veterancy(uid)`), and `unit_strength` rises by 1 each; idle units and units elsewhere gain none.
  `raid_resolved`'s outcome lists them as `veterans`.
- [x] AC3 (cap): A unit at 2 counters gains no more from later repelled raids.
- [x] AC4 (keep and lose): Moving keeps the counters; a unit that leaves the tableau (disbanded or lost in a raid)
  loses them, so if it is played again it starts at 0.
- [x] AC5 (text): Card details show "Veteran 1 (+1 strength)" on a unit with 1 counter.

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
- [ ] Shipped `veteran_max` 2. Play a game until a raid is announced at a territory, garrison it with enough
  defence, and let it strike: the raid modal says it was repelled; the garrison's face shows "Strength N" one above
  its printed strength, and its details show "Veteran 1 (+1 strength)".
- [ ] Not built: veteran pips or chevrons in the territory view (see Log).

## Log
- Shipped `veteran_max` 2 in `data/config.json`. `Military.training` now sums the station's buildings (it was strength
  less printed, which would have counted veterancy as training); the face's strength tag shows for veterans too.
- Fixture fix after approval: `veteran_engine`'s event deck dropped the Horde (it was drawn before the third Raiders
  and blocked it), and `raid_again` also finds Raiders in the deck after a reshuffle. No assertion changed.
- Follow-ups: a trained veteran's details read "Strength 4 (printed 2, +1 training)" plus "Veteran 1 (+1 strength)";
  folding both into one line would read better. The territory view shows no veteran pips yet (Manual check), and
  GenericBot doesn't value veterancy. Balance: veterans make a held garrison stronger each repel; worth a
  `scripts/sim.sh --level 2 --compare <main checkout>` run.
