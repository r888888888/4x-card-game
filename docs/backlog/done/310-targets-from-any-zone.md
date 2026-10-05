---
id: 310
title: Ask what a card would target from any zone, not only the hand
type: feature
status: done
branch: feat/310-targets-from-any-zone
---

## Goal
The generic bot (313) values its deck by what each card could do now. A card with nothing to act on (a settler and no
frontier, a building and no free slot) is worth nothing yet, and exploring is worth what it gives such a card. Today
`needs_target` and `valid_targets` answer only for hand cards, so the spike read `CardPlay` and `Territories`
internals. After this, the engine says what any card would target if it were in the hand.

## Acceptance criteria
- [x] AC1: Given a Farm in the deck and the homeland with a free slot, then `would_need_target(farm)` is true and
  `would_target(farm)` is `[homeland uid]`, what `valid_targets` returns for a Farm in the hand.
- [x] AC2: Given a Pioneer (settle) in the discard and an empty frontier, then `would_target(pioneer)` is `[]`; after an
  Explorer is played and a territory chosen into the frontier, it is `[that territory's uid]`.
- [x] AC3: Given a card in the hand, then `would_need_target` and `would_target` equal `needs_target` and
  `valid_targets` for it; for a Forager (no target) anywhere, `would_need_target` is false and `would_target` is `[]`.
- [x] AC4: Given a uid in no zone, or the game over, then `would_need_target` is false and `would_target` is `[]`. Both
  queries change nothing (the card stays in its zone, nothing is logged or emitted).

## Out of scope
- Whether the card is affordable or allowed now (`play_error` stays the hand's answer).
- Changing `needs_target` or `valid_targets`, which the UI calls for hand cards.

## Design notes
- New queries on `EngineQueries`: `would_need_target(uid) -> bool` and `would_target(uid) -> Array[int]`, sharing
  `CardPlay.targets_of` with `valid_targets` (pass the card, not a hand lookup). Add both to `QUERIES` in
  `tests/test_engine_structure.gd`.
- A card in the reveal or frontier is the target, never the one targeting: the queries look up the card in any zone.
- Spike reference: `GenericBot.has_targets` on `spike/generic-bot`.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_would_target::test_a_farm_in_the_deck_would_target_the_territory_with_a_free_slot`, `test_engine_structure` (both queries declared in `engine_queries.gd`) |
| AC2 | `test_would_target::test_a_pioneer_in_the_discard_has_a_target_once_a_territory_is_discovered` |
| AC3 | `test_would_target::test_for_a_hand_card_the_answers_match_needs_target_and_valid_targets`, `test_a_forager_anywhere_needs_no_target` |
| AC4 | `test_would_target::test_a_uid_in_no_zone_or_a_finished_game_has_no_targets`, `test_asking_changes_nothing` |

## Log
- 2026-10-05: specced from the generic-bot spike, with 309, 311–315.
- 2026-10-05: built on `CardPlay.needs_target` / `targets_for` (295's build menu already used `targets_for` for a new
  copy) with an `_anywhere(uid)` lookup that answers null after game over. `engine_queries.gd` is now 485 lines, close
  to `test_engine_structure`'s 500: the next query added there may need a split (311 and 312 add theirs elsewhere).
