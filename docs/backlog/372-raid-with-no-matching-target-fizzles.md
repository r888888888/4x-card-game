---
id: 372
title: A raid whose targets match no territory still strikes one
type: bug
status: in-progress
branch: fix/372-raid-no-target-fizzles
---

## Reproduction
- Seed: any; reproduced from the rules (162 AC2 made it the intended behavior, so this is a rule change).
- Steps:
  1. Have no settled territory with `hills` or `mountain`.
  2. Draw Hill Tribes (`raid.targets` `["hills", "mountain"]`).
- Expected: the raid has nothing to strike and does nothing.
- Actual: `Military.announce` falls back to every settled territory and aims at the weakest (Homeland), which is
  then pillaged.

## Acceptance criteria
- [ ] AC1: Given `TEST_CARDS` Raiders (targets `mountain`) and no settled mountain territory (Hills back in the
  territory deck), when Raiders is drawn as the turn's event, then it goes straight to `event_discard`: it isn't in
  `active_events`, `raid_target(uid)` is -1, `raid_forecast()` is `[]`, no caution notice is posted, and its `play` effects don't resolve (Raiders' +1
  insight isn't gained).
- [ ] AC2: Given AC1's fizzled raid, when the turns pass that would have brought its strike, then `raid_resolved` is
  never emitted, Homeland's pop and units are unchanged, resources are unchanged by it (no pillage or repel effects
  resolve), and `last_raid_turn` stays 0 (a fizzle starts no `raid_gap`).
- [ ] AC3: Given AC1, the fizzled raid was still the turn's event: `event_drawn` is emitted for it and no second event
  is drawn that turn.
- [ ] AC4: A raid with empty `targets` still aims at the weakest of all settled territories
  (`test_a_raid_with_no_targets_picks_the_weakest_then_the_most_pop` stays green), and a raid with a matching
  territory still aims at the weakest match.
- [ ] AC5: The fallback is gone: `test_raids::test_a_raid_whose_targets_match_nothing_picks_among_all_territories`
  is replaced by AC1's test, and 162's AC2 text and PLAN.md describe the new rule.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_raids::test_bug_372_a_raid_whose_targets_match_nothing_fizzles_into_the_discard` |
| AC2 | `test_raids::test_bug_372_a_fizzled_raid_never_strikes_or_starts_the_raid_gap` |
| AC3 | `test_raids::test_bug_372_a_fizzled_raid_is_still_the_turns_event` (passes already: guards the fix) |
| AC4 | `test_raids::test_a_drawn_raid_is_announced_at_the_weakest_matching_territory`, `test_a_raid_with_no_targets_picks_the_weakest_then_the_most_pop` (existing) |
| AC5 | `test_a_raid_whose_targets_match_nothing_picks_among_all_territories` removed; docs at close |

## Design notes
- Change is in `Military.announce` / `Events.draw`: with non-empty `targets` and no settled match, discard the raid
  instead of announcing it. No data format change; no new API.
- No raid in `data/cards.json` has `play` effects today, so skipping effects only concerns pillage/repel.
- Sim: `GenericBot` sees raids through `raid_forecast`/`turn_forecast`, so a fizzle simply shows no threat.
- Balance worry (not tuned here): targeted raids get rarer for realms lacking their terrain; note in the Log.

## Root cause
<!-- Filled in by Claude after the fix. -->

## Manual check
- Draw a targeted raid with no matching territory: the event log shows it, no announcement, no Realm-row warning,
  no raid modal.

## Log
- 2026-10-06: Reported by the user; they chose "fizzles" over a notice or waiting for a target.
