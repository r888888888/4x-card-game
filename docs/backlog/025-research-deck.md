---
id: 025
title: Research techs from a research deck (reveal 2, buy one or decline)
type: feature
status: in-progress
branch: feat/025-research-deck
---

## Goal
Techs give the player long-term goals and something to spend wealth on. Techs never enter the main
deck. Once per turn the player may research: reveal the top 2 techs of a separate research deck, then
buy one with wealth or decline both. Bought techs stay in a Researched row for the rest of the game.
Their effects and VP count like buildings. This is the first of three tech items; 026 adds passes and
discounts, 027 adds eras and the Library.

## Acceptance criteria
Fixture techs added to TEST_CARDS:
- `pottery`: "Pottery", cost 2 wealth, 1 VP, ⟳ +1 food
- `writing`: "Writing", cost 3 wealth, 0 VP, play: +2 VP (`score`)
- `bronze`: "Bronze Working", cost 5 wealth, 0 VP, no effects

Unless stated otherwise, the config has `research_deck: {pottery: 1, writing: 1, bronze: 1}` and
starting resources `{food: 2, wealth: 10}`. Tests set the research deck order directly when it
matters ("top first").

- [ ] AC1 (tech cards load): card type `tech` is valid. A tech's cost must be wealth only, and at
  least 1: `{"food": 1}`, `{"wealth": 0}`, `{"wealth": 2, "food": 1}` and a missing cost are each a
  load error that names the card and `cost`. A tech effect with a `keyword`, or a play effect that needs
  a target (`settle`), is a load error that names the card and the effect index.
- [ ] AC2 (config): `research_deck` is optional ({tech_id: count}, default {}). An unknown id, a card
  that isn't a tech, or a count below 1 is a load error that names config.json and `research_deck`. A
  tech listed in `deck` is a load error that names `deck`.
- [ ] AC3 (setup): In a new game, the `research_deck` zone holds the 3 techs in a shuffled order that
  depends only on the seed (same seed, same order). `researched` is empty and `research_left()` is 1.
  With no `research_deck` in the config, the research deck is empty and `research_error()` is "The
  research deck is empty."
- [ ] AC4 (reveal): Given the research deck [pottery, writing, bronze] (top first), when I call
  `research()`, then it returns true. `research_options()` is [pottery uid, writing uid] (top first),
  the research deck holds only Bronze Working, and `research_left()` is 0. `changed` is emitted.
  While options are open:
  - `play_error(uid)` and `grow_error(territory_uid)` are "Buy a tech or decline first.", and
    `play_card`/`grow` fail with nothing changed
  - `discard_card` returns false
  - `end_turn()` does nothing (still turn 1)
  - `research()` returns false.
- [ ] AC5 (buy): Continuing AC4, when I call `buy_tech(pottery uid)`, then it returns true. Wealth is
  8, Pottery is in `researched`, and the research deck holds 2 cards (Bronze Working and Writing, in
  shuffled order). `research_options()` is empty, and play and end turn work again.
  Rejections leave everything unchanged, including the open options:
  - with 1 wealth, `buy_tech_error(writing uid)` is "Writing needs 3 wealth (you have 1)." and
    `buy_tech` returns false
  - `buy_tech` with a uid that isn't an option (Bronze Working, the Capital, -1) returns false.
  `tech_cost(uid)` is the tech's printed wealth cost: 2 for Pottery.
- [ ] AC6 (techs count like buildings): Buying Writing resolves its play effects, so the score goes up
  by 2 at once. Buying Pottery raises the score by 1 (its printed VP), and at the next turn's upkeep
  Pottery gives +1 food. A tech is never idle, and needs no territory, slot or worker.
- [ ] AC7 (decline): Given open options [pottery, writing], when I call `decline_research()`, then it
  returns true, both techs are back in the research deck (3 cards, reshuffled), no wealth is spent,
  `research_left()` stays 0, and `research_options()` is empty. With no options open,
  `decline_research()` returns false.
