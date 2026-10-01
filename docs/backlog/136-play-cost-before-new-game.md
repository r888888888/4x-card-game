---
id: 136
title: Clicking a civilization on the new game screen errors in play_cost
type: bug
status: in-progress
branch: fix/136-play-cost-before-new-game
---

## Reproduction
- Seed: any (no game exists yet)
- Steps:
  1. Launch the game and open the new game screen.
  2. Click a civilization card.
- Expected: its details open with no error.
- Actual: the details modal builds its card as a hand card, so `card_face` asks `GameEngine.play_cost(uid)`. Before
  `new_game` the engine has no zones, so `zone("hand")` fails ("Invalid access to property or key 'hand'") and
  `play_cost` then calls `find` on null.

## Acceptance criteria
- [ ] AC1: Given a `GameEngine` built from test cards and config with `new_game` not yet called, when `play_cost(-1)`
  is called, then it returns `{}` and raises no script error.
- [ ] AC2: Given a started game, when `play_cost` is called with a uid that isn't in the hand, then it still returns
  `{}` (unchanged).

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_discounts::test_bug_136_play_cost_is_empty_before_a_game_starts` |
| AC2 | `test_discounts::test_bug_136_play_cost_is_empty_for_a_card_not_in_the_hand` (guard; passes already) |

## Root cause
<!-- Filled in by Claude after the fix. -->

## Manual check
- On the new game screen, click each civilization: its details open and the console shows no script error.

## Log
- 2026-10-01: reported from the console when selecting a civilization.
