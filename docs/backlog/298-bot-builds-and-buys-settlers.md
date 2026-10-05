---
id: 298
title: The sim bot builds, recruits and keeps Settlers
type: feature
status: blocked
branch: feat/298-bot-builds-and-buys-settlers
---

## Goal
After 295–296 buildings and units come from the build menu, so a bot that only plays its hand never builds and the
simulator stops measuring anything real. After this, `ScriptedBot` builds and recruits as part of its play order, and
the expanding strategies buy Settlers on purpose instead of relying on wealth dumped before Anarchy's drain (the
spike's baseline and wide played half as many Settlers without it). Follows 296 (independent of 299 and 297); the balance item that retunes costs
comes after this one.

## Acceptance criteria
- [ ] AC1: Given a fixture game played by the growth bot with Scout and Research in hand, 2 actions, enough food, and
  a buildable Farm entry (Farm makes food on upkeep, so growth prefers it), when `take_turn` runs, then the Farm is
  built first and the Scout played second, and Research stays in the hand. Order: the strategy's preferred hand cards,
  then its preferred build-menu entries, then the rest of the hand, then the other entries, then cards that gain
  insight; among entries, the costliest (total of its cost) first; each step skips what `build_error` or
  `play_error` refuses, as today.
- [ ] AC2: Given the baseline bot with the same hand and menu, when `take_turn` runs, then the Scout is played first and
  the Farm built second (baseline prefers nothing, so hand cards come before entries); Research stays.
- [ ] AC3: The bot builds an entry on the first territory in `build_targets` order that `build_error` allows, and skips
  an entry whose play effects would push unrest to the limit (the `_unrest_ok` check hand cards get).
- [ ] AC4: The bot recruits a unit entry only while it has fewer units in the tableau than settled territories (one
  garrison each until 168 gives it a raid rule): given 2 settled territories and 2 units, it recruits none; with 1
  unit, it may recruit one.
- [ ] AC5: Given the baseline or wide bot at the end of `take_turn` with wealth ≥ the Settler's buy price, land left
  (the territory deck or the frontier not empty) and fewer than 3 Settlers in its deck, hand and discard together,
  then it buys 1 Settler. It buys none when it already holds 3, when no land is left, when it can't pay, or as the
  growth, wealth or tall strategy.

## Out of scope
- Tuning costs, wealth income or strategy weights (the balance item after this).
- Raid defence (168).

## Design notes
- Spike code to start from: `_play_order` and `_build` in `sim/bot.gd` on `spike/rotating-supply` (0a53674); it lacked
  AC4 and AC5.
- The Settler rule names Settlers by effect (`_settles`, an effect `settle`), not by id, like the bot's other rules.
- Bot rules are tested on fixture games of a few turns (`tests/test_bot_spending.gd` and kin); real-data bot games stay in
  `tests/balance/`.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_bot::test_…` |

## Manual check
- [ ] Run `scripts/sim.sh 20` before and after and note in the Log how Settlers played, buildings built and score moved
  per strategy (no tuning here).

## Log
- 2026-10-05: blocked: to be superseded by 314 (the generic bot); don't build. 314 closes it as wontfix.
