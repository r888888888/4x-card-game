---
id: 128
title: A card can give actions this turn when played (Scout and Barter give +1 action)
type: feature
status: in-progress
branch: feat/128-gain-actions-op
---

## Goal
With 2 actions a turn (127), a card that only sets up or converts would rarely be worth one of them. A "+1 action"
card pays its own action back, so it's a free choice rather than a turn spent. Scout (explore, draw 1) is setup for
Settlers and already replaces itself; Barter (2 food → 2 wealth) is a conversion. Both get +1 action.

## Acceptance criteria
Fixtures: TEST `band` government (`actions: 2`, from 127); new free TEST action cards `drill` with
`{"op": "gain_actions", "amount": 1}` and `muster` with `"amount": 2`.

- [ ] AC1 (loader): new op `gain_actions` with `amount` an int ≥ 1 (default 1). Any trigger other than `play` is a
  load error (it isn't `upkeep_ok`, and at `start` there is no turn yet). On an event it's a load error naming the
  card and the op (events resolve at the end of the turn, so the actions would be lost).
- [ ] AC2: given `band` at the start of a turn, playing `drill` leaves `actions_left()` 2 (one used, one gained);
  playing `muster` instead leaves 3. `actions_per_turn()` stays 2.
- [ ] AC3: given `band` with 0 actions left, `drill`'s `play_error` is "No actions left this turn." (it needs an
  action to be played, like any card).
- [ ] AC4: actions gained this turn don't carry over: after `end_turn()`, `actions_left()` is 2 again.
- [ ] AC5: with unlimited actions (no `actions` on the government), the op does nothing and `actions_left()` stays
  -1.
- [ ] AC6 (text): the card text is "+1 action" on the face and "+1 action this turn" in the tooltip; with amount 2,
  "+2 actions" and "+2 actions this turn".

## Out of scope
- Standing per-turn bonuses (129).
- Other cards: Storyteller (1 food: draw 2) stays a card that uses up an action, with the draw as its reward;
  Research stays a real choice of whether to research this turn; Hunt, Winnow, Settler and Caravan stay too.

## Design notes
- Follow the `add-effect` skill: `engine/effects/gain_actions_effect.gd`, registry entry, generated text.
- The engine keeps a count of actions gained this turn next to 127's count used (both copied by `GameState.copy()`,
  reset at the start of a turn): `actions_left = actions_per_turn + gained − used`, never below 0.
- Content after this item: Scout `effects` add `{"op": "gain_actions", "amount": 1}`; Barter the same.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_gain_actions::test_gain_actions_loads`, `test_gain_actions_validation`, `test_gain_actions_amount_defaults_to_1`; `test_forecast::test_ops_that_change_more_than_the_forecast_restores_are_rejected_on_upkeep` (new row) |
| AC2 | `test_gain_actions::test_a_plus_one_card_pays_back_its_action`, `test_a_plus_two_card_leaves_one_more` |
| AC3 | `test_gain_actions::test_a_plus_one_card_cant_be_played_with_no_actions_left` |
| AC4 | `test_gain_actions::test_gained_actions_dont_carry_over` |
| AC5 | `test_gain_actions::test_gain_actions_does_nothing_with_unlimited_actions` |
| AC6 | `test_gain_actions::test_gain_actions_text` |

## Manual check
- [ ] As Chiefdom, playing Scout leaves the counter at 2 / 2; Scout, Barter and then two more cards can all be
  played in one turn.

## Log
- Balance worry (for the balance item): Scout costs nothing, explores and draws 1, so with +1 action it's pure
  upside; if the supply's 6 Scouts make a "Scout chain" deck, look at Scout's draw or supply count there.
