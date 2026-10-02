---
id: 172
title: One pending-decision model
type: feature
status: review
branch: feat/172-one-pending-model
---

## Goal
A decision the player owes is one thing in the state, not four (`pending_choice`, `discard_left`, `renewal_left`,
`choosing_government`), and every decision's action checks it the same way. 155 adds a revolt pending and moves the
government choice to `end_turn`, and later decisions (raids, unit moves) would each add a field, a copy line and their
own checks. From the 2026-10-01 project review.

## Acceptance criteria
- [x] AC1: `GameState.pending` (a Dictionary, `{}` when nothing is owed) replaces the four fields. `pending()` returns
  a copy of it in today's shapes: `{kind: PENDING_EXPLORE, options, source}` (`source` a uid, as now),
  `{kind: PENDING_DISCARD, count, options}`, `{kind: PENDING_RENEWAL, count, options}`,
  `{kind: PENDING_GOVERNMENT, options}`. The explore source is stored as a uid, so `copy()` needs no remapping.
- [x] AC2: Each decision's own action checks it the same way: game over first ("The game is over."), then another
  owed decision (that decision's blocked message), then its own "nothing owed" message. Given an explore choice is open,
  `renew_error(uid)` is "Choose a territory first." (today "Nothing to renew."); given the game is over,
  `choose_government_error(uid)` is "The game is over." (today "No government to choose."). `choose_error`,
  `discard_error`, `renew_error` and `choose_government_error` keep their other messages.
- [x] AC3: `EngineCore.pending_choice` is gone; `sim/bot.gd` and the tests use `pending()`. The tests that read the
  removed fields (test_explore, test_hand_limit, test_actions, test_changed, test_growth, test_population, test_supply,
  test_ui_queries, test_game_state, test_pending) are rewritten on `pending()` with the same assertions, and listed at
  the red checkpoint.
- [x] AC4: In `engine/game_engine.gd` every action sits under `# --- Actions ---` beside its error query (`grow`,
  `revolt`, `renew`, `restore_order`, `choose_government` and `relieve_famine` move there).
- [x] AC5: Behavior is pinned: `scripts/sim.sh 20` prints the same before and after; 171's guards pass unedited; every
  other existing test passes unedited.
- [x] AC6: A new `add-decision` skill (`.claude/skills/add-decision/SKILL.md`) lists the steps of a new decision kind on
  this model: the `PENDING_*` constant, setting and clearing `state.pending`, the `_blocked_error` message, the action
  and its error query, the `ChoiceOverlays` row, `main.gd`'s refresh row and pick branch, `card_focus.gd` keys, the bot,
  and rows in 171's table. CLAUDE.md gains: "A decision the player owes is one `PENDING_*` kind in `pending()`; every
  action's `*_error` starts with `_blocked_error`." `docs/development-process.md`'s Files table lists the skill.

## Out of scope
- New decision kinds (155's revolt, the military items' moves).

## Design notes
- `_blocked_error(action)` reads `state.pending.kind`. A helper such as `_owed_error(kind, nothing_msg)` gives AC2's
  order for the decision actions.
- `test_ui_structure`'s `INTERNALS` drops `pending_choice` and `discard_left` (gone) and keeps `.state.`.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_pending::test_the_state_holds_one_pending_decision`, `test_pending::test_pending_returns_a_copy` (the shapes: test_pending's existing tests) |
| AC2 | `test_blocking::test_each_decision_action_names_game_over_then_the_owed_decision_then_nothing_owed` |
| AC3 | `test_pending::test_the_engine_has_no_pending_choice`; rewritten on `pending()`: test_explore (5 tests), test_growth, test_hand_limit, test_ui_queries, test_population, test_changed, test_supply (`test_cannot_buy_while_an_explore_choice_is_pending` sets `state.pending`); test_ui_structure's `INTERNALS` |
| AC4 | `test_blocking::test_every_action_sits_under_actions_beside_its_error_query` |
| AC5 | 171's guards and every other test unedited; `scripts/sim.sh 20` before and after (Manual check) |
| AC6 | Docs: the `add-decision` skill, CLAUDE.md, `docs/development-process.md` |

## Manual check
- [x] `scripts/sim.sh 20` prints the same on `main` and on this branch (Claude runs both and pastes the comparison in
  the Log).

## Log
- 2026-10-01: Specced from the project review. Decided: one dictionary (not just consistent checks on four fields).
- 2026-10-01: Red. AC2 read as one rule for all four decision actions, so beyond the two named changes: `choose_error`
  says "The game is over." at game over and the owed decision's message while a discard, renewal or government choice
  is owed (today "There is no territory to choose."); `renew_error` and `choose_government_error` likewise give the
  game-over or owed-decision message before their "nothing owed" one. `discard_error` already did. AC4 puts
  `end_turn_error`, `play_error`, `buy_error` and `buy_tech_error` under Actions too, each beside its action;
  `supply_error` stays a query (the supply screen isn't an action). test_game_state and test_actions only name the
  old field in a test name, so they need no rewrite.
- 2026-10-01: Green. `GameState.pending` holds `{kind, count}` for a discard or renewal, `{kind}` for the government
  choice and `{kind, options, source}` for explore; `pending()` duplicates it and adds the live options (hand,
  renewal options, government deck) as before. `_owed_error(kind, nothing_owed)` starts `choose_error`,
  `renew_error` and `choose_government_error`. Explore's log line looks the source card up by uid. `scripts/sim.sh 20`
  is identical to `main`'s (diffed). New `add-decision` skill; CLAUDE.md, PLAN.md, development-process and testing docs
  updated.
