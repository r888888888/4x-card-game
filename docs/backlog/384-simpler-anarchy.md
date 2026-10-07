---
id: 384
title: Simpler Anarchy - unrest is its clock
type: feature
status: red-review
branch: feat/384-simpler-anarchy
---

## Goal
Anarchy (145, 155, 156, 253) stacks eight rules on one card, and two of them are clocks for the same thing: its counters
(⌈max_counters × unrest ÷ limit⌉, lowered by calming, −1 a turn) and unrest itself (lowered by renewal and order
cards). Cut it down so the player watches one number: **Anarchy lasts until unrest reaches 0.** Unrest drops by 1 at
the end of each Anarchy turn (so it always ends), the drain goes, the
one-action limit goes, and so does buying order: Anarchy ends only when unrest reaches 0. Renewal, the order-card-only rule, "nothing grown, bought or researched", revolution and the
government choice stay.

## Acceptance criteria
Fixtures are `tests/lib/anarchy_case.gd`'s: Chiefs (limit 5), Kings (limit 7), Feast (order, −2 unrest); the unrest
block with no `renewal` unless a criterion says so.

- [ ] AC1 (unrest is the clock): Given Anarchy ruling with 3 unrest and nothing else changing unrest, when the turn ends,
  unrest is 2 and Anarchy still rules the next turn; when that turn and the next end, unrest goes 2 → 1 → 0, and at
  the end of the turn where it reaches 0 Anarchy leaves for `removed`, the government choice is owed before the next
  turn starts (as today when counters ran out), and after choosing Kings unrest is 0 and the next turn starts.
  `event_counters(anarchy uid)` is 0 throughout (Anarchy carries no counters).
