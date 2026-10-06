---
name: add-decision
description: Recipe for adding a new kind of decision the player owes (a pending() kind, like explore, discard, renewal or the government choice) test-first. Covers the PENDING_* constant, state.pending, the blocking message, the action and its error query, the choice overlay, main.gd's refresh and pick, card focus keys, the sim bot, and the guard tables. Use when a backlog item makes the game wait for the player's choice before anything else can happen.
---

# Add a decision kind

Use this inside the `tdd` skill's phases. A decision the player owes is one `PENDING_*` kind in `GameState.pending`
(172): while it is owed every other action refuses with one message, and only the decision's own action goes on.
Copy from the government choice (154: `Anarchy.choose_government`) or renewal (147: `Anarchy.renew`).

## Red

1. **Rules tests** for the decision: when it becomes owed, `pending()`'s shape (`{kind, count?, options}`), the action
   resolving it (and clearing it), its error query's messages, and that `legal_actions()` lists its options (the sim bot answers through it).
2. **Guard tables** (`tests/test_blocking.gd`, 171–172):
   - a scenario in `scenarios()` that owes it, with the actions it lets go on;
   - a row in `actions()` for its action (the AC4 table test fails until there is one);
   - a row and a column in `test_each_decision_action_names_game_over_then_the_owed_decision_then_nothing_owed`;
   - its message in `test_hand_input_error_names_what_blocks_picking_up_a_hand_card`.
3. **UI tests** in the real `main.tscn` (`with_main`): the overlay shows the options, a click resolves it, a stale pick
   is refused with the error's reason.

## Green

4. `engine/game_engine.gd`: a `PENDING_<KIND>` constant, documented in `pending()`'s comment. If the options can
   change while it is owed, `pending()` computes them (as for discard, renewal and government); otherwise store them.
5. Set `state.pending = {"kind": PENDING_<KIND>, …}` where it becomes owed and `state.pending = {}` when it is paid.
   Only one decision is owed at a time: never set it over another kind. Store uids, never `CardInstance`s, so
   `GameState.copy()` needs no change (171's guard checks it).
6. `_blocked_error`: a `match` branch with the message every other action gives ("Choose a … first."). If some
   actions go on meanwhile (as a discard lets you learn techs), say which, like `_DISCARD_ALLOWS`.
7. The action and its `<action>_error` query, side by side under `# --- Actions ---`. The query starts with
   `_owed_error(PENDING_<KIND>, "<nothing owed message>")`, then checks the argument.
8. `engine/legal_actions.gd` (312): the decision's options as entries (`LegalActions.DECISIONS`, or `_decision` when
   the options aren't one-per-call), and a row in `tests/test_legal_actions.gd`'s coverage table: bots see the choice
   through `legal_actions()`.`GenericBot` answers it by value
   with no change (a choice that pays off over many turns may want a rollout, as the government choice has, 314).

## UI

9. `ui/choice_overlays.gd`: an overlay (heading and a card row) shown while `pending().kind` is the new kind.
10. `ui/main.gd`: in the refresh, the zone whose cards the row shows (`rows[...]`); in `on_picked`, a branch for picks
    in that row that calls the error query, refuses with its reason, or calls the action.
11. `ui/card_focus.gd`: the keys that move through and pick the row's cards while it is owed.

## Afterwards

- PLAN.md: the decision under its feature, and the list of kinds under "Pending decisions".
- A new test file: a `##` header saying what it covers and a one-line row in `docs/testing.md` (331).
