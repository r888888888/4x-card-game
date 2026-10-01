---
id: 136
title: Clicking a civilization on the new game screen errors in play_cost
type: bug
status: review
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
- [x] AC1: Given a `GameEngine` built from test cards and config with `new_game` not yet called, when `play_cost(-1)`
  is called, then it returns `{}` and raises no script error.
- [x] AC2: Given a started game, when `play_cost` is called with a uid that isn't in the hand, then it still returns
  `{}` (unchanged).

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_discounts::test_bug_136_play_cost_is_empty_before_a_game_starts` |
| AC2 | `test_discounts::test_bug_136_play_cost_is_empty_for_a_card_not_in_the_hand` (guard; passed before the fix) |

## Root cause
`play_cost` assumed a hand zone exists, but `Game.engine` is built at startup and only gets zones in `new_game`.
The new game screen's civilization details draw a hand card (to show its cost) before any game, so the query hit
the missing zone. Every test engine came from `make_engine`, which always calls `new_game`, so no test asked an
unstarted engine. Fix: `play_cost` returns `{}` when there's no hand.

## Manual check
- On the new game screen, click each civilization: its details open and the console shows no script error.

## Log
- 2026-10-01: reported from the console when selecting a civilization.
- 2026-10-01: fixed; suite 936 → 938 tests, green.
