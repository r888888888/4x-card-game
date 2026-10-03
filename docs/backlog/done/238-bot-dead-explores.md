---
id: 238
title: The bot plays an explore-only card with nothing left to explore
type: bug
status: done
branch: fix/238-bot-dead-explores
---

## Reproduction
- Seed: 1–8, any strategy (`ScriptedBot.play` on the real data, 100 turns).
- Steps:
  1. Play until the territory deck runs out.
  2. Draw Scout (since 235 its only effect is `explore`: it costs an action and refunds nothing).
- Expected: the bot keeps the action for another card, or ends the turn with Scout in hand.
- Actual: the bot plays Scout and logs "Scout: no territories left to explore." A probe over seeds 1–8 counted 54
  (tall) to 197 (growth) such plays per strategy; wealth had 0.

## Acceptance criteria
- [x] AC1: Given a game whose territory deck is empty and a hand of a card whose only effect is `explore` and
  a card that gains 1 food, when the bot takes its turn, then it plays the food card and not the explore card,
  which stays in the hand.
- [x] AC2: Given the same empty territory deck and a hand of only the explore card, when the bot takes its turn,
  then it plays no card (the action is unspent).
- [x] AC3: Given a territory deck with 1 territory and a hand of only the explore card, when the bot takes its turn,
  then it plays it and the territory is in the frontier (explore still happens while there is something to find).
- [x] AC4: Given an empty territory deck and a hand of a card that explores and also gains 1 food, when the bot takes
  its turn, then it plays it (only cards that do nothing but explore are skipped).

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_sim::test_bug_238_the_bot_skips_an_explore_only_card_with_nothing_to_explore` |
| AC2 | `test_sim::test_bug_238_with_only_an_explore_only_card_the_bot_plays_nothing` |
| AC3 | `test_sim::test_bug_238_the_bot_still_explores_while_a_territory_is_left` (guard: passes before the fix) |
| AC4 | `test_sim::test_bug_238_the_bot_plays_a_card_that_explores_and_does_more_with_nothing_to_explore` (guard) |

## Root cause
`ScriptedBot._play_first_playable` played any card `play_error` allowed, and the engine allows exploring an empty
territory deck (it logs "no territories left to explore"). Before 235 Scout drew a card and refunded its action, so
the waste was invisible; now it costs an action. The bot now skips a card whose effects are all `explore` while the
territory deck is empty (`_explores_nothing`). No test covered the bot with an empty territory deck.

## Log
- 2026-10-03: Found while checking the bot against the changes since 158 (156, 157, 232, 235). Siblings: 239 (the
  bot spends wealth), 240 (the lookahead values research).
- 2026-10-03: Red. Fixtures Forager (+1 food) and Pathfinder (explore, +1 food) added to TEST_CARDS. AC2 counts
  card_played instead of actions_left: the fixture game has no action limit, so an unspent action can't be seen.
- 2026-10-03: Green: 1515 → 1519 tests; balance suite green.
