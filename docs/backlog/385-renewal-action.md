---
id: 385
title: Renewal is a free action during Anarchy
type: feature
status: review
branch: feat/385-renewal-action
---

## Goal
Today renewal (147, 255) is a decision Anarchy forces on you at each turn's start: trash `renewal` + (its turn − 1) +
the renewal modifier cards, each calming 1 unrest, before anything else. With [384](384-simpler-anarchy.md) Anarchy
lasts a fixed 3 turns and unrest drops to 0 when it ends, so calming during it means nothing. Make renewal a plain
opportunity: during Anarchy you may trash up to `renewal` + the renewal modifier cards each turn, from your hand, deck or
discard (not a government), at any time, for no action and no change to unrest. The ramp (+1 per turn so far) goes: it
pushed you out of a long Anarchy, and a fixed one needs no push.

Builds on 384.

## Acceptance criteria
Fixtures are `tests/lib/anarchy_case.gd`'s, with `unrest.renewal: 1`.

- [x] AC1 (an action, not a decision): Given Anarchy on its first turn with 3 unrest, when the turn starts no decision
  is owed (`pending()` is `{}`) and `renewals_left()` is 1. When `renew([uid of a hand card])` is called, it returns
  true, the card is in `trashed`, unrest is still 3, `renewals_left()` is 0 and `actions_left()` is unchanged.
- [x] AC2 (a flat count per turn): Given Anarchy on its second turn, `renewals_left()` is 1 (no ramp); one `renew` of a
  discard card succeeds and a second is refused and changes nothing. On its third turn `renewals_left()` is 1 again:
  unused renewals don't carry over, and a turn can end with renewals unused.
- [x] AC3 (the modifier raises the cap): Given a card in play with `"modifiers": {"renewal": 1}`, `renewals_left()` is 2
  on each Anarchy turn, and one `renew` of two cards succeeds. With no `renewal` in the unrest block, `renewals_left()`
  is 0 and `renew` is refused.
- [x] AC4 (rejections): `renew_error(uids)` is non-empty and `renew` changes nothing when: Anarchy doesn't rule; `uids`
  is empty; a uid is a government, a tableau card or unknown; a uid appears twice; `uids` holds more cards than
  `renewals_left()`; the game is over or another decision is owed (`_blocked_error`).
- [x] AC5 (no more waiting): Given Anarchy ruling and a choice event drawn at a turn's start, its choice is owed at once
  (renewal no longer goes first). `PENDING_RENEWAL` is no longer a decision kind.
- [x] AC6 (legal actions): While `renewals_left()` > 0 and there are options, `legal_actions()` has one entry
  `["renew", renewal_options(), renewals_left()]` whose first card passes `renew_error`; with no renewals left, or
  without Anarchy, it has none.
- [x] AC7 (the bot uses it): Given a fixture game under Anarchy with `renewal: 1` and a card of no worth to the bot (no
  effects, no VP) in hand, when `GenericBot` plays the turn, it renews that card.

## Out of scope
- Anarchy's length (384); the honeymoon (399); the claimants (401–404).
- Which zones renewal may trash from (hand, deck, discard; 255) and the renewal numbers (balance).

