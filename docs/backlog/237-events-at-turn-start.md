---
id: 237
title: Draw the turn's event at the start of the turn, from turn 2
type: feature
status: review
branch: feat/237-events-at-turn-start
---

## Goal
Today the event is drawn in `end_turn`, after the play phase, and the next upkeep counts it down. An event that lasts
N turns is active for only N − 1 play phases, so a one-turn event (most of the deck) is never in the Realm row while
you play and its modifiers never apply. Drawing it at the end of the turn start, from turn 2, lets you see each event
and play around it for every turn it lasts.

## Acceptance criteria
- [x] AC1: Given a new game (event deck not empty), when turn 1 starts, then no event is drawn: `active_events` is
  empty, the event deck keeps its size and `event_drawn` is not emitted.
- [x] AC2: Given turn 1 with an event deck, when the turn ends, then no event is drawn during `end_turn` and the event
  is drawn as turn 2 starts: after the turn starts, `active_events` holds the former top of the event deck, its `play`
  effects have resolved and `event_drawn` was emitted once.
- [x] AC3: Given an event that lasts 1 turn drawn at the start of turn 2, then it is active through turn 2's play
  phase (`turns_left` 1); when turn 3 starts, its `upkeep` effects resolve, it goes to `event_discard`, and the turn
  3 event is drawn after that.
- [x] AC4: Given an event with `modifiers` (e.g. +1 action) and `discard.turns` 2 drawn at the start of turn 2, then
  the modifier applies during the play phases of turns 2 and 3 and not turn 4.
- [x] AC5: Given unrest 1 below the limit and the event deck's top event gains 1 unrest on play, when the next turn
  starts, then unrest reaches the limit but Anarchy does not fall that turn (the event resolves after the
  `start_of_turn` check); when the turn after starts with unrest still at the limit, Anarchy falls.
- [x] AC6: Given Anarchy ruling with renewal owed at turn start and an event that gains food, when the turn starts,
  then renewal is pending with its usual count (an event drawn this turn adds no renewal modifier to it), the event's
  food is gained after the drain (not drained), and the event is in `active_events`.
- [x] AC7: Given the final turn (`turn_limit`), when it ends, then no event is drawn (the event deck keeps its size).
- [x] AC8: Given Anarchy burning out at the end of a turn (the government choice owed), when the government is chosen,
  then the next turn starts and its event is drawn exactly once.

## Out of scope
- Tuning event numbers or unrest limits (balance step).
- ScriptedBot's unrest margin (`_unrest_ok` adds +1 "for the event"): it still works, now slightly cautious. Revisit
  in a balance item.
- Events whose `play` needs a player choice: none exist; such an event would collide with a pending renewal.

## Design notes
- `TurnLoop.end_turn` stops calling `Events.draw`; `TurnLoop.start_turn` calls it last, after `Anarchy.start_renewal`,
  when `e.turn >= 2`. Turn order in PLAN.md (Turn loop, step 4) and the Realm row's events tooltip
  ("drawn at the end of each turn", `ui/tableau_view.gd`) change to match.
- `upkeep_forecast` now includes the active events' upkeep during the play phase (it did not see the event before).
- Turn 1's start goes through `start_turn` from `GameEngine.start`, so the turn ≥ 2 guard covers it.
- No data format change.

## Test plan
All in `tests/test_events_at_turn_start.gd` unless named.

| AC | Test |
|---|---|
| AC1 | `test_no_event_is_drawn_on_turn_1` (already passes: today's draw is in `end_turn`, so turn 1 has none; kept as a guard) |
| AC2 | `test_the_event_is_drawn_as_turn_2_starts`, `test_end_turn_draws_nothing_before_the_hand_limit_discard` |
| AC3 | `test_a_one_turn_event_is_active_through_its_turn_then_ends_at_the_next_upkeep` |
| AC4 | `test_an_events_modifier_applies_every_turn_it_lasts` |
| AC5 | `test_an_unrest_event_reaching_the_limit_lets_the_turn_play_before_anarchy` |
| AC6 | `test_an_event_drawn_under_anarchy_comes_after_the_drain_and_renewal`, `test_an_event_drawn_this_turn_adds_nothing_to_this_turns_renewal` |
| AC7 | `test_the_final_turn_draws_no_event` |
| AC8 | `test_anarchy_burning_out_draws_the_next_event_once_the_government_is_chosen` |

Existing tests changed to the new timing: `test_events` (removed `test_end_turn_draws_the_top_event_and_resolves_it_before_cleanup`
and `test_the_final_turn_draws_an_event`, superseded by AC2 and AC7; re-timed the upkeep, forecast, single-turn, notice, draw-order and
reshuffle tests), `test_event_panel::test_event_view_shows_its_turns_left` (2 turns left), `test_event_modal::test_the_hand_limit_discard_comes_before_the_event_modal`
(was `..._is_still_owed_after_the_modal`), `test_harmful_ops::test_a_drawn_event_with_lose_takes_food`, `test_modifiers::test_actions_per_turn_adds_the_actions_modifier`
(a Lull in the event deck, else the draw reshuffles Unrest back in) and `test_identity_lines::test_choosing_a_government_updates_the_sidebar_and_an_open_modal`
(closes the earlier turns' event modal first).

## Manual check
- [ ] `godot --path . -- --seed 5`: turn 1 shows no event modal. Press End turn: the event modal opens as turn 2
  starts, and after OK the event leads the Realm row with its turns-left badge (a 1-turn event says 1 turn left)
  while you play turn 2. Hover the row: "One event is drawn at the start of each turn from turn 2."
- [ ] Draw a one-turn event with a "while active" modifier (e.g. Calls for Reform under Anarchy, or any +action
  event): the modifier shows in effect during that turn.
- [ ] Declare a revolution with cards in the discard, end the turn: Anarchy falls, renewal is owed and the turn's
  event modal is on top; read it, press OK, then pay the renewal.
- [ ] Let Anarchy burn out (calm to 1 counter, end the turn): choose a government, then the next turn's event modal
  opens.

## Log
- Balance worries: every event gets one more play phase (harmful ones hit harder, e.g. `bandit_raids`, good ones
  help more), and unrest events no longer topple a government by surprise, so events become a softer source of
  Anarchy. One fewer event per game is drawn (the wasted draw at the end of the final turn).
- Built: `TurnLoop.end_turn` no longer draws; `start_turn` calls `Events.draw` last, from turn 2. No new API.
- The empty-event-deck reshuffle now runs right after upkeep, so an event that just ended can be reshuffled and drawn
  again the same turn start. That is the same sequence as before (discarded at an upkeep, then the next draw), one
  step earlier; `test_modifiers` needed a filler event because its game has no event deck.
- `ModalStack.push` on an already-open modal closes what is above it: if the previous turn's event modal is still
  open when the next event is drawn (only possible in tests, or by choosing a government from the identity modal
  without closing the event first), the identity modal above it closes. Not changed here.
- Follow-ups: ScriptedBot's `_unrest_ok` keeps a +1 margin "for the event", now only cautious (balance item).
  `engine/glossary.gd` says upkeep happens "at the end of each turn"; it runs at the start (pre-existing, not this
  item).
