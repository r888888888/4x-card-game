---
id: 155
title: Revolt any time; Anarchy's length follows unrest
type: feature
status: red-review
branch: feat/155-revolution-and-anarchy-length
---

## Goal
Revolution becomes a reform you schedule. You can revolt whenever you like and Anarchy starts next turn. How long it
lasts depends on how restless the people are relative to the fallen government's limit: a calm reform is short, a
collapse at the limit is long. Calming shortens it, and wealth buys the rest off at a price that rises with each
turn left. Follows 154. From `spike/revolution`.

## Acceptance criteria
- [ ] AC1: When Anarchy falls, it gets ⌈max_counters × unrest ÷ L⌉ counters, between 1 and max_counters, where L is
  the fallen government's `unrest_limit()` (modifiers included). With Chiefs (5) and max_counters 4: unrest 5 → 4,
  unrest 2 → 2, unrest 1 → 1, unrest 0 → 1; with an Altar (limit 6), unrest 3 → 2.
- [ ] AC2: `anarchy_counters()` is the counters left, lowered live by calming: never more than the AC1 formula on the
  current unrest (same L), never below 1 while Anarchy rules. Given 4 counters, L 5 and unrest 5, when unrest drops to
  2, then `anarchy_counters()` is 2, and it doesn't rise again when unrest goes back up.
- [ ] AC3: At the end of each Anarchy turn (after any hand-limit discard), one counter comes off; at 0 Anarchy ends
  and the government choice (154) is owed before the next turn starts. A 1-counter Anarchy lasts exactly one turn.
  The next turn's upkeep runs under the chosen government.
- [ ] AC4: Given a government ruling and no Anarchy, `revolt_error()` is "" (no event needed). `revolt()` uses no
  action, changes nothing else this turn, and at the next turn's start (before upkeep) Anarchy falls as in AC1, the
  fallen government going to the government deck. `revolt_error()` is `"Anarchy already rules."`, `"A revolution is
  already under way."` after a revolt this turn, `"There is no government to overthrow."` with none ruling, the
  pending-decision message while one is owed, and `"The game is over."` after the end; `revolt()` then returns false
  and changes nothing.
- [ ] AC5: `order_relief()` is `{wealth: c × (c + 1)}` for c = `anarchy_counters()` (2, 6, 12, 20 for 1–4), `{}`
  without Anarchy. `restore_order_error()` is `"Order can't be restored on Anarchy's first turn."` on the turn it
  fell, and names the price when wealth is short. `restore_order()` pays, ends Anarchy, drops any renewal still owed
  this turn, and owes the government choice at once.
