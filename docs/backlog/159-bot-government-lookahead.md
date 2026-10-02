---
id: 159
title: The bot chooses governments and revolts by looking ahead
type: feature
status: ready
branch: feat/159-bot-government-lookahead
---

## Goal
The sim bot judges governments by playing them out instead of by a fixed ranking, so balance runs reflect what a
government is worth (Theocracy's research cost included) and the bot revolts when a change pays off. From
`spike/revolution`.

## Acceptance criteria
- [ ] AC1: When the government choice is owed, `ScriptedBot` forks the engine once per option, chooses it, plays
  `LOOKAHEAD_TURNS` (12) turns with the same strategy (or to the game's end), and chooses the option whose fork
  scores highest (ties: zone order). With one option it chooses it without forking.
- [ ] AC2: Every `REVOLT_EVERY` (4) turns, at the end of the turn, it compares a fork that doesn't revolt with one fork
  per government in the deck that revolts and then chooses that government; it revolts if any revolting fork scores
  higher. It doesn't weigh a revolt in the last LOOKAHEAD_TURNS ÷ 2 turns.
- [ ] AC3: Inside a lookahead the bot never revolts and chooses the government its fork was opened for, else 154's
  ranking. A lookahead changes nothing in the real game (state, log, signals).
- [ ] AC4: With fixtures where one government clearly scores more (⟳ +3 VP against nothing), the bot chooses it, and
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

## Log
- 2026-10-01: Specced from `spike/revolution` (`sim/bot.gd` at commit d8b7a75 has a working version; the branch is deleted: `git show d8b7a75:sim/bot.gd`).
