---
id: 257
title: Raids wait for a large enough realm, warn 2 turns ahead and come further apart
type: feature
status: review
branch: feat/257-raid-pacing
---

## Goal
Raids now arrive from turn 2 whatever the realm looks like, strike one turn after they're announced, and can come
back to back. A small realm can't defend itself in time. After this, raids only begin once the civilization has grown
to a minimum size (by what its territories, cities, buildings and units are worth), each raid gives 2 turns to
prepare, and a quiet stretch follows each strike.

## Acceptance criteria
- [x] AC1 (size): Given a tableau with 2 settled territories, a city costing 2 wealth, a building costing 1 food and
  2 wealth and a unit costing 2 food, and config `territory_value` 3, when `realm_size()` is read, then it is 13
  (3 + 3 + 2 + 3 + 2). Idle cards in the tableau count; cards in hand, deck or discard, pop, techs, the civilization
  and the government add nothing.
- [x] AC2 (size gate): Given config `raid_min_size` 15 and an event deck whose top is a raid and next a non-raid
  event, when the turn's event is drawn with `realm_size()` 14, then the non-raid event is drawn and made active, the
  raid is at the bottom of the event deck and isn't active, and `event_drawn` reports the non-raid event only. With
  `realm_size()` 15 the raid is drawn and announced as now.
- [x] AC3 (only raids left): Given raids aren't allowed and the event deck and discard hold only raids, when the turn's
  event is drawn, then no event becomes active, `event_drawn` isn't emitted, and the raids stay in the event deck
  (none lost, none in the discard).
- [x] AC4 (2-turn warning): Given a raid drawn and announced at turn T's event phase, then it doesn't strike at turn
  T+1's start (still active, `raid_target` unchanged), and strikes at turn T+2's start before that turn's event is
  drawn. A raid drawn on the final turn or the turn before never strikes. `raid_turns_left(uid)` is 2 on turn T, 1 on
  turn T+1, and 0 for anything not an active raid.
- [x] AC5 (gap): Given config `raid_gap` 4 and a raid that struck at turn S, when a raid tops the event deck at turns
  S to S+3, then it is deferred as in AC2; at turn S+4 it is drawn and announced. Before any raid has struck there is
  no gap. `copy()` keeps the turn of the last strike.
- [x] AC5b (one at a time): Given a raid is active (announced, not yet struck), when another raid tops the event deck,
  then it is deferred as in AC2, whatever the size and gap; at most one raid is ever active.
- [x] AC6 (text): `raid_line`, `raid_warning` and the raid's card text say "in 2 turns" while 2 turns are left and
  "next turn" at 1 ("Raiders will strike Hills in 2 turns: 3 against your 0."; "Raiders strike in 2 turns: 3 vs 0";
  card text "Raid 3: strikes your least defended hills or mountain territory 2 turns after it is drawn").

## Out of scope
- The sim bot's response to raids (168); it ignores raids today and still will.
- Tuning the shipped numbers beyond the defaults below; balance is a later item.
- Bandit Raids (a plain unrest event, not a raid) is unaffected.

## Design notes
- Config (`data/config.json`, validated by the loader, all ints ≥ 0, optional): `territory_value` (default 0),
  `raid_min_size` (default 0: no gate), `raid_gap` (default 0: no gap). Defaults keep today's gating off for test
  fixtures that don't set them; the 2-turn warning applies always.
- Value of a card = the sum of its `cost` amounts (all resources); a settled territory = `territory_value`.
  Counted: territories, cities, buildings, units in the tableau.
- New engine API: `realm_size() -> int`, `raids_allowed() -> bool` (size and gap and no announced raid),
  `raid_turns_left(uid) -> int`. Rules in `Military`; `Events.draw` skips deferred raids to the deck bottom, at most
  once each per draw, so a deck of only raids ends the loop.
- State: `GameState.last_raid_turn` (0 = none yet), set in `Military.strike_raids`; the raid's countdown can live in
  its `turns_left` (raids skip upkeep's countdown already).
- `raid_resolved` and the strike rules are unchanged.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| config | `test_raid_pacing::test_raid_pacing_config_defaults_to_0_and_rejects_negatives` |
| AC1 | `test_raid_pacing::test_realm_size_counts_territories_and_the_cost_of_cities_buildings_and_units` |
| AC2 | `test_raid_pacing::test_a_raid_drawn_while_the_realm_is_too_small_goes_to_the_bottom_and_the_next_event_is_drawn`, `test_a_raid_is_drawn_once_the_realm_reaches_the_minimum` |
| AC3 | `test_raid_pacing::test_with_only_raids_left_and_none_allowed_no_event_is_drawn` |
| AC4 | `test_raids::test_a_raid_strikes_two_event_phases_after_it_is_drawn_then_is_discarded`, `test_raids::test_a_raid_strikes_in_the_final_turn_and_one_drawn_then_never_does`, `test_raid_pacing::test_raid_turns_left_counts_down_from_2`, `test_a_raid_drawn_on_the_turn_before_the_final_turn_never_strikes` |
| AC5 | `test_raid_pacing::test_no_raid_is_drawn_until_raid_gap_turns_after_the_last_strike`, `test_a_fork_keeps_the_gap` |
| AC5b | `test_raid_pacing::test_a_raid_drawn_while_another_is_active_is_deferred` |
| AC6 | `test_raid_pacing::test_raid_text_says_in_2_turns_then_next_turn`, `test_raids::test_raid_line_tag_and_shortfall_for_the_ui` |

## Manual check
- [ ] Shipped numbers for review: `territory_value` 3, `raid_min_size` 12, `raid_gap` 4. Start a game: no raid is
  announced until the realm reaches 12: count 3 per settled territory plus the printed cost of each city, building
  and unit on the board. Raiders, Sea Raiders and Hill Tribes should start appearing only after a second territory
  and a few buildings; after a strike, none for 4 turns.
- [ ] An announced raid's board card and its target's tooltip say "in 2 turns", then "next turn".

## Log
<!-- Decisions and surprises during implementation, newest last. -->
- Red: raid fixtures moved from `test_raids.gd` into `tests/lib/raid_case.gd` (shared with `test_raid_pacing.gd`).
  The existing strike tests in `test_raids.gd` get an extra `end_turn` before the strike (AC4).
- User: only one raid may be active at a time; shipped `raid_min_size` is 12.
- Balance worry: the starting realm (1 territory + city) sits under 12, so early unit and wall cards may feel
  useless for longer; revisit in a balance item.
- Green: two red tests were wrong and were fixed before production code relied on them: AC1's sum is 13, not 15
  (3 + 3 + 2 + 3 + 2; the spec had the same slip), and the AC4 strike test counted two active Omens, but Omen lasts
  one turn; it now checks the turn-4 event was drawn from the deck.
- `realm_size` and `raid_turns_left` sit in `game_engine.gd` beside the other military queries (`unit_strength`,
  `move_targets`): `engine_queries.gd` has a 500-line cap (249) and would have gone to 511.
- A raid deferred while the event deck is short is never swapped for a non-raid in the event discard (no reshuffle
  until the deck is empty); fine for now.
