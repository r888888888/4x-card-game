---
id: 140
title: Open tech tree: learn any tech whose prerequisite you have
type: feature
status: done
branch: feat/140-open-tech-tree
---

## Goal
Research becomes something you plan, not a draw. Every tech whose prerequisite is researched is on offer in the tech
tree, and the player learns one by spending Insight, whenever they like, with no card or action. Prerequisites become
hard (no Iron Working before Bronze Working), and the Research card simply makes Insight. Reveal-2, passes and lost
techs go. Follows 139; tried on `spike/research-insight`.

## Acceptance criteria
- [x] AC1: Given a research deck of Pottery (2 insight) and Writing (3 insight), 2 insight and 2 actions left, when
  the player calls `buy_tech` on Pottery with no card played, then Pottery is in `researched`, insight is 0, Writing
  is still in `research_deck`, Pottery's play effects have resolved and 2 actions are still left.
- [x] AC2: Given Iron Working (prereq Bronze Working) in the research deck and Bronze Working not researched, with 20
  insight, then Iron Working's `tech_tree()` state is `GameEngine.TECH_LOCKED` and `buy_tech_error` is
  `"Iron Working needs Bronze Working first."`. When Bronze Working is bought, then Iron Working's state is
  `TECH_AVAILABLE` and it can be bought.
- [x] AC3: `buy_tech_error` refuses, and `buy_tech` changes nothing, for: a tech not in the research deck (researched
  or in a future era) → `"That tech isn't on offer."`; too little insight → `"Pottery needs 2 insight (you have
  1)."`; the game over → `"The game is over."`; an explore choice open → `"Choose a territory first."`. While a
  hand-limit discard is owed, learning is allowed (like buying from the supply).
- [x] AC4: Given era 2 techs waiting in `future_techs` and Pottery as the only tech left in the research deck, when
  Pottery is bought, then `era()` is 2 and the era 2 techs are in the research deck.
- [x] AC5: The reveal is gone: a card with `{"op": "research"}` fails to load as an unknown op; `prereq_discount` is an
  unknown field (warning); `pending()` never reports a research choice; the engine has no `research_reveal` or
  `lost_techs` zone, no passes and no `TECH_LOST`, and `tech_tree()` entries carry `uid` (−1 for a future tech) and
  no `passes`. `research_card_name()` names the first deck-then-supply card whose effects gain insight.
- [x] AC6: Given the tech tree open, then an available tech's tile has a "Learn" button, disabled with
  `buy_tech_error` as its tooltip when that is non-empty; clicking an enabled one learns the tech and the tree
  refreshes with it marked ✔ Researched. A locked tech shows 🔒 Locked and "needs Bronze Working" and has no
  Learn button. The tree's header reads `"Insight 5 · play a Research card for more"`, and the board has no research
  choice overlay.
- [x] AC7: Given a sim game whose bot has 2 insight and Pottery learnable, when the bot takes its turn, then it learns
  the cheapest tech it can afford before playing cards (`ScriptedBot` no longer declines or buys from a reveal).

