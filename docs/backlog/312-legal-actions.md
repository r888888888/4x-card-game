---
id: 312
title: legal_actions lists every action the engine would allow now
type: feature
status: ready
branch: feat/312-legal-actions
---

## Goal
Each new mechanic has needed its own bot rule (298, 303, 168) because the bot only knows the actions someone wrote a
rule for. After this, the engine lists every action it would allow right now, each with its arguments, so a bot (313)
can consider all of them, and the suite fails when a new action isn't listed, so a mechanic reaches the bot the day
it lands.

## Acceptance criteria
- [ ] AC1: Given a fixture game with nothing owed, when `legal_actions()` is called, then it returns entries
  `[action, args…]`: `["play_card", uid, target]` for each hand card and each of its `valid_targets` (target −1 for a
  card that needs none), `["buy", id]` per open supply pile, `["buy_tech", uid]` per research-deck tech,
  `["contribute", uid, contribute_limit]` per site with a limit above 0, `["move_unit", uid, territory]` per move
  target, `["discard_card", uid]` per hand card, the argument-free actions (`relieve_famine`, `restore_order`, `revolt`,
  `abandon`/`disband` per card) and `["end_turn"]`, each only when its error query returns "" for those arguments.
- [ ] AC2: Every entry is legal: for each, the action's error query called with its args returns "". Given a Farm in
  the hand and food 1 (it costs 2), no `play_card` entry names it; given wealth below every buy price, no `buy` entry.
- [ ] AC3: Given an owed decision, only its options are listed: explore → `["choose", uid]` per option; event choice →
  `["choose_option", i]` per option `choose_option_error` allows; government → `["choose_government", uid]` per option;
  hand-limit discard → `["discard_card", uid]` per hand card; renewal → one entry `["renew", options, count]`, meaning
  any `count` of `options` (`renew_error` is "" for the first `count`).
- [ ] AC4: After game over it returns `[]`.
- [ ] AC5: The list is in a fixed order (the order above, each zone in its order) and changes nothing: called twice it
  returns equal lists, and a fork's list equals the game's.
- [ ] AC6: The suite checks coverage: every `GameEngine` action that has an error query (found the way
  `test_blocking.gd` finds them), except `new_game` and `rename_territory`, has a row in a table that sets up a game
  where `legal_actions()` lists it. A new action with an error query and no row fails the suite.

## Out of scope
- Bots using it: 313. Choosing amounts other than `contribute_limit` (one entry per site is enough for a bot).
- `build` (295) and upgrades (300): they join when they land, through AC6's table.

## Design notes
- New query on `EngineQueries` (or a `LegalActions` module it calls, to keep the file under 700 lines):
  `legal_actions() -> Array`. Each entry's action name is the method to call; its error query is `<action>_error`,
  except `play_card` → `play_error` and `discard_card` → `discard_error` (the `ERROR_OF` table `test_blocking.gd`
  already has; move it to the engine so both use one).
- Renewal is one "choose count of" entry because listing every combination can run to thousands.
- Spike reference: `GenericBot.candidates` and `decision_options` on `spike/generic-bot`.
- When this lands, the `add-decision` skill's "the sim bot" step becomes "a `legal_actions` entry for the decision";
  `add-effect` needs nothing.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_legal_actions::test_…` |

## Log
- 2026-10-05: specced from the generic-bot spike, with 309–311, 313–315.
