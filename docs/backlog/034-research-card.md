---
id: 034
title: Research is a card, not a free action each turn
type: feature
status: red-review
branch: feat/034-research-card
---

## Goal
Researching becomes something the player builds their deck around. The free research charge each
turn and the Research button go away. Instead, a Research action card reveals the top 2 techs when
played. The deck starts with 1 Research card, and 2 more can be bought from the supply.

## Acceptance criteria
Fixtures: TEST_CARDS gets `study` ("Research", action, cost {}, effects `[{op: research}]`). The
tech fixtures (pottery, writing, bronze) and the research deck [pottery, writing, bronze] (top first)
come from `test_research.gd`, with starting resources `{food: 2, wealth: 10}`.

- [ ] AC1 (op): `{"op": "research"}` loads with no other fields. Its short text is "Research" and its
  tooltip is "Research: reveal 2 techs, buy 1 or decline". A `research` effect with
  `"trigger": "upkeep"` is a load error that names the card and the effect index. `amount` is an
  unknown field (load error), like any other unknown field.
- [ ] AC2 (play reveals): Given `study` in hand, when I `play_card(study uid)`, then it returns true,
  Research is in the discard, `research_options()` is [pottery uid, writing uid], and the research deck
  holds only Bronze Working. Buying and declining then work as in 025/026 (for example, buying Pottery
  leaves wealth at 8).
- [ ] AC3 (no free research): There are no research charges. The engine has no `research()`,
  `research_left()` or `research_error()`, and a new game, or a new turn, opens no tech options on its own.
- [ ] AC4 (no limit per turn): Given 2 `study` in hand and a research deck of 4 techs, when I play
  one, buy a tech, and play the other, then the second play reveals 2 techs again.
- [ ] AC5 (can't play): With the research deck and future techs both empty, `play_error(study uid)` is
  "The research deck is empty." and `play_card` returns false, with the card still in hand. It can
  still be discarded. With only future techs left, playing it adds the lowest future era first, as the
  button did. With tech options open, `play_error` is "Buy a tech or decline first." (unchanged).
- [ ] AC6 (Library): The Library fixture in `test_tech_eras.gd` becomes play: `create study` into the
  discard. Building it puts a new Research card on top of the discard. It has no upkeep effect, and
  the next turn opens no tech options.
- [ ] AC7 (content): `data/cards.json` has `research` ("Research", action, cost {}, 0 VP, no tags,
  `[{op: research}]`). Config: deck gets `research: 1` (23 cards); supply gets
  `research: {price: 3, count: 2}`. The Library's effect becomes create `research` in the discard.
  The real data loads with no errors.

## Out of scope
- Other ways to gain research (techs or buildings other than the Library).
- Changing how revealing, buying, passes, discounts or eras work.
- Rebalancing tech prices or era thresholds for the slower research pace.

## Design notes
- The `research` op changes meaning: it used to add charges, and now it reveals the top 2 techs
  (the old `GameEngine.research()` body). It is play-only, with no fields.
- `play_error` needs a check for a card whose `research` effect has nothing to reveal. Add a hook on
  `Effect` (for example `play_block_error(engine) -> String`, "" by default) rather than hard-coding
  the op in the engine.
- Remove `_research_left`, `research_left()`, `research()`, `research_error()` and `add_research()`.
  The reveal logic moves to an engine method that the effect calls (like `explore`).
- Approved tests this replaces (intended behavior change): in `test_research.gd`, the charge tests for
  025 AC3, AC8 and AC9 (`..._starts_with_one_charge...`, `test_research_error_*`,
  `test_each_turn_starts_with_one_charge`, `test_unused_charges_do_not_carry_over`). Tests that call
  `e.research()` to open options switch to playing `study`. In `test_tech_eras.gd`, the Library charge
  tests and its "⟳ +1 research" text test are replaced by AC6. The scripted game in `test_content.gd`
  plays Research cards instead of calling `research()`. `test_a_tech_unlocks_the_library` checks that
  the Library creates `research` instead of granting research.
- UI: remove the Research button and its R shortcut. Keep the research deck count, era and lost count
  visible, as a label in the side column. The research overlay opens from `play_card` as it does now.
- Price 3 is a first guess (like Settler and Temple). Tune after playtesting.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_tech_eras::test_research_op_loads_with_no_fields`, `test_research_op_at_upkeep_is_an_error`, `test_research_op_amount_is_an_unknown_field`, `test_era_and_research_card_text` |
| AC2 | `test_research::test_playing_a_research_card_reveals_the_top_two`; buy/decline/pass tests in `test_research`, `test_tech_passes`, `test_tech_eras`, `test_supply` now open research with `play_research` |
| AC3 | `test_research::test_there_are_no_research_charges` |
| AC4 | `test_research::test_two_research_cards_can_be_played_in_one_turn` |
| AC5 | `test_research::test_a_research_card_cannot_be_played_with_nothing_to_research`, `test_tech_eras::test_an_empty_research_deck_with_no_eras_left_is_an_error`, `test_an_empty_research_deck_adds_the_next_era`, `test_research::test_open_options_block_play_grow_discard_end_turn_and_research` |
| AC6 | `test_tech_eras::test_building_a_library_creates_a_research_card`, `test_a_library_does_nothing_at_upkeep` |
| AC7 | `test_content::test_real_research_card_starts_in_the_deck_and_is_sold`, `test_a_tech_unlocks_the_library`, `test_scripted_games_buy_techs_and_never_go_negative` (plays Research cards) |

## Manual check
- [ ] Start a game. There is no Research button. The side column shows the research deck count and
  era. The deck counter starts at 23 cards.
- [ ] The Supply lists "Research · 3 wealth · 2 left".
- [ ] Play the Research card: the tech overlay opens with 2 techs. Buy or decline closes it, and the
  card is in the discard.
- [ ] Build a Library: a Research card appears in the discard.

## Log
- 2026-09-29: User chose: reveal on play (no charges), Library creates a Research card when built,
  free to play and priced 3 in the supply, can't be played with nothing to research.
- 2026-09-29: Approved by the user.
