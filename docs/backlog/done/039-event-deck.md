---
id: 039
title: Event deck and event cards (framework)
type: feature
status: done
branch: feat/039-event-deck
---

## Goal
Replace the event-phase stub with a real event deck. Each turn's event phase draws one random event
card. An event is active until its discard condition is met, which is checked at upkeep. While active,
its upkeep effects fire each upkeep. A single-turn event is one whose condition is met at the next
upkeep. This is the base for solo opposition (PLAN.md: "Event/barbarian deck that escalates by era").
This item builds only the framework. Real events, harmful ops and the event UI come later.

## Acceptance criteria
Fixture events added to TEST_CARDS (existing ops only):
- `windfall`: "Windfall", event, play: +2 food, `discard: {"turns": 1}`
- `trade_winds`: "Trade Winds", event, upkeep: +1 wealth, `discard: {"turns": 2}`
- `omen`: "Omen", event, no effects, no `discard` field (defaults to turns 1)

Unless stated otherwise, the config has `event_deck: {windfall: 1, trade_winds: 1, omen: 1}`, and
tests set the event deck order directly when it matters ("top first").

- [x] AC1 (event cards load): card type `event` is valid. `discard` is optional and defaults to
  `{"turns": 1}`. `turns` must be an integer ≥ 1, and `{"turns": 0}`, `{"turns": "x"}`,
  `{"until": 3}` (unknown condition) and a non-object `discard` are each a load error that names the
  card and `discard`. An event with a `cost` or a non-zero `vp` is a load error that names the card and
  the field. An event effect with a `keyword`, or one that needs a target (`settle`), is a load error
  that names the card and the effect index. An event `upkeep` effect whose op fails `upkeep_ok()` is a
  load error, as for any other card. `discard` on a card that isn't an event gives an
  unknown-field warning, not an error.
- [x] AC2 (config): `event_deck` is optional ({event_id: count}, default {}). An unknown id, a card that
  isn't an event, or a count below 1 is a load error that names config.json and `event_deck`. An event
  listed in `deck` is a load error that names `deck`. An event in `supply` is a load error, like any
  other type the supply doesn't sell.
- [x] AC3 (setup): In a new game, the `event_deck` zone holds the 3 events in a shuffled order that
  depends only on the seed (same seed, same order). `active_events` and `event_discard` are empty.
  With no `event_deck` in the config, all three zones are empty and end turn works as before.
- [x] AC4 (draw in the event phase): Given the event deck [windfall, trade_winds, omen] (top first) and
  2 food on turn 1, when I call `end_turn()`, then Windfall is drawn before cleanup. Its play effects
  resolve (food is 2 + 2 = 4 before turn 2's upkeep). It is in `active_events` with
  `event_turns_left(uid)` 1, and the event deck holds 2 cards. Exactly one event is drawn per
  `end_turn()`. Over the hand limit, the event is drawn once when end_turn is called, not again when
  the last discard finishes the turn. The final turn also draws an event.
- [x] AC5 (upkeep and discard): Given Trade Winds is drawn at the end of turn 1, then:
  - at turn 2's upkeep it gives +1 wealth and `event_turns_left` becomes 1, and it stays in `active_events`
  - at turn 3's upkeep it gives +1 wealth again, then it moves to `event_discard`
  - at turn 4's upkeep it gives nothing.

  An event's upkeep effects resolve after tableau and researched upkeep and before pop eats. The discard
  check runs after the event's upkeep effects, so an event always gives every upkeep it lasted for.
  `upkeep_forecast()` includes active events' upkeep effects (Trade Winds active: wealth +1 in the
  forecast), and calling it leaves `active_events`, `event_discard` and `event_turns_left` unchanged.
- [x] AC6 (single-turn and several active): Windfall (turns 1) drawn at the end of turn 1 is in
  `event_discard` after turn 2's upkeep. Several events can be active at once. With Trade Winds drawn at
  the end of turn 1 and Omen at the end of turn 2, both are in `active_events` during turn 2's play
  phase, in draw order. Active events never score VP and are never in the hand, the tableau or the
  main discard.
- [x] AC7 (empty event deck): When the event deck is empty in the event phase, `event_discard` is
  shuffled back into the event deck with the engine rng (seeded), and the top card is drawn. When both
  are empty (every event is active, or there is no event deck), nothing is drawn and the turn ends
  normally.

