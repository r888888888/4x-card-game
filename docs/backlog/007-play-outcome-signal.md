---
id: 007
title: Report what each card play did
type: feature
status: in-progress
branch: feat/007-play-outcome-signal
---

## Goal
When a card is played, the engine reports what happened: where the card went, what was paid,
what was gained, which cards were drawn or created. The UI (item 008) can then animate each
result, such as food flying to the counter or drawn cards sliding into the hand, without
comparing state before and after or copying rules.

## Acceptance criteria
<!-- All use TEST_CARDS + make_engine. Food is 4 at the start of turn 1 (2 start + 2 Capital upkeep). -->
- [ ] AC1: Given a Farm deck and 4 food, when I play a Farm from hand, then `card_played` is
  emitted exactly once, before `changed`, with outcome
  `{uid: <farm uid>, to_zone: "tableau", paid: {food: 2}, gained: {}, vp: 0, drawn: [], created: []}`.
- [ ] AC2: Given a Scout deck, when I play a Scout (draw 2), then the outcome has
  `to_zone: "discard"`, `paid: {}`, and `drawn` holds the uids of the 2 cards that were on top of
  the deck, in draw order (they are now the last 2 cards in hand).
- [ ] AC3: Given a Caravan deck, 4 food and only the Capital (1 city) on the tableau, when I play a
  Caravan, then the outcome has `paid: {}` and `gained: {food: 2}`, and food is 6.
- [ ] AC4: Given a Settler deck and 4 food, when I play a Settler (cost 3, creates a City), then
  the outcome has `paid: {food: 3}`, `to_zone: "discard"`, and `created` holds exactly the uid of
  the new City, which is on the tableau.
- [ ] AC5: Given a deck of a test action "Shrine" (free, play effect `score 1`), when I play it,
  then the outcome has `vp: 1` and the score goes from 2 to 3.
- [ ] AC6: Given 1 food and a Farm in hand, when I try to play it, then `play_card` returns false
  and `card_played` is not emitted. The same holds after the game is over.

## Out of scope
- Outcomes for upkeep and end-of-turn draws (end-turn animations can get their own item).
- Any UI change (item 008).

## Design notes
- New signal on `GameEngine`: `card_played(outcome: Dictionary)`. Keys: `uid: int`,
  `to_zone: String`, `paid: Dictionary` (resource → amount, only costs > 0), `gained: Dictionary`
  (resource → total from `gain` calls during the play; resources gaining 0 are left out),
  `vp: int` (from `add_score`), `drawn: Array[int]`, `created: Array[int]`.
- Implementation idea: `play_card` starts an outcome dictionary; `gain`, `add_score`, `draw` and
  `create_card` add to it while it is active; `play_card` emits it and then `changed`.
- `play_card` still returns `bool`, so existing callers and tests don't change.
- AC5 adds a `shrine` card to `TEST_CARDS`
  (`{"id": "shrine", "name": "Shrine", "type": "action", "effects": [{"op": "score", "amount": 1}]}`).
  Existing tests don't use it, so they are unaffected.
- **Territories (001–006):** whichever lands second must fit the other. 003 adds `play_card(uid, target_uid)`,
  so the outcome should gain a `target` key. 002's Explore leaves a choice pending during the play,
  so decide whether `choose` emits its own outcome or the play's outcome waits for it.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_play_outcome::test_building_play_reports_tableau_and_cost` |
| AC2 | `test_play_outcome::test_action_play_reports_discard_and_drawn_cards` |
| AC3 | `test_play_outcome::test_gain_effect_reported_in_outcome` |
| AC4 | `test_play_outcome::test_created_card_reported_in_outcome` |
| AC5 | `test_play_outcome::test_score_effect_reported_in_outcome` |
| AC6 | `test_play_outcome::test_failed_play_emits_no_outcome`, `test_play_outcome::test_play_after_game_over_emits_no_outcome` |

## Log