- [ ] AC6: Renewal (147) asks for `unrest.renewal` + (the Anarchy's turn − 1) + the `renewal` modifier cards: 1 on its
  first turn with renewal 1, 2 on its second.
- [ ] AC7 (bot): `ScriptedBot` revolts at the end of a turn when the government deck holds one it ranks higher (154's
  ranking) than the ruling one and `anarchy_counters` would be 1 (AC1 on current unrest); under Anarchy it restores
  order from the second turn when it can pay and 2+ counters are left or the next upkeep would starve.
- [ ] AC8: The Revolt button below the Realm shows whenever `revolt_error()` is ""; its tooltip says Anarchy starts
  next turn and lasts about N turns (N from the engine: AC1 on current unrest).
- [ ] AC9 (154 leftovers): a government is never played from hand. Given a government card put straight into the hand,
  `play_error` is `"A government is chosen, not played."`, with or without Anarchy. The play-a-government path goes:
  `CardPlay`'s government destination and `_replace_government`, the same-government error, `Anarchy.accept_error` and
  the government branch of `Anarchy.play_error` (whose message becomes `"Anarchy: only an order card can be
  played."`), and `ScriptedBot`'s governments-first play and 148 revolt rule. The 11 tests that put a government in hand
  (test_government 3, test_leaving_anarchy 4, test_anarchy 2, test_revolution 2) are removed or rewritten on the
  government deck, and listed at the red checkpoint.

## Out of scope
- The drain on stores (156); the lookahead bot (159).

## Design notes
- `GameState`: `revolt_pending`, `anarchy_turn` (1 = the turn it fell), `anarchy_limit` (L, recorded before the
  government falls). The counters' countdown moves from the turn's start to `end_turn`, which owes the choice like the
  hand-limit discard does (`finish_turn` after `choose_government`).
- Forced Anarchy still falls at the turn's start after upkeep when unrest is at the limit (then max_counters counters).
  A revolution falls before upkeep, so its first Anarchy turn has an Anarchy upkeep.
- Replaces 148's event requirement: events' `revolt` field is dropped (loader: unknown field warning; Calls for Reform
  and Radical Thinkers keep their `renewal` modifiers, Peasant Uprising keeps +1 unrest). Replaces 146's flat
  `unrest.relief` (dropped from the config) and 145's count-up counters.
- API: `anarchy_counters()` (now counters left), `revolt_forecast()` → expected counters, for the tooltip.
- The Anarchy card's hand-written text must follow these rules.
- AC9 was folded in from the 2026-10-01 project review: since 154 `create_card` sends a government to the government
  deck and the loader keeps governments out of the deck and supply, so no real game has one in hand (8 seeds checked:
  never). AC4's "There is no government to overthrow." also closes a soft-lock the review reproduced on today's code:
  with no government ruling, revolt → Anarchy burns out → a government choice from an empty deck that refuses every
  action. Its AC4 test is the regression test. The item now has 9 criteria.
- Builds on 169–176: the end-of-turn government choice is set in 172's `state.pending`, the new `GameState` fields are
  covered by 171's copy guard, and the order price uses 173's helpers.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | test_anarchy_length: `test_anarchy_gets_counters_by_its_share_of_the_fallen_limit`, `test_a_forced_anarchy_at_the_limit_gets_max_counters` |
| AC2 | test_anarchy_length: `test_calming_lowers_the_counters_left_for_good` |
| AC3 | test_anarchy_length: `test_a_counter_comes_off_at_the_end_of_each_anarchy_turn`, `test_a_1_counter_anarchy_lasts_one_turn_and_the_next_upkeep_runs_under_the_chosen_government`, `test_the_counter_comes_off_after_the_hand_limit_discard`; test_anarchy: `test_when_anarchy_burns_out_the_government_choice_is_owed`, `test_burning_out_keeps_unrest_below_half_the_limit` |
| AC4 | test_revolution: `test_revolting_needs_no_event_and_changes_nothing_this_turn`, `test_anarchy_falls_at_the_next_turns_start_before_upkeep`, `test_revolt_error_names_each_reason_and_a_refusal_changes_nothing`, `test_revolt_waits_for_a_pending_discard`, `test_bug_155_no_revolt_without_a_government_to_overthrow`, `test_an_events_revolt_field_is_unknown` |
| AC5 | test_leaving_anarchy: `test_order_relief_is_c_times_c_plus_1_wealth_for_the_counters_left`, `test_unrest_relief_is_no_longer_read`, `test_restore_order_error_names_each_reason_and_a_refusal_changes_nothing`, `test_restore_order_waits_for_a_pending_discard`, `test_restore_order_pays_and_the_government_choice_is_owed_at_once`, `test_a_government_chosen_mid_turn_counts_its_actions_at_once`, `test_the_restore_order_button_shows_in_anarchy_beside_relieve_famine` |
| AC6 | test_renewal: `test_renewal_grows_with_anarchys_turn`, `test_renewal_counts_anarchys_turn_not_its_counters_left` |
| AC7 | test_revolution: `test_revolt_forecast_is_the_counters_a_revolution_would_bring`, `test_the_bot_revolts_to_a_better_government_when_anarchy_would_last_1_turn`, `test_the_bot_doesnt_revolt_otherwise`; test_leaving_anarchy: `test_the_bot_restores_order_from_the_second_turn_with_2_counters_left`, `test_with_1_counter_left_the_bot_pays_only_to_avoid_starving` |
| AC8 | test_revolution: `test_the_revolt_button_shows_while_you_may_revolt_and_forecasts_the_anarchy` |
| AC9 | test_government: `test_a_government_in_hand_cant_be_played`; test_anarchy: `test_under_anarchy_a_government_in_hand_cant_be_played`, `test_under_anarchy_only_order_cards_play` |
| (changed) | test_government_deck: `test_a_chosen_government_resolves_its_play_effects_without_paying` (the next turn's upkeep now runs); test_blocking scenarios (restore on Anarchy's 2nd turn); test_prices: `test_a_short_price_of_two_resources_names_both` (calls `price_error`, no config relief); test_identity_lines: `test_choosing_a_government_updates_the_button_and_an_open_modal` |

## Manual check
- [ ] Revolt at low unrest: Anarchy next turn lasts 1 turn; the Government overlay opens at its end.
- [ ] Hit the unrest limit: 4 turns of Anarchy; renewal shortens it; Restore order shows the price falling.

## Log
- 2026-10-01: Specced from `spike/revolution`. Spike: counters by share of the limit cost 7–9% score against ⌈unrest ÷ 2⌉
  on baseline and wide; about 4 Anarchies and 1–2 revolts a game with the lookahead bot.
