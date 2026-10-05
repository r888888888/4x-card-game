---
id: 269
title: Choice events: an event that makes you pick one of 2–3 options
type: feature
status: red-review
branch: feat/269-choice-events
---

## Goal
Every event today resolves on its own, so the event deck is weather: you watch it happen. A choice event offers 2 or
3 options, such as "pay 3 wealth, or take +1 unrest". You must pick one before you do anything else that turn. That
turns the event deck into decisions and gives stockpiles a use beyond spending. At least one option is always free, so
you can always choose.

## Acceptance criteria
- [ ] AC1 (loader): An event may set `choices`, a list of options. Each option is `{cost?: {resource: n}, effects: [...]}`.
  Each of these is a load error naming the file, the card and the field:
  - fewer than 2 or more than 3 options;
  - no option without a cost;
  - an option effect with a `trigger`;
  - an option effect that targets or opens a choice (the same rule as an event's own effects);
  - an unknown resource in a cost;
  - `choices` on a card that isn't an event;
  - `choices` on a raid.
- [ ] AC2 (owed): Given an event with 2 choices on top of the event deck, when it is drawn at turn 2's start, then its
  own play effects resolve first, and `pending()` is `{kind: PENDING_EVENT_CHOICE, uid, options: [0, 1]}`. Every other
  action (play, buy, research, end turn, …) refuses with "Choose how to answer <event> first.". The event stays active
  for its `discard.turns`, as now.
- [ ] AC3 (choose): Given options [cost 2 wealth → +1 VP] and [free → +1 unrest], and 3 wealth:
  - `choose_option(0)` leaves 1 wealth and +1 VP, and clears `pending()`.
  - Instead, `choose_option(1)` adds +1 unrest and changes nothing else.

  Each choice emits `event_drawn`'s outcome shape for what the option did (`gained`, `lost`, `vp`, …), so the UI can
  summarise it.
- [ ] AC4 (refusals): `choose_option_error(i)` is "" when legal. Otherwise it gives a reason, and `choose_option` then
  changes nothing:
  - "Not enough wealth: needs 2." for option 0 with 1 wealth;
  - "No such option." for index 2 of 2, or −1;
  - "No event choice is waiting." when none is owed;
  - "The game is over." after the end.
- [ ] AC5 (other decisions first): Given Anarchy owes a renewal at turn start and a choice event is drawn that same turn,
  then `pending()` is the renewal. Once it is paid, `pending()` is the event choice. The same holds for a government
  choice owed at turn start. `copy()` keeps an owed or waiting choice.
- [ ] AC6 (text): Card text lists the options after its other effects: "Choose: pay 2 wealth for +1 VP; or +1 unrest."
  `option_text(uid, i)` returns one option's text: "Pay 2 wealth: +1 VP", "+1 unrest".
- [ ] AC7 (bot): Given a fixture where option 0 gives the higher lookahead score, `ScriptedBot` picks option 0. Ties go
  to the lowest index, and the bot never picks an option `choose_option_error` refuses. A bot game whose event deck is
  all choice events plays to its last turn without stalling.

## Out of scope
- Options with lasting (upkeep) effects. An option resolves once, when chosen. A lasting outcome can go in the event's
  own upkeep effects, or wait for a later item.
- Options that target a territory or card.
- Most shipped choice events (270). This item ships one (see Manual check) so the UI can be tried.

## Design notes
- Data: a new event-only field `choices`, added to `DataLoader.TYPE_FIELDS`. Options are parsed into
  `CardDef.choices: Array` of `{cost: Dictionary, effects: Array[Effect]}`.
- Decision: follow the `add-decision` skill.
  - `GameEngine.PENDING_EVENT_CHOICE`; `state.pending` stores the event's uid.
  - `choose_option(index)` / `choose_option_error(index)`; `option_text(uid, index)`.
  - When another decision is owed, the choice waits. A flag on the event's `CardInstance` (so `copy()` keeps it)
    marks it as still owed, and paying the other decision makes the choice owed next.
- Bot: per-option lookahead, as for the government choice (`ScriptedBot.lookahead`) on a fork after choosing.
- 267's AC1 invariant extends to choice events: count the option that gains the most unrest, on top of the event's
  own effects. That keeps era-1 choice events within +1.
- UI: the event modal shows the options as buttons in place of Close, and can't be dismissed while the choice is owed.
  A button whose option is refused is disabled, with the engine's reason as its tooltip. Choosing closes the modal and
  shows a notice with `outcome_summary`.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_choice_events::test_choices_load_on_an_event`, `test_bad_choices_are_a_load_error` |
| AC2 | `test_choice_events::test_a_drawn_choice_event_resolves_its_own_effects_then_owes_the_choice`, `test_every_other_action_refuses_while_the_choice_is_owed`; `test_blocking` (the "event choice" scenario, the `choose_option` row and column, `hand_input_error`) |
| AC3 | `test_choice_events::test_choosing_a_paid_option_pays_its_cost_and_resolves_its_effects`, `test_choosing_a_free_option_changes_nothing_else`, `test_choosing_emits_what_the_option_did` |
| AC4 | `test_choice_events::test_choose_option_error_gives_the_reason_and_choose_option_changes_nothing`; `test_blocking::test_each_decision_action_names_game_over_then_the_owed_decision_then_nothing_owed` |
| AC5 | `test_choice_events::test_a_renewal_owed_at_turn_start_comes_before_the_choice`, `test_the_choice_follows_a_government_chosen_at_the_turns_end`, `test_a_copy_keeps_an_owed_or_waiting_choice` |
| AC6 | `test_choice_events::test_card_text_lists_the_options_after_its_other_effects`, `test_option_text_gives_one_options_text` |
| AC7 | `test_choice_events::test_the_bot_picks_the_option_whose_lookahead_scores_most`, `test_lookahead_ties_go_to_the_lowest_index`, `test_the_bot_never_picks_a_refused_option`, `test_the_bot_answers_the_choice_in_its_turn`, `test_a_bot_game_of_choice_events_plays_to_its_last_turn` |
| 267 invariant | `test_content::test_no_era_1_event_adds_more_than_1_unrest` (counts the option that adds most unrest) |
| UI | `test_choice_modal::test_a_choice_event_shows_its_options_in_place_of_ok`, `test_the_choice_modal_cant_be_dismissed`, `test_a_refused_option_is_disabled_with_the_reason_as_its_tooltip`, `test_choosing_closes_the_modal_and_notices_what_the_option_did`, `test_under_anarchy_the_renewal_comes_first_then_the_choice` |

## Manual check
- [ ] Shipped for review: "Envoys from the Hills" (era 1, 1 copy): "Choose: pay 2 wealth for +1 VP; or +1 unrest."
  Flavour: hill chieftains arrive with gifts and expect gifts in return.
- [ ] When it is drawn, the event modal shows 2 option buttons and no Close. Esc and clicking outside do nothing. With
  under 2 wealth the pay button is disabled, and its tooltip says why.
- [ ] Choosing closes the modal, the top bar updates, and a notice summarises what the choice did.
- [ ] Under Anarchy, the renewal modal comes first and the choice follows it.

## Log