## Out of scope
- Real event content in `data/`, and escalation by era (for example, a per-era event deck, as with techs).
- Harmful ops (lose resources, lose pop, destroy a building) and rule modifiers (for example, "buildings
  cost +1").
- Discard conditions other than duration: resource or pop thresholds, a tag or card on the tableau, or
  paying to discard.
- UI: an event panel, active events on the board, and the event deck count. The event log lines are
  enough to try it until then.
- A separate `event` trigger (PLAN.md mentions one). Events use `play` (when drawn) and `upkeep`.

## Design notes
- Card type `event`: add it to `CARD_TYPES` and `SEPARATE_DECK_TYPES`. It is not permanent in the
  tableau sense and never enters the main deck.
- New constant `CardDef.EVENT`. New card field `discard` (object), declared in `DataLoader.TYPE_FIELDS`
  as `discard: [CardDef.EVENT]`. For now its only key is `turns` (int ≥ 1, default 1). Store it as
  `CardDef.discard_turns`, and later conditions go in new keys. Card text gets a generated line:
  "Lasts 1 turn" / "Lasts 2 turns".
- Config: `event_deck` {event_id: count}, parsed with `_parse_counts(..., "event")`.
- New zones: `event_deck`, `active_events`, `event_discard`. `CardInstance.turns_left` (int).
- Engine API:
  - `event_turns_left(uid) -> int`: upkeeps left for an active event (0 if uid isn't active).
  - `_event_phase()`: draws one event (reshuffling `event_discard` if needed), puts it in
    `active_events` with `turns_left = discard_turns`, logs "Event: Windfall.", and resolves its `play`
    effects with the event as source.
  - `_resolve_upkeep()`: after tableau and researched cards, it resolves each active event's `upkeep`
    effects, lowers `turns_left` by 1, and moves events at 0 to `event_discard` (logs "Windfall ends.").
    `upkeep_forecast` runs on a `GameEngine.fork()`, so `GameState.copy()` must copy the event zones
    and `CardInstance.turns_left`.
- The event phase already runs once per `end_turn()`, before the hand-limit discard. Keep it there.
- Follow-ups to spec: event UI panel, harmful ops, threshold/tag discard conditions, era-escalating event
  content.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_events::test_event_loads_with_discard_turns`, `test_event_discard_defaults_to_one_turn`, `test_event_card_validation`, `test_discard_on_a_non_event_is_a_warning`, `test_event_text_says_how_long_it_lasts` |
| AC2 | `test_events::test_event_deck_is_normalized`, `test_event_deck_defaults_to_empty`, `test_event_deck_validation` |
| AC3 | `test_events::test_new_game_shuffles_the_event_deck_by_seed`, `test_no_event_deck_leaves_the_event_zones_empty` |
| AC4 | `test_events::test_end_turn_draws_the_top_event_and_resolves_it_before_cleanup`, `test_finishing_the_discard_does_not_draw_another_event`, `test_each_end_turn_draws_exactly_one_event`, `test_the_final_turn_draws_an_event`, `test_event_turns_left_is_zero_for_a_card_that_is_not_active` |
| AC5 | `test_events::test_an_active_event_gives_its_upkeep_every_turn_it_lasts`, `test_event_upkeep_resolves_before_pop_eats`, `test_forecast_includes_active_event_upkeep`, `test_forecast_leaves_the_event_zones_alone` |
| AC6 | `test_events::test_a_single_turn_event_ends_at_the_next_upkeep`, `test_several_events_can_be_active_in_draw_order`, `test_active_events_score_no_vp` |
| AC7 | `test_events::test_empty_event_deck_reshuffles_the_event_discard_by_seed`, `test_nothing_is_drawn_when_both_event_piles_are_empty` |

## Log
- Red: fixture events live in `tests/test_events.gd` (`EVENTS`, like `tech_case.gd`'s `TECHS`), not `TEST_CARDS`:
  `event` isn't a valid type yet, so adding them to `TEST_CARDS` would break every test's `make_engine`. Added a
  fourth fixture, `harvest` (upkeep +1 food, 2 turns), to test that event upkeep resolves before pop eats.
- Red: AC6 said both events are active "during turn 2's play phase", but Omen is drawn at the end of turn 2.
  The test checks both are active right after Omen is drawn (end of turn 2, before turn 3's upkeep).
- Green: `test_nothing_is_drawn_when_both_event_piles_are_empty` checked after turn 3's upkeep, when Trade Winds
  had rightly ended; with approval it now checks at the hand-limit pause right after the empty event phase.
- Built: `engine/events.gd` (`Events.setup`, `draw`, `resolve_upkeep`, `turns_left`); `TurnLoop` calls it in
  place of the old `_event_phase` stub. Loader: `CardDef.EVENT`, `discard` in `TYPE_FIELDS`, `NO_TERRITORY_TYPES`
  (techs and events share the keyword/target rule, was `_tech_effect_problem`), `event_deck` config.
- No manual check: `data/` has no events yet, so nothing changes in the game. The log shows "Event: X." and
  "X ends." once content exists.
- Follow-ups: event UI panel (active events, deck count), "Lasts n turns" in the full tooltip (`rules_tooltip`),
  harmful ops, threshold/tag discard conditions, era-escalating event content.