## Out of scope
- Eurekas (141) and diffusion (142).
- Iron Age content, the era-3 opener and pacing (143).
- Making Insight scale with the empire (see 143's Design notes: tall strategies research slowly).

## Design notes
- `Research.buy` takes the tech from `research_deck`; after a buy, an empty research deck adds the lowest waiting era
  (today that happens on reveal). `Research.prereq_met(def)`. `TECH_LOCKED` is computed in `tech_tree()` for a tech in
  the research deck whose prereq isn't researched.
- Removed: `reveal_techs`, `reveal_techs_error`, `decline_research`, `decline_research_error`, `research_options`,
  `tech_passes`, `MAX_PASSES`, `PENDING_RESEARCH`, `CardInstance.passes`, `CardDef.prereq_discount`, zones
  `research_reveal` and `lost_techs`, `engine/effects/research_effect.gd` and its registry entry, the research
  overlay in `ui/choice_overlays.gd` and the revealed-tech branch of `main.gd`'s `on_picked`, `CardView.set_tech_info`
  if nothing else uses it. `_DISCARD_ALLOWS` gains `"research"`. Card text: "Needs Bronze Working" replaces
  "-2 wealth with …".
- Supersedes `test_research.gd`, `test_tech_passes.gd` and the reveal parts of `test_tech_eras.gd`,
  `test_tech_tree.gd`, `test_discounts.gd`, `test_pending.gd`, `test_ui_queries.gd`, `test_button_widths.gd`,
  `test_board_labels.gd`, `test_board_row.gd` and `test_card_details.gd`; deleting or rewriting them needs the user's
  OK at the red checkpoint. Fixture: TEST_CARDS' `study` becomes `{"op": "gain", "resource": "insight", "amount":
  3}`; `play_research`, `pass_tech` and `research_engine` go.
- Content: the Research card becomes `+3 insight` (free, 1 action, as now). The Learn button is a `UIKit.button` beside
  the tile (not a card name, per the UI-text rule).
- 7 criteria, more than usual, but reveal-2 can't half-go: the engine, the UI and the bot all change with it.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_research::test_learning_a_tech_needs_no_card_and_no_action`, `test_learning_a_tech_resolves_its_play_effects`, `test_a_tech_scores_its_vp_and_works_at_upkeep`, `test_several_techs_can_be_learned_in_one_turn`; `test_actions::test_learning_a_tech_after_the_last_action_is_free`; `test_changed` (buy_tech emits once) |
| AC2 | `test_research::test_a_tech_whose_prereq_isnt_researched_is_locked`, `test_learning_the_prereq_unlocks_the_tech`, `test_prerequisite_card_text`; `test_tech_tree::test_a_researched_prerequisite_no_longer_lowers_the_cost` |
| AC3 | `test_research::test_a_tech_not_in_the_research_deck_isnt_on_offer`, `test_a_tech_needs_enough_insight`, `test_no_learning_after_the_game_is_over`, `test_no_learning_during_an_explore_choice`, `test_learning_is_allowed_while_a_discard_is_owed`; `test_pending::test_each_pending_kind_blocks_actions_as_before` (buy_tech_error row) |
| AC4 | `test_research::test_learning_the_last_tech_adds_the_next_era`; `test_tech_eras::test_learning_the_last_era_tech_adds_the_next_era`, `test_learning_the_last_tech_with_no_eras_left_adds_nothing`, `test_an_era_added_by_an_empty_deck_is_not_added_again` |
| AC5 | `test_research::test_the_research_op_is_unknown`, `test_prereq_discount_is_an_unknown_field`, `test_the_engine_has_no_reveal_passes_or_lost_techs`, `test_tech_tree_entries_carry_a_uid_and_no_passes`, `test_learning_never_leaves_a_choice_pending`, `test_the_research_card_gains_insight`, `test_research_card_name_*`; `test_card_details::test_a_tech_in_the_research_deck_explains_its_price_now` |
| AC6 | `test_tech_tree_modal::test_an_available_tech_has_a_learn_button_that_learns_it`, `test_a_learn_button_you_cant_use_is_disabled_with_the_reason`, `test_a_locked_tech_says_what_it_needs_and_has_no_learn_button`, `test_the_tree_header_counts_insight_and_names_the_research_card`, `test_the_board_has_no_research_choice`, `test_hints_*` |
| AC7 | `test_sim::test_bot_learns_the_cheapest_tech_it_can_afford` |

## Manual check
- [ ] `godot --path . -- --seed 5`: play a Research card (+3 insight), open Knowledge (T), learn Pottery with its Learn
  button; the tile turns ✔ and Insight drops. Locked techs say what they need.
- [ ] A Learn button you can't afford is disabled and its tooltip says why.

## Log
- 2026-10-01: Built. Engine: `Research.buy`/`buy_error` work on the research deck (blocked → not on offer → prereq →
  insight), `prereq_met`, `TECH_LOCKED`, the next era arrives after the last tech is learned, `tech_tree` entries carry
  `uid` (−1 for a future tech); `"research"` joins `_DISCARD_ALLOWS`. Removed everything in the Design notes list,
  plus the glossary's "Passes" term; "Prerequisite" now says it gates. Card text: "Needs Bronze Working" / tooltip
  "Needs Bronze Working researched first.". Content: the Research card is `+3 insight`.
- UI: the tree's tiles sit in a row with a Learn button while available (it rebuilds the tree after learning);
  🔒 Locked tiles read "needs X"; header "Insight N · play a Research card for more"; the Knowledge tooltip says
  "Play a Research card for more insight."; the research overlay, its Decline button, its focus/pick paths and
  `CardView.set_tech_info` are gone. `Palette.LOST` became `Palette.LOCKED`.
- Bot: `_learn_cheapest_tech` each step before playing cards; non-baseline strategies still play insight cards last.
- Approved in the green phase: deleted `test_board_labels::test_research_choice_is_titled_knowledge` (the overlay is
  gone); `test_button_widths::test_tech_tiles_fill_their_era_column` now checks each tech row fills its column and the
  tile takes what the Learn button leaves.
- Balance worry (for 143 / a balance item): Research is now +3 insight for 1 action, with the Capital +1 and the
  Library +2; era-1 techs cost 6–10. Hard prereqs also slow Masonry and Bronze Working (both need Mining).

