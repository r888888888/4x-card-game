---
id: 162
title: Barbarian raids, announced a turn ahead
type: feature
status: in-progress
branch: feat/162-barbarian-raids
---

## Goal
The first military threat. Some events are **raids**: drawn in the event phase, they name the territory they will
hit, and the next event phase they strike it. The player has a turn to answer (recruit, build walls, move units in
163). A raid that meets enough defence is repelled for a reward; otherwise it pillages. Everything is deterministic and
forecast, with no choice during upkeep. Follows 161.

## Acceptance criteria
- [ ] AC1 (loader): An event may set `raid` `{strength (int ≥ 1, required), targets (config keywords, optional),
  pop (int ≥ 0, default 1)}`; a bad field is a load error naming file, card and field; `raid` on another type is ignored
  with a warning. A raid with `discard` is a load error (it lasts until it strikes). Effects with trigger `repel` or
  `pillage` are allowed only on a raid (load error elsewhere) and only with upkeep-safe ops (`Effect.upkeep_ok`).
- [ ] AC2 (announce): When the event phase draws a raid, it becomes active, its `play` effects resolve, and its
  target is fixed (`raid_target(uid)`): among settled territories with any of `targets` (all settled territories when
  none match or `targets` is empty), the one with the lowest `defense`, ties to the most pop, then tableau order. With
  Homeland (defense 0, 3 pop) and Hills (mountain, defense 0, 1 pop), Raiders targeting mountain picks Hills; with no
  targets it picks Homeland.
- [ ] AC3 (timing): An active raid doesn't count down at upkeep. At the next `end_turn`, before the new event is drawn,
  each raid drawn on an earlier turn strikes, in the order drawn, then goes to `event_discard`; `raid_resolved(outcome)`
  is emitted with `{uid, target, strength, defense, repelled, units_lost, pop_lost, gained, lost, vp}`. The target
  stays fixed even if defence changes elsewhere meanwhile.
- [ ] AC4 (repelled): Given Raiders (strength 3; repel: +2 wealth, −1 unrest) aimed at Hills and Hills' defence 3 when
  it strikes, then it is repelled: wealth +2, unrest −1, no pop is lost and the units on Hills stay.
- [ ] AC5 (pillaged): Given the same raid and Hills' defence 2 (a Levy stationed there), then its `pillage` effects
  resolve (e.g. −2 food, +1 unrest), Hills loses `pop` pop (1, never below 0), the Levy goes to the discard and units
  stationed elsewhere are untouched.
- [ ] AC6 (forecast): `raid_forecast()` lists each announced raid as `{uid, target, strength, defense}` with the
  target's current defence; after recruiting a Levy on the target during play, its `defense` is 2 higher. It is `[]`
  with no raid active.
- [ ] AC7 (end of game): A raid announced earlier still strikes in the final turn's event phase; a raid drawn in the
  final turn never strikes. `fork()` copies each raid's target.

## Out of scope
- Moving units to answer a raid (163); veterans from a repelled raid (165); occupation and rivals; the bot (168).
- Raids that hit several territories, or casualties on the units' homes (considered; for now a lost garrison returns
  to the discard and the civilians on the target pay the pop).

## Design notes
- `raid` in `DataLoader.TYPE_FIELDS` (`[CardDef.EVENT]`). New effect triggers `repel` and `pillage`, validated like
  `upkeep` (no choice, no target); they resolve on the raid with the outcome collecting gained/lost/vp.
- The target is stored on the event's `CardInstance` (e.g. `territory_uid`, which events don't otherwise use).
- New API: `raid_target(uid)`, `raid_forecast()`, signal `raid_resolved(outcome)`. Strike step lives in the military
  module (161) and `Events`; `Events.resolve_upkeep` skips raids as it skips the Famine.
- Unrest from raids comes from the card data (repel/pillage effects), not an engine rule.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_raids::test_raid_loads_on_an_event`, `test_bad_raid_is_a_load_error`, `test_repel_and_pillage_effects_only_go_on_raids`; added: `test_raid_text` |
| AC2 | `test_raids::test_a_drawn_raid_is_announced_at_the_weakest_matching_territory`, `test_a_raid_with_no_targets_picks_the_weakest_then_the_most_pop`, `test_a_raid_whose_targets_match_nothing_picks_among_all_territories`, `test_a_raid_avoids_stronger_land_and_breaks_full_ties_by_tableau_order`, `test_raid_target_is_minus_1_for_anything_but_an_active_raid` |
| AC3 | `test_raids::test_a_raid_strikes_at_the_next_event_phase_then_is_discarded`, `test_the_target_stays_fixed_when_defence_changes_elsewhere` |
| AC4 | `test_raids::test_a_raid_meeting_enough_defence_is_repelled` |
| AC5 | `test_raids::test_a_raid_short_of_defence_pillages`, `test_pillage_never_takes_pop_below_0` |
| AC6 | `test_raids::test_raid_forecast_lists_announced_raids_with_live_defence` |
| AC7 | `test_raids::test_a_raid_strikes_in_the_final_turn_and_one_drawn_then_never_does`, `test_a_fork_keeps_each_raids_target` |

## Manual check
- [ ] Shipped era-1 raids in `event_deck`: Raiders (strength 2, grassland/desert; pillage −2 food, +1 unrest; repel
  +2 wealth, −1 unrest), Sea Raiders (3, coastal; pillage −3 wealth), Hill Tribes (3, hills/mountain; pillage −2 food,
  −1 wealth).
- [ ] The raid's event modal says which territory it will hit and compares strength with defence ("Raiders will
  strike Steppe next turn: 3 against your 1").
- [ ] An announced raid in the Realm row shows its target and "3 vs 1", in the warning colour while defence is short;
  the target territory card is marked.
- [ ] When it strikes, a modal or toast says repelled or pillaged and what it cost or gave.

## Log
- Balance worry: era-1 raids before Warriors are bought. Capital defence and terrain should cover strength 2; check in
  a balance item.
