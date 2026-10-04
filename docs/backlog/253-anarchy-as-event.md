---
id: 253
title: Anarchy is an event with its counters on show
type: feature
status: in-progress
branch: feat/253-anarchy-as-event
---

## Goal
Anarchy today is a government card that replaces the ruling one, and its counters (how many turns it has left) are
never shown, so a player can't tell how long it will last or whether it ended and fell again. Make Anarchy an event,
like the Famine: it sits in the active events with its counters on its face, while the government slot stands empty
and the fallen government waits in the government deck. Everything Anarchy does (restrictions, drain, renewal, restore
order, burning out into the government choice) stays as it is.

## Acceptance criteria
- [ ] AC1: Given a game whose config has unrest.anarchy set to an event card and Chiefdom ruling (unrest limit 5), when a
  turn starts with unrest at 5, then the Anarchy event is in `active_events`, `government()` is -1, Chiefdom is in the
  `governments` zone, `anarchy()` is the event's uid and `anarchy_counters()` is 4 (max_counters 4).
- [ ] AC2: Given Anarchy active with 3 counters left, then `event_counters(anarchy uid)` is 3; after one end of turn it
  is 2. (The Famine's `event_counters` is unchanged.)
- [ ] AC3: Given Anarchy active with `discard` turns unset, when upkeeps pass, then `Events.resolve_upkeep` resolves its
  upkeep effects but neither counts it down nor discards it; it leaves `active_events` only when it burns out or order is restored, and goes to
  `removed` (never to `event_discard`, never back into the event deck).
- [ ] AC4: Given Anarchy active and no government ruling, then `actions_per_turn()` is 1 plus the actions modifier (1
  with none, 2 with a +1 actions tech), as the Anarchy government gave before.
- [ ] AC5: Given Anarchy active, then the existing Anarchy rules hold unchanged: only order-tagged cards can be played,
  grow/buy/research refuse with Anarchy's build error, the drain and renewal run at turn start, `restore_order` works
  from Anarchy's second turn for c × (c + 1) wealth, and burning out or restoring order owes the government choice
  (`pending().kind == PENDING_GOVERNMENT`) with the old government among the options.
- [ ] AC6: Loader: `unrest.anarchy` must name an event card ("unrest.anarchy '<id>' is not an event"), with no
  `discard` ("unrest.anarchy '<id>' can't have a discard (Anarchy ends when its counters run out)"), and not in
  `event_deck` ("unrest.anarchy '<id>' can't be in event_deck"). A government there is now refused. An event may carry
  a `quote` (Anarchy keeps its Yeats line for the revolt modal).
- [ ] AC7: A revolution (`revolt`) brings the event the same way at the next turn's start, and `copy()` keeps the active
  Anarchy and its counters (the state-copy guard passes).

## Out of scope
- Which government the choice offers first or focuses: item 254.
- Numbers (max_counters, drain_pct, renewal, relief prices) and the unrest that piles back up after Anarchy: balance.
- The bot's Anarchy play beyond following the engine's queries.

## Design notes
- Data: `anarchy` in `data/cards.json` becomes `"type": "event"` with no `actions`, no `discard`, and `"modifiers":
  {"actions": 1}`; its `text` keeps describing the rules (it no longer says it rules as a government). It stays out of
  `event_deck`, like the Famine.
- Actions: `CardPlay.actions_per_turn` with an empty government slot returns -1 (unlimited) today; while Anarchy is
  active it counts from 0 plus the actions modifier (the event's +1 included), never below 1. No-government games
  without Anarchy stay unlimited.
- `Anarchy.active` looks in `active_events` (as `Famine.active` does); `_fall` moves the government to `governments`
  and adds the event to `active_events`; `_end` moves the event to `removed`. `Events.resolve_upkeep` skips it like
  the Famine and raids. `event_counters(uid)` returns Anarchy's `counters_left` for its uid.
- `anarchy_id()` keeps returning the config id (the revolt modal shows its flavor). `unrest_limit()` is -1 with no
  government, as with the Anarchy government now.
- UI: the board's active-events row already shows `event_counters` ("3 counters"). The sidebar's government button
  keeps reading "ANARCHY ›" while Anarchy is active and no government rules (the name comes from the engine, not a
  literal).
- Loader: the unrest.anarchy checks "can't set unrest_limit" and "can't be starting.government" become unreachable (an
  event can't have either) and go, with their test cases. `quote` joins `TYPE_FIELDS` for events.
- Engine-wide: ~40 files mention Anarchy; tests 145/147/154/155/156 that check `government()` is Anarchy move to
  checking `anarchy()` / `active_events`.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_anarchy_event::test_anarchy_falls_into_the_active_events_and_the_government_slot_empties` |
| AC2 | `test_anarchy_event::test_anarchys_event_counters_are_its_counters_left` |
| AC3 | `test_anarchy_event::test_upkeep_neither_counts_anarchy_down_nor_discards_it`, `::test_restoring_order_removes_the_anarchy_event`, `test_anarchy::test_each_turn_of_anarchy_takes_a_pop` (upkeep effects still resolve) |
| AC4 | `test_anarchy_event::test_anarchy_gives_1_action_plus_the_actions_modifier` |
| AC5 | the existing suites, on the Anarchy fixture now an event: `test_anarchy`, `test_anarchy_length`, `test_anarchy_drain`, `test_renewal`, `test_leaving_anarchy`, `test_government_deck`, `test_revolution` |
| AC6 | `test_anarchy_event::test_unrest_anarchy_must_be_an_event_outside_the_event_deck`, `::test_an_event_may_carry_a_quote`, `test_anarchy::test_unrest_block_validation` |
| AC7 | `test_anarchy_event::test_a_revolution_brings_the_anarchy_event`, `::test_a_copy_keeps_the_active_anarchy_and_its_counters` |

## Manual check
- [ ] Fall into Anarchy (egypt, seed 5, revolt from the civilization modal): the Anarchy card shows among the events
  with "4 counters", counting down each turn.
- [ ] While Anarchy is active, the government slot and top-bar government button read as having no government.
- [ ] When it ends, the government overlay comes up and nothing else can be done until a government is chosen.

## Log
- Balance worry (from the seed 5 probe): unrest kept rising during Anarchy (6 → 9) despite renewal, so calming never
  shortens it, and it was back to 4 of 5 two turns after Chiefdom returned. For a balance item.