- [ ] AC8 (can't research): `research()` returns false and changes nothing when `research_error()`
  isn't "". The messages:
  - game over: "The game is over."
  - explore choice pending: "Choose a territory first."
  - hand-limit discard pending: "Discard down to 7 cards first."
  - no charge left: "No research left this turn."
  - empty research deck: "The research deck is empty."

  With 1 tech left, `research()` reveals just that one, and it can be bought or declined.
- [ ] AC9 (charges reset): Each turn starts with `research_left()` 1. Unused charges don't carry over:
  end turn 1 without researching, and turn 2 has 1, not 2.

## Out of scope
- Passes, discounts, prerequisites and removal (026).
- Eras, `add_era`, Library and extra research charges (027).
- Real tech content in `data/` (028).
- Tech tags counting for `gain_per_tag` (it counts the tableau only).

## Design notes
- Card type `tech`: permanent. `CardDef.is_permanent()` already treats every non-action as
  permanent. Techs have no territory.
- Config: `research_deck` {tech_id: count}, parsed like `territory_deck` (reuse `_parse_counts` with a
  type check for `tech`).
- New zones: `research_deck`, `research_reveal`, `researched`.
- Engine API:
  - `research_left() -> int`: charges left this turn. `_start_turn` resets it to 1 before upkeep
    (027 adds charges during upkeep).
  - `research_error() -> String`, `research() -> bool`: spend a charge, reveal the top 2 (or 1).
  - `research_options() -> Array[int]`: revealed uids, top first; empty when nothing is open.
  - `tech_cost(uid) -> int`: current wealth cost. In 025 this is the printed cost; 026 adds discounts.
    The UI shows this value and never calculates it.
  - `buy_tech_error(uid) -> String`, `buy_tech(uid) -> bool`: pay `tech_cost`, move the tech to
    `researched`, resolve its `play` effects, and shuffle the other revealed techs back into the
    research deck (the whole research deck is reshuffled with the engine RNG).
  - `decline_research() -> bool`: shuffle all revealed techs back.
- `score()` adds the printed VP of `researched` cards. `_start_turn` resolves upkeep for
  `researched` cards too.
- Open research options block play, grow, discard and end turn, like the explore choice. The
  message is "Buy a tech or decline first."
- 023 (more wealth sinks) overlaps with this. Rerun its wealth numbers after 028 before building it.
- UI:
  - a Research button with the charges left and the research deck count, disabled with
    `research_error()` as its tooltip
  - the choice panel shows the revealed techs with their cost, a Buy button each (disabled with
    `buy_tech_error`), and Decline
  - a Researched row next to the tableau.
- PLAN.md: add a Techs section and a research step to the play phase.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_research::test_tech_with_a_wealth_cost_loads`, `test_tech_food_cost_is_an_error`, `test_tech_zero_wealth_cost_is_an_error`, `test_tech_mixed_cost_is_an_error`, `test_tech_without_a_cost_is_an_error`, `test_tech_keyword_effect_is_an_error`, `test_tech_targeting_effect_is_an_error` |
| AC2 | `test_research_deck_is_normalized`, `test_research_deck_defaults_to_empty`, `test_research_deck_unknown_card_is_error`, `test_research_deck_non_tech_is_error`, `test_research_deck_count_below_1_is_error`, `test_tech_in_the_main_deck_is_error` |
| AC3 | `test_new_game_shuffles_the_research_deck_by_seed`, `test_new_game_starts_with_one_charge_and_nothing_researched`, `test_no_research_deck_means_nothing_to_research` |
| AC4 | `test_research_reveals_the_top_two`, `test_open_options_block_play_grow_discard_end_turn_and_research` |
| AC5 | `test_buying_a_tech_pays_for_it_and_moves_it_to_researched`, `test_buying_shuffles_the_other_techs_back_into_the_deck`, `test_play_and_end_turn_work_again_after_buying`, `test_cannot_afford_a_tech`, `test_cannot_buy_a_tech_that_was_not_revealed`, `test_tech_cost_is_the_printed_wealth_cost` |
| AC6 | `test_buying_a_tech_resolves_its_play_effects`, `test_a_tech_scores_its_vp_and_works_at_upkeep` |
| AC7 | `test_declining_returns_both_techs_and_spends_nothing`, `test_decline_does_nothing_without_open_options` |
| AC8 | `test_research_error_when_the_game_is_over`, `..._while_an_explore_choice_is_pending`, `..._while_a_discard_is_pending`, `..._with_no_charge_left`, `..._with_an_empty_research_deck`, `test_researching_with_one_tech_left_reveals_just_that_one` |
| AC9 | `test_each_turn_starts_with_one_charge`, `test_unused_charges_do_not_carry_over` |

## Manual check
Run the game with a temporary research deck in `data/config.json` (the real content comes in 028).
- [ ] The Research button shows 1 charge and the deck count. After researching it is disabled, with
  "No research left this turn." as the reason.
- [ ] The panel shows 2 techs with costs. An unaffordable Buy is disabled with the reason. Decline
  closes the panel.
- [ ] A bought tech appears in the Researched row, and its VP shows in the score.

## Log