- [ ] AC2 (calming shortens it; 0 is checked at the turn's end): Given Anarchy ruling with 3 unrest and Feast in hand,
  when Feast is played, unrest is 1 and Anarchy still rules for the rest of the turn (a non-order card is still
  refused with `ONLY_ORDER`); when the turn ends, unrest is 0 and Anarchy ends. Unrest never goes below 0: Anarchy
  with 0 unrest at a turn's end ends with unrest 0.
- [ ] AC3 (a natural fall and a revolution): Given Chiefs ruling and unrest reaching 5 by a turn's start, Anarchy falls
  with unrest 5 and ends at the end of its 5th turn if nothing else changes unrest. Given Chiefs ruling with 2 unrest
  and a revolution declared, when the next turn starts Anarchy falls with unrest 2 and ends at the end of its 2nd turn.
- [ ] AC4 (no buying out): Given Anarchy ruling with 4 unrest and 30 wealth, `legal_actions()` has no entry that ends
  Anarchy (no `restore_order`), and ending the turn leaves Anarchy ruling with 3 unrest and 30 wealth. The engine has no
  `restore_order`, `restore_order_error` or `order_relief`, the board no Restore order button, and the sim no
  `restored` metric.
- [ ] AC5 (no drain): Given Anarchy ruling (or a revolution pending) with 10 food and 10 wealth and nothing else
  changing them, when the next turn starts food and wealth are still 10, and `upkeep_forecast()` and
  `turn_forecast()` show no food or wealth lost to Anarchy.
- [ ] AC6 (no action limit): Given Anarchy ruling (no government) and two Feasts in hand, `actions_left()` is −1
  (unlimited) and both Feasts can be played in the same turn.
- [ ] AC7 (the revolt summary): Given Chiefs ruling and a revolution possible, `revolt_summary()` has a line
  "It lasts until unrest reaches 0, with −1 unrest at the end of each of its turns.", and no line about actions per
  turn, stores eaten or buying order; with no revolution possible it is
  `[]`, as today.
- [ ] AC8 (loader): `max_counters` and `drain_pct` are no longer known fields of the unrest block (an unknown-field
  warning, like any other), and the block loads without them; the real data loads with no errors or warnings.

## Out of scope
- Renewal as a free action: [385](385-renewal-action.md). Losing the game to a long Anarchy: [386](386-anarchy-collapse.md).
- Renewal's count (still `renewal` + its turn − 1 + the renewal modifier), the order tag, revolution's rules.
- Tuning `renewal` or the government limits; that's a balance item.

## Design notes
- Config `unrest`: drop `max_counters` and `drain_pct`.
- `data/cards.json`: Anarchy loses `"modifiers": {"actions": 1}`; its hand-written `text` is rewritten for the new
  rules (no counters, no drain, no action limit, no buying order). A draft that fits 383's hover pull-up:
  "Only order cards can be played; nothing is grown, bought or researched.\nEnds when unrest is 0; −1 unrest at each
  turn's end.\nEach turn, trash 1 card, +1 per turn so far (−1 unrest each).\nWhen it ends, choose a government." 
- End of an Anarchy turn (`Anarchy.end_of_turn`): unrest −1 (not below 0), then at 0 Anarchy ends (`_end`, the
  government choice with `ends_turn`). The notices say "It lasts until unrest reaches 0."
- Unreachable once Anarchy always ends at 0 unrest, so removed: `choose_government`'s drop to half the new limit;
  `counters_for`, `counters_left`, `calm` and the `_unrest_lowered` hook, `revolt_forecast` and
  `GameEngine.revolt_forecast`, `anarchy_counters`, `state.anarchy_limit` (and `GenericBot`'s key on it), `drain`,
  `drain_of`, `rules_next_turn` and their forecast step, and the Anarchy branch in
  `CardPlay.actions_per_turn` (no government ⇒ unlimited, as without unrest). Their tests go too
  (`test_anarchy_length`, `test_anarchy_drain`, and the counter, halving, drain and actions cases elsewhere).
- Buying order goes (the user's call, 2026-10-06, after the spec): `restore_order`, `restore_order_error`,
  `order_relief`, `Anarchy.relief`/`restore`/`restore_error`, the `order_restored` signal, the Restore order button
  (`ActionButton.restore_order`, `main.restore_order_button`), its `legal_actions` entry and the sim's `restored`
  metric. Relieve famine stays. Tests that reached the government choice by restoring order end Anarchy at 0 unrest
  instead.
- `GenericBot` sees the change through `turn_forecast` and the legal actions; no new action.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_anarchy_length::test_anarchy_lasts_until_unrest_reaches_0_losing_1_each_turn`, `test_anarchy::test_when_anarchy_burns_out_the_government_choice_is_owed`, `test_anarchy_event::test_anarchy_falls_into_the_active_events_and_the_government_slot_empties`, `test_anarchy_event::test_upkeep_neither_counts_anarchy_down_nor_discards_it`, `test_anarchy_event::test_a_copy_keeps_the_active_anarchy` |
| AC2 | `test_anarchy_length::test_calming_shortens_anarchy_and_0_is_checked_at_the_turns_end`, `test_anarchy_length::test_unrest_never_goes_below_0_at_an_anarchy_turns_end`, `test_anarchy_length::test_anarchys_end_comes_after_the_hand_limit_discard` |
| AC3 | `test_anarchy_length::test_a_fall_at_the_limit_lasts_as_many_turns_as_its_unrest`, `test_anarchy_length::test_a_revolution_falls_with_the_unrest_it_had`, `test_anarchy_length::test_a_1_turn_anarchy_and_the_next_upkeep_runs_under_the_chosen_government`, `test_sim_anarchy::test_a_forced_anarchy_of_5_turns_then_glory` |
| AC4 | `test_anarchy::test_there_is_no_buying_out_of_anarchy`, `test_legal_actions::test_every_action_with_an_error_query_has_a_coverage_row`, `test_blocking::test_the_action_table_names_every_action_with_an_error_query`, `test_sim::test_sim_stats_reports_mean_min_max_per_metric` |
| AC5 | `test_anarchy::test_anarchy_eats_no_stores_even_with_a_retired_drain_pct`, `test_anarchy::test_a_pending_revolution_forecasts_no_drain` |
| AC6 | `test_anarchy::test_anarchy_sets_no_action_limit` |
| AC7 | `test_revolution::test_revolt_summary_describes_the_coming_anarchy_with_this_games_numbers`, `test_revolution::test_a_summary_leaves_out_what_the_config_lacks` |
| AC8 | `test_anarchy::test_the_unrest_block_loads_with_its_defaults`, `test_anarchy::test_unrest_block_validation` |

## Manual check
- [ ] Anarchy's card reads well and fits its face; its event panel shows no counter.
- [ ] The Revolt modal's summary reads well with the new lines.
- [ ] Balance worry (for the user to run): a natural fall now lasts as many turns as the fallen limit less what
  renewal and order cards calm (Chiefdom 8, Kingship 10, Theocracy 13), with no way to buy out.
  `scripts/sim.sh --level 2 --compare <main checkout>` shows anarchy_turns.

## Log
- 2026-10-06: buying order removed entirely (the user, via the card-images session), in place of 2 wealth per unrest.
  Balance worry sharper: with no buy-out, Anarchy's length is the fallen unrest less renewal and order cards.
