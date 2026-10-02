---
id: 188
title: Counter and card sounds
type: feature
status: done
branch: feat/188-counter-and-card-sounds
---

## Goal
The two things the player watches most make the quietest sounds in the game ([docs/design/mcm-style-guide.md](../design/mcm-style-guide.md)
§10.3–10.5, §15.5–15.6): an odometer ticks as each digit lands and registers its new total with a small gain or loss
sound, and a card flicks as it is picked up, pats down as it lands and is refused with a low double tap. Upkeep becomes
audible as a short run of ticks without ever turning into a clatter.

## Acceptance criteria
- [x] AC1: An `Odometer` (181) rolling from 3 to 6 plays `Sfx.COUNTER_TICK` as the 4 and the 5 land (each at the end
  of its step) and, as the 6 lands, `Sfx.RESOURCE_GAIN` instead of a tick; rolling down from 6 to 3 plays two ticks
  and `Sfx.RESOURCE_LOSS`. The k-th tick of a roll (from 0) plays k dB quieter.
- [x] AC2: A roll of more than 8 steps ticks only for the 8 it shows: 12 → 40 plays 7 ticks and one gain; the jump
  from 12 to 32 is silent.
- [x] AC3: Counters that change in the same refresh share one tick stream: given an upkeep that takes food 3 → 5,
  wealth 1 → 4 and insight 0 → 2, every counter plays its gain, the gains play in counter order (food, wealth,
  insight), and no two ticks in `Sfx.played()` are closer than 0.035 s.
- [x] AC4: Nothing plays for a refresh that changes no figure, when a game starts or restarts, or when the Supply
  screen closes after buying (as 181's tags). With Reduce motion, a changed counter plays no ticks and one gain or
  loss.
- [x] AC5: Picking a card up to drag it plays `Sfx.CARD_LIFT` as the drag starts; a played card plays
  `Sfx.CARD_PLACE` when it lands in its slot (once, after any flight); a refused drop plays `Sfx.REJECT` as the card
  starts its shake. Hovering a card, moving it while dragged and the target highlights play nothing.
- [x] AC6: Clicking a card that then waits for a target (click-to-target) plays `Sfx.SELECTION`; cancelling the
  targeting plays nothing.

## Out of scope
- The turn number's split-flap and `Sfx.FLAP` (the turn plate isn't a split-flap yet); dealing piles (§15.13, not
  built); the tally pips of the grow meter (their own ticks can come with the meter's restyle).

## Design notes
- The odometer knows its own steps (181), so it plays its ticks; "the last step registers" is part of the odometer, not
  the top bar. The shared stream is `Sfx`'s tick rule (186), not a second limiter.
- Card sounds live in `CardMotion` where the lift, landing and shake already happen; `Sfx.CARD_PLACE` waits for the
  landing, so a card that flies to a slot sounds when it arrives, not when it is dropped.
- These are system sounds (`input` false) except the lift and the selection, which answer the player's own press.
- Builds on 179 (card motion), 181 (odometers) and 186.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_counter_and_card_sounds::test_an_odometer_ticks_each_step_and_registers_the_last` |
| AC2 | `test_a_long_roll_ticks_only_for_the_steps_it_shows` |
| AC3 | `test_counters_changed_together_share_one_tick_stream_and_register_in_order` |
| AC4 | `test_a_refresh_that_changes_nothing_a_new_game_and_a_restart_are_silent`, `test_closing_the_supply_screen_after_buying_is_silent`, `test_with_reduce_motion_a_change_registers_once_with_no_ticks` |
| AC5 | `test_picking_a_card_up_flicks_and_dragging_it_is_silent`, `test_a_played_building_pats_down_once_when_it_lands`, `test_a_building_played_into_the_open_territory_view_pats_down_in_its_slot`, `test_a_refused_drop_taps_twice_as_the_card_shakes` |
| AC6 | `test_a_click_that_waits_for_a_target_ticks_and_cancelling_is_silent` |

## Manual check
- [ ] Seed 5, Egypt: playing Barter ticks wealth up with a small registering clack; End turn's upkeep is a short,
  tidy run of ticks and registrations left to right.
- [ ] Dragging a card and playing it: a soft flick on pick-up, a pat on landing; dropping it somewhere it can't go
  gives a low double tap.
- [ ] Repetition (§16.8): 20 upkeeps back to back; 40 card plays. Nothing grates.

## Log
- 2026-10-02: Specced from the style guide's sound system. The game has no card selection as such, so
  `ui.selection` marks click-to-target.
- 2026-10-02: Built. `Odometer.set_value(v, delay, sound)` schedules its ticks and registration as the roll starts; `Counter.show_value(..., delay, sound)`. To make AC3's gains come in counter order, the top bar's changed counters now roll one after another, each starting as the one before registers (the tags keep their `TAG_STAGGER`): a visible change from 181, where they rolled together. `CardMotion` plays the lift (`Anim.LIFT_TIME`), the pat (`place_on_land`, set by `BoardViews` for a card leaving the hand for a board slot) and the refusal (as the shake starts, or alone with Reduce motion); a building played onto a territory in the Realm flies onto its card and pats on arrival. `DragController.begin_targeting` ticks (`Anim.SELECT_TIME`).
- Fixed in `Sfx` (186): the six-voice limit counts only sounds overlapping the new one's time, not ones scheduled later (a long roll's later ticks were refused).
- Not built: the downward roll's −1 st on ticks (§14.1; `Sfx.play` takes no pitch yet). A roll interrupted mid-way keeps its already scheduled ticks.
