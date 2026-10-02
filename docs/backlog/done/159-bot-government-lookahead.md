---
id: 159
title: The bot chooses governments and revolts by looking ahead
type: feature
status: done
branch: feat/159-bot-government-lookahead
---

## Goal
The sim bot judges governments by playing them out instead of by a fixed ranking, so balance runs reflect what a
government is worth (Theocracy's research cost included) and the bot revolts when a change pays off. From
`spike/revolution`.

## Acceptance criteria
- [x] AC1: When the government choice is owed, `ScriptedBot` forks the engine once per option, chooses it, plays
  `LOOKAHEAD_TURNS` (12) turns with the same strategy (or to the game's end), and chooses the option whose fork
  scores highest (ties: zone order). With one option it chooses it without forking.
- [x] AC2: Every `REVOLT_EVERY` (4) turns, at the end of the turn, it compares a fork that doesn't revolt with one fork
  per government in the deck that revolts and then chooses that government; it revolts if any revolting fork scores
  higher. It doesn't weigh a revolt in the last LOOKAHEAD_TURNS ÷ 2 turns.
- [x] AC3: Inside a lookahead the bot never revolts and chooses the government its fork was opened for, else 154's
  ranking. A lookahead changes nothing in the real game (state, log, signals).
- [x] AC4: With fixtures where one government clearly scores more (⟳ +3 VP against nothing), the bot chooses it, and
  revolts to it from a ruling government that scores nothing.

## Out of scope
- Valuing research beyond score in the lookahead (the spike's caveat; a later bot item if balance needs it).

## Design notes
- Replaces 155 AC7's revolt rule; restore order stays as 155 AC7.
- Cost: the spike's version slowed a 20-seed sweep of every strategy to ~5 minutes on 12 cores; tests use small
  fixture games only (no many-seed runs in the suite).

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_the_bot_chooses_the_government_whose_lookahead_scores_most`, `test_with_one_option_the_bot_chooses_it`, `test_lookahead_ties_go_to_zone_order` |
| AC2 | `test_the_bot_revolts_every_4_turns_when_a_revolution_scores_more`, `test_the_bot_doesnt_revolt_when_no_revolution_scores_more`, `test_the_bot_doesnt_weigh_a_revolt_in_the_last_half_lookahead` |
| AC3 | `test_a_lookahead_changes_nothing_in_the_real_game`, `test_a_lookahead_chooses_the_government_it_was_opened_for`, `test_inside_a_lookahead_the_bot_never_revolts`, `test_a_lookahead_stops_at_the_games_end`, `test_the_ranking_prefers_most_actions_then_highest_limit_then_deck_order` |
| AC4 | the Glory fixtures in AC1 and AC2 |
| (removed) | test_revolution: 155's `test_the_bot_revolts_to_a_better_government_when_anarchy_would_last_1_turn`, `test_the_bot_doesnt_revolt_otherwise`; test_government_deck: `test_the_bot_chooses_the_government_with_most_actions_then_highest_limit`, `test_the_bot_breaks_government_ties_by_deck_order` (now the ranking test) |

## Log
- 2026-10-01: Built on 155's branch. The lookahead made the real-data sim tests take minutes (suite 45 s → 157 s, past
  the Stop hook's 120 s); at the user's request those moved to a balance suite (`chore/balance-suite`,
  `scripts/test.sh --balance`), merged into this branch: main suite 31 s. 158 is rebuilt on this branch so its
  revolution fixture follows the lookahead rule.
- 2026-10-01: Specced from `spike/revolution` (`sim/bot.gd` at commit d8b7a75 has a working version; the branch is deleted: `git show d8b7a75:sim/bot.gd`).
