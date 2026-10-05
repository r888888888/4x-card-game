---
id: 312
title: legal_actions lists every action the engine would allow now
type: feature
status: in-progress
branch: feat/312-legal-actions
---

## Goal
Each new mechanic has needed its own bot rule (298, 303, 168) because the bot only knows the actions someone wrote a
rule for. After this, the engine lists every action it would allow right now, each with its arguments, so a bot (313)
can consider all of them, and the suite fails when a new action isn't listed, so a mechanic reaches the bot the day
it lands.

## Acceptance criteria
- [ ] AC1: Given a fixture game with nothing owed, when `legal_actions()` is called, then it returns entries
  `[action, args…]`: `["play_card", uid, target]` for each hand card and each of its `valid_targets` (target −1 for a
  card that needs none), `["build", id, territory]` per build-menu entry and each of its `build_targets` (295 landed first), `["buy", id]`
  per open supply pile, `["buy_tech", uid]` per research-deck tech,
  `["contribute", uid, contribute_limit]` per site with a limit above 0, `["move_unit", uid, territory]` per move
  target, `["discard_card", uid]` per hand card, the argument-free actions (`relieve_famine`, `restore_order`, `revolt`,
  `abandon`/`disband` per card) and `["end_turn"]`, each only when its error query returns "" for those arguments.
- [ ] AC2: Every entry is legal: for each, the action's error query called with its args returns "". Given a Farm in
  the hand and food 1 (it costs 2), no `play_card` entry names it; given wealth below every buy price, no `buy` entry.
- [ ] AC3: Given an owed decision, only its options are listed: explore → `["choose", uid]` per option; event choice →
  `["choose_option", i]` per option `choose_option_error` allows; government → `["choose_government", uid]` per option;
  hand-limit discard → `["discard_card", uid]` per hand card; renewal → one entry `["renew", options, count]`, meaning
  any `count` of `options` (`renew_error` is "" for the first `count`).
- [ ] AC4: After game over it returns `[]`.
- [ ] AC5: The list is in a fixed order (the order above, each zone in its order) and changes nothing: called twice it
  returns equal lists, and a fork's list equals the game's.
- [ ] AC6: The suite checks coverage: every `GameEngine` action that has an error query (found the way
  `test_blocking.gd` finds them), except `new_game` and `rename_territory`, has a row in a table that sets up a game
  where `legal_actions()` lists it. A new action with an error query and no row fails the suite.

## Out of scope
- Bots using it: 313. Choosing amounts other than `contribute_limit` (one entry per site is enough for a bot).
- Upgrades (300): they join when they land, through AC6's table.

## Design notes
- New query on `EngineQueries` (or a `LegalActions` module it calls, to keep the file under 700 lines):
  `legal_actions() -> Array`. Each entry's action name is the method to call; its error query is `<action>_error`,
  except `play_card` → `play_error` and `discard_card` → `discard_error` (the `ERROR_OF` table `test_blocking.gd`
  already has; move it to the engine so both use one).
- Renewal is one "choose count of" entry because listing every combination can run to thousands.
- Spike reference: `GenericBot.candidates` and `decision_options` on `spike/generic-bot`.
- When this lands, the `add-decision` skill's "the sim bot" step becomes "a `legal_actions` entry for the decision";
  `add-effect` needs nothing.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_legal_actions::test_with_nothing_owed_every_allowed_action_is_listed_in_order`, `test_a_card_that_needs_no_target_is_listed_with_target_minus_1`, `test_units_and_sites_list_their_moves_contributions_disbands_and_abandons`, `test_engine_structure` (declared in `engine_queries.gd`) |
| AC2 | `test_legal_actions::test_every_entry_is_legal_and_nothing_unaffordable_is_listed` |
| AC3 | `test_legal_actions::test_an_explore_choice_lists_only_its_options`, `test_an_event_choice_lists_the_options_it_allows`, `test_the_government_choice_lists_each_government`, `test_a_hand_limit_discard_lists_each_hand_card_and_what_it_still_allows`, `test_a_renewal_is_one_entry_choose_count_of_the_options` |
| AC4 | `test_legal_actions::test_nothing_is_listed_after_game_over` |
| AC5 | `test_legal_actions::test_the_list_is_the_same_twice_and_on_a_fork_and_changes_nothing`, and AC1's exact list (the order) |
| AC6 | `test_legal_actions::test_every_action_with_an_error_query_has_a_coverage_row`, `test_each_coverage_game_lists_its_action` |

## Log
- 2026-10-05: specced from the generic-bot spike, with 309–311, 313–315.
- 2026-10-05: red. `build` is in AC1 (295 landed before this item). AC3's "only its options" is what the error queries
  give, with one exception they already make: while a hand-limit discard is owed, research stays allowed
  (`_DISCARD_ALLOWS`: discard, the supply screen's query, research; buying is blocked), so it is listed too. `supply` pairs a query with `supply_error` but is no
  action: left out with `new_game` and `rename_territory`.
- 2026-10-05: green phase: the discard test expected `buy` too, from a misread of `test_blocking`; buying is blocked
  while a discard is owed. Corrected with the user's approval to research then the discards.
