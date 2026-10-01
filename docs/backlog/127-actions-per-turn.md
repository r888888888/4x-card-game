---
id: 127
title: Playing a card from hand uses an action; your government sets how many you get each turn
type: feature
status: red-review
branch: feat/127-actions-per-turn
---

## Goal
Today the only limit on a turn is food and wealth, so the best play is almost always "play everything you can
afford". An action counter makes tempo a decision: each turn you get a few actions, and every card played from
hand uses one. The number comes from your government (Chiefdom 2, Kingship and Theocracy 3), which gives changing
government a reason beyond its upkeep bonus. Later, techs, buildings and civilizations add to it (129).

Only playing a card from hand uses an action. Growing, buying from the supply, buying a revealed tech, choosing an
explored territory, relieving a Famine, discarding and ending the turn never do.

## Acceptance criteria
Fixtures: two new TEST_GOVS, `band` (`actions: 2`, cost {}) and `court` (`actions: 3`, cost {}); the existing
`council` and `kingdom` keep no `actions`. Free TEST_CARDS (`scout`, `shrine`, `study`) fill the hand.

- [ ] AC1 (loader, text): government field `actions` is optional: an int ≥ 1. A value < 1 or not an int is a load
  error naming the card and `actions`. On another card type it's an unknown-field warning (`DataLoader.TYPE_FIELDS`).
  A government with `actions: 2` has the card text "2 actions each turn." (face and tooltip).
- [ ] AC2 (queries): new `actions_per_turn() -> int` is the ruling government's `actions`, and `actions_left() -> int`
  is that minus the actions used this turn, never below 0. Both are -1 (unlimited) when no government rules or it
  sets no `actions`. Given `band` at the start of a turn, both are 2; `fork().actions_left()` matches the game's.
- [ ] AC3 (spending): given `band` and 3 free cards in hand, playing two leaves `actions_left()` 0. The third's
  `play_error` and `playable_error` are "No actions left this turn." and `play_card` returns false with the card
  still in hand. With game over or a pending decision, those errors keep their current, higher-priority message.
- [ ] AC4 (free actions): given `band` with 0 actions left, `grow_error`, `buy_error`, `discard_error`,
  `relieve_famine_error` and `end_turn_error` don't mention actions, and each action still works when otherwise
  legal. Playing `study` (research) with the last action still lets `buy_tech` or `decline_research` resolve its
  reveal, and playing an explore card with the last action still lets `choose` pick a territory.
- [ ] AC5 (reset): given `band` with 0 actions left, after `end_turn()` the new turn starts with `actions_left()` 2.
  Unused actions don't carry over (ending a turn with 1 left still starts the next with 2).
- [ ] AC6 (changing government): given `band` with 1 action used, playing `court` from hand uses the second action
  and leaves `actions_left()` 1 (3 − 2). Given `court` with 3 used, playing `band` leaves 0. Given no `actions` on
  the government (`council`), any number of cards can be played, as today.
- [ ] AC7 (UI, in the real main.tscn): with `band` ruling, the top bar shows an actions counter reading "Actions:
  2 / 2", which reads "Actions: 1 / 2" after a play; at 0 the hand cards show as unplayable (as for any non-empty
  `playable_error`). With unlimited actions the counter is hidden.
- [ ] AC8 (content): every government in `data/cards.json` sets `actions` (an invariant, no numbers).

## Out of scope
- Cards that give actions when played (128) and standing bonuses from techs, buildings, civilizations or events
  (129).
- A per-card action cost other than 1.
- Highlighting End turn when no actions are left (a later UI item if wanted).
- Balance (a separate item; see Log).

## Design notes
- New `CardDef` field `actions` (government only, via `TYPE_FIELDS`); 0 means "sets none".
- New `GameState` field counting the actions used this turn (copied by `copy()`), reset in `TurnLoop.start_turn`
  before the draw. Count used, not left: `actions_left` is computed, so a government played mid-turn (AC6), and
  later a bonus (128, 129), takes effect at once with no snapshot to fix up.
- `CardPlay.error` checks actions after `_blocked_error` and before cost, so "No actions left this turn." wins over
  "needs N food". `CardPlay.play` uses the action when the card leaves the hand. `_blocked_error` is not the place:
  it also guards grow, buy, discard and end turn, which stay free.
- New queries go in `GameEngine` (after 125) and the rules in `CardPlay` or a small new module.
- Glossary term "Actions": "Playing a card from your hand uses 1 action. Your government sets how many you get each
  turn; unused ones are lost." It shows in a government's card details.
- The sim bot needs no change: it ends the turn when nothing is playable. `MAX_PLAYS_PER_TURN` stays for configs
  with unlimited actions.
- Content after this item: Chiefdom `actions: 2`, Kingship `actions: 3`, Theocracy `actions: 3`. PLAN.md's turn loop
  ("3. Play") and Governments section describe actions.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_actions::test_government_actions_load`, `test_bad_government_actions_are_load_errors`, `test_government_actions_text` |
| AC2 | `test_actions::test_actions_per_turn_come_from_the_government`, `test_actions_are_unlimited_without_a_government_that_sets_them` |
| AC3 | `test_actions::test_each_play_uses_an_action_until_none_are_left`, `test_no_actions_comes_after_game_over_and_a_pending_choice` (a guard: passes already) |
| AC4 | `test_actions::test_other_actions_dont_use_or_need_actions`, `test_buying_a_revealed_tech_after_the_last_action_is_free`, `test_choosing_an_explored_territory_after_the_last_action_is_free` |
| AC5 | `test_actions::test_actions_reset_each_turn_and_dont_carry_over` |
| AC6 | `test_actions::test_a_new_government_counts_at_once`, `test_any_number_of_plays_without_actions` |
| AC7 | `test_actions::test_top_bar_counts_actions_and_spent_hands_dim` |
| AC8 | `test_content::test_every_government_sets_actions` |

## Manual check
- [ ] As Chiefdom, after two plays the hand dims and the counter reads "Actions: 0 / 2"; growing and buying still
  work. Playing Kingship as the second action leaves 1 action that turn and 3 the next.

## Log
- Balance worries (for the balance item, not here): the whole economy shifts from resources to tempo. Food and
  wealth will pile up; the sim bot discards its whole hand every turn, which now matters much more (it refills to 5
  each turn while a human keeps cards). Babylon starts with Kingship in its discard, so it reaches 3 actions within a
  few turns; Kingship and Theocracy both keep their upkeep bonuses on top of the extra action.
