---
id: 048
title: create can target any zone; discarding down to the hand limit emits changed twice
type: bug
status: red-review
branch: fix/048-create-zones-and-changed-once
---

## Reproduction
- Seed: 1
- Steps:
  1. Load a card with `{"op": "create", "card": "farm", "zone": "research_reveal"}`: it loads with no error.
     Playing it puts a Farm in `research_reveal`, which opens a "research" choice with a Farm as the option.
  2. `make_engine({"scout": 10}, {"hand_limit": 5})`, play a Scout (hand 6), `end_turn()` (discard 1 owed), then
     `discard_card` one card: `changed` is emitted twice (once by `_finish_turn`, once by `discard_card`).
- Expected: `create` only targets zones where a new card makes sense; each action emits `changed` once.

## Acceptance criteria
- [ ] AC1: Given a card with a `create` effect whose `zone` is `research_reveal` (also `reveal`, `frontier`,
  `territory_deck`, `research_deck`, `researched`, `lost_techs`, `future_techs`), when it loads, then the error is
  `card 'x': effects[0]: 'zone' must be one of: tableau, hand, discard, deck (got 'research_reveal')`.
- [ ] AC2: `create` into `tableau`, `hand`, `discard` and `deck` still loads and works; the real data still loads.
- [ ] AC3: Given the step 2 setup, when the last owed card is discarded, then `changed` is emitted exactly once.
- [ ] AC4: Each successful action (`play_card`, `choose`, `grow`, `buy`, `buy_tech`, `decline_research`,
  `discard_card`, `end_turn`) emits `changed` exactly once, and a refused one emits none.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_data_loader::test_bug_048_create_refuses_zones_where_a_new_card_makes_no_sense` |
| AC2 | `test_data_loader::test_bug_048_create_loads_into_tableau_hand_discard_and_deck`, `test_rules::test_bug_048_create_puts_the_card_in_each_allowed_zone` |
| AC3 | `test_changed::test_bug_048_discarding_the_last_owed_card_emits_changed_once` |
| AC4 | `test_changed::test_bug_048_each_successful_action_emits_changed_once`, `test_changed::test_bug_048_refused_actions_emit_no_changed` |

## Root cause
<!-- Filled in after the fix. -->

## Log
