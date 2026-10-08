---
id: 416
title: Events whose preconditions aren't met are discarded unseen
type: feature
status: in-progress
branch: feat/416-event-preconditions
---

## Goal
An event that can't apply to the realm (Beached Whale with no coast, Sea Raiders with no coastal territory) is never
the turn's event: it is quietly discarded and the next event is drawn, so every event the player sees means something.

## Acceptance criteria
- [ ] AC1: Given a `TEST_CARDS` event with `"requires": ["coastal"]` on top of the event deck and an ordinary event
  under it, and no settled territory with `coastal`, when the turn's event is drawn, then the requires event is in
  `event_discard`, the ordinary event is in `active_events`, `event_drawn` is emitted once (for the ordinary event),
  and the requires event's play effects did not resolve.
- [ ] AC2: Given the same event and a settled territory with `coastal` (any one of the listed keywords is enough), when
  the turn's event is drawn, then it is active and its play effects resolve. A territory still on the frontier
  (unsettled) does not count.
- [ ] AC3: Given a raid whose `targets` match no settled territory on top of the event deck (raids allowed) and an
  ordinary event under it, when the turn's event is drawn, then the raid goes to `event_discard` without
  `event_drawn` for it, no raid target, no `raid_gap` started (`last_raid_turn` unchanged), and the ordinary event is
  the turn's event. This replaces 372's fizzle (a raid with no target was still the turn's event).
- [ ] AC4: Given a raid while raids aren't allowed (257 pacing), when drawn, then it still goes to the event deck's
  bottom, not the discard (pacing is unchanged; the precondition is checked only for a card pacing lets through).
- [ ] AC5: Given an event deck holding only unmet events and an event discard holding one ordinary event, when the
  turn's event is drawn, then the unmet events go to the discard, the discard is shuffled in once, and an event whose
  precondition holds becomes the turn's event; given no such event in either pile, then no event that turn (no
  `event_drawn`) and the draw ends (each card is checked at most once per pile pass, no loop).
- [ ] AC6: Loader: `requires` on an event is accepted (known keyword ids, the building rules); an unknown keyword is a
  load error naming the card and field. `requires` on a raid is a load error (its `targets` are its precondition).
  The card text and tooltip show the requirement as for buildings.
- [ ] AC7 (content invariant): every shipped event whose play or upkeep effects are all `gain_per_keyword` /
  `lose_per_keyword` on keywords K has `requires` covering K (it would do nothing without them).

## Out of scope
- Preconditions other than terrain keywords (pop, resources, buildings); a richer condition object can follow.
- Showing the discard to the player: no log notice, modal or sound (the internal log line may stay).
- Changing raid pacing (257) or the event deck's era rules.

## Design notes
- Data: `requires` (array of keyword ids) joins `DataLoader.TYPE_FIELDS` for `CardDef.EVENT` (follow the
  `add-card-field` skill; the field and `_requires` parse already exist for buildings). Met when any settled territory
  has any of the keywords; empty means always met.
- A raid's precondition is `Military.aim(event) != null` (some settled territory matches its targets).
- Engine: `Events.draw` / `_take_allowed` gain the check; an unmet card goes to `event_discard` and the draw goes on.
  Suggested query `Events.precondition_met(e, card) -> bool` (or on the events area) so the UI or bot could ask.
- 372's three tests in `tests/test_raids.gd` (`test_bug_372_*`) describe the fizzle; replace them with AC3's tests in
  this item and remove the fizzle branch in `Events.draw`. Update PLAN.md's Events section (372 sentence, 266
  reshuffle wording).
- Content (Manual check): `requires: ["coastal"]` on Tuna Run, Beached Whale, Shipwreck Salvage, Busy Harbours, Storm
  at Sea; `requires: ["flood_plain"]` on Silt Flood. Drought hits desert/grassland only by upkeep; give it
  `["desert", "grassland"]` too.
- Sim: the bot draws through the same engine path, so nothing to add; event mix per game shifts toward met events.
  Balance worry: harmful keyword events (Storm at Sea, Drought) now skip realms they'd miss, and helpful ones too, so
  inland civs see more of the other events. `scripts/sim.sh --level 3 --compare <main checkout>` would show it.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_event_preconditions::test_an_event_whose_requires_no_settled_territory_has_is_discarded_unseen` |
| AC2 | `test_event_preconditions::test_an_event_whose_requires_a_settled_territory_has_resolves`, `test_any_one_of_the_required_keywords_is_enough`, `test_a_frontier_territory_does_not_meet_requires` |
| AC3 | `test_raids::test_a_raid_whose_targets_match_nothing_is_discarded_unseen_and_the_next_event_drawn` (replaces `test_bug_372_a_fizzled_raid_is_still_the_turns_event`); the other two `test_bug_372_*` tests still hold |
| AC4 | `test_event_preconditions::test_a_raid_held_back_by_pacing_goes_to_the_deck_bottom_not_the_discard` |
| AC5 | `test_event_preconditions::test_unmet_events_are_discarded_and_the_discard_reshuffled_once_for_a_met_one`, `test_no_event_when_no_event_in_either_pile_is_met` |
| AC6 | `test_event_preconditions::test_requires_loads_on_an_event`, `test_bad_requires_on_an_event_is_a_load_error`, `test_an_events_text_shows_what_it_requires` |
| AC7 | `test_content::test_real_events_that_only_count_keywords_require_them` |

## Manual check
- [ ] Shipped `requires` on the events listed in Design notes.
- [ ] Start an inland game (no coastal territory), play to era 2: no coastal event or Sea Raiders/Pirates modal ever
  appears, and no modal or notice mentions a discarded event.

## Log