## Design notes
- New state: `GameState.renewed` (cards renewed this turn, 0 at each turn's start), copied by `copy()`.
- New query `renewals_left()`: `renewal` + the renewal modifier − `renewed`, never below 0; 0 without Anarchy or with
  no `renewal` in the config. `renewal_options()` stays (hand, deck and discard, governments aside).
- `renew(uids)` / `renew_error(uids)` keep their names; `renew_error` starts with `_blocked_error("renew")` instead of
  `_owed_error`, and checks 1 ≤ `uids.size()` ≤ `renewals_left()`. `renew` no longer lowers unrest.
- Removed: `PENDING_RENEWAL`, `Anarchy.start_renewal`, the renewal case in the decision tables (`_owed_error`,
  `pending` guards, focus keys), `EventChoices.next` after a renewal, the sim bot's owed-renewal path, and
  `state.anarchy_turn` if nothing else reads it once the ramp goes. Follow the `add-decision` skill's list backwards
  for the places a decision kind touches.
- Renewal modifier wording on cards (Calls for Reform, Radical Thinkers, Mysticism) changes from "trash N more" to
  "renew up to N more each Anarchy turn"; the text is generated from `Modifiers.RENEWAL`'s entry.
- `revolt_summary()`'s renewal line becomes "Each turn: you may trash 1 card from your hand, deck or discard."
  Anarchy's card text line: "Each turn, you may trash 1 card."
- UI: the Renewal modal opens from a "Renew" action button (beside Relieve famine) shown while `renewals_left()` > 0,
  picks 1 to `renewals_left()` cards, and can be closed without trashing. The button's label asks the engine for the
  count.
- Bot (AC7): `GenericBot` must see a thinner deck as worth something (its `deck` weight); if it doesn't renew a
  worthless card, add a term under TDD.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_renewal::test_renewal_is_an_action_that_owes_nothing`; `test_pending::test_the_state_holds_one_pending_decision` (no `PENDING_RENEWAL`) |
| AC2 | `test_renewal::test_the_count_is_flat_and_unused_renewals_dont_carry_over` |
| AC3 | `test_renewal`: `test_a_renewal_modifier_raises_the_count_each_anarchy_turn`, `test_without_renewal_in_the_config_there_is_none`, `test_the_renewal_modifier_loads_with_its_text`; `test_events_at_turn_start::test_an_event_drawn_this_turn_raises_this_turns_renewals`; `test_card_text::test_bug_329_countable_modifiers_keep_their_plural` |
| AC4 | `test_renewal`: `test_renew_error_names_each_reason_and_a_refusal_changes_nothing`, `test_renew_is_refused_outside_anarchy`, `test_renew_is_refused_while_a_decision_is_owed_or_the_game_is_over`; `test_blocking` (renewal is no longer a decision scenario) |
| AC5 | `test_choice_events::test_under_anarchy_a_choice_drawn_at_turn_start_is_owed_at_once`, `test_choice_modal::test_under_anarchy_the_choice_shows_at_once`, `test_pending` (above) |
| AC6 | `test_renewal::test_renewal_is_one_legal_entry_while_renewals_are_left`, `test_legal_actions::test_a_renewal_is_one_entry_choose_up_to_renewals_left_of_the_options` |
| AC7 | `test_generic_bot`: `test_the_bot_renews_a_worthless_card`, `test_renewal_trashes_the_least_valuable_cards_even_when_listed_last` |
| Design (summary, UI, state) | `test_revolution::test_revolt_summary_describes_the_coming_anarchy_with_this_games_numbers`; `test_renewal_modal` (the Renew button, a closable sheet, 1 to N cards); `test_renewal::test_a_copy_keeps_the_renewals_used`; `test_engine_structure` (`renewals_left`, `renewal_options` queries) |

## Manual check
Steps: `godot --path . -- --seed 5`; open the civilization modal, Revolt, confirm and end the turn.
- [ ] During Anarchy the Renew button shows with the count left; the Renewal sheet opens, can be closed, and trashes
  1 to N cards; the button hides when none are left.
- [ ] The cards with the renewal modifier read correctly.
- [ ] Balance worry (for the user to run): renewal now thins the deck with no unrest attached, so revolting to trash
  cards may pay; the honeymoon (399) blocks back-to-back revolutions. `scripts/sim.sh --level 2 --compare <main
  checkout>` (revolts, trashed).

## Log
- 2026-10-07: reshaped with 384's redesign (the user): renewal no longer calms unrest ("just an opportunity to trash
  cards") and the count is flat per turn (no +1 per turn so far).
- 2026-10-08: red tests. Messages chosen: "Renewal is only possible during Anarchy.", "Choose a card to trash.", "No
  renewals left this turn.", "Trash at most N cards this turn." (the wrong-card and twice messages stay). The modifier
  text: "Renew up to N more cards each Anarchy turn". The Renew button reads "Renew (N left)"; the sheet's key "Trash N
  cards" counts the cards chosen. A renewal modifier on an event drawn this turn now counts this turn (it is live).
  Removed as unreachable: the cap at the options, the ramp, the "renewal blocks everything" and drag tests, the
  rollout-answers-renewal bot test, and renewal's column in test_blocking's decision tables.
- 2026-10-08: green. Beyond the criteria, removed as unreachable once renewal stopped being a decision: the wait a
  choice event had behind it (`EventChoices.next`, `CardInstance.choice_waiting`; nothing else is owed when an event
  is drawn) and `GameState.anarchy_turn` (only the ramp read it). The bot now tries a renewal one card at a time, the
  least valuable first (at most 40), instead of combinations of exactly the count; it repeats while each renewal beats
  doing nothing. `test_sim_anarchy::test_trashed_and_famine_turns` gained a worthless Husk in its renewal game: its deck
  of Charters held nothing the bot would choose to trash.
