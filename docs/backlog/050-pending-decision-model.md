---
id: 050
title: One model for decisions the player owes
type: feature
status: review
branch: feat/050-pending-decision-model
---

## Goal
"Waiting for the player" is tracked three ways: `pending_choice` (explore), a non-empty `research_reveal` zone
(research) and `_discard_left` (hand limit), and each action checks them its own way. One model with one
blocking rule makes the next kind (the event deck) a single addition.

## Acceptance criteria
- [x] AC1: `pending()` is `{}` when nothing is owed.
- [x] AC2: After a Scout-style explore reveals 2 territories, `pending()` is
  `{kind: "explore", options: [uids, top of the reveal zone first, as in pending_choice], source: <card uid>}`.
- [x] AC3: After a Research card reveals 2 techs, `pending()` is `{kind: "research", options: [the 2 tech uids]}`.
- [x] AC4: With hand limit 5 and 7 cards in hand at `end_turn()`, `pending()` is
  `{kind: "discard", count: 2, options: [the 7 hand uids]}`; after one discard, `count` is 1.
- [x] AC5: A table test over each kind checks `play_error`, `grow_error`, `buy_error`, `end_turn_error`,
  `supply_error` and `discard_card`: each returns the same message or result as today (explore: "Choose a
  territory first."; research: "Buy a tech or decline first."; discard: "Discard down to N cards first.", except
  `discard_card` and `supply_error` are allowed).
- [x] AC6: `pending_choice`, `research_options()` and `discard_needed()` keep working (derived from `pending()`),
  and every existing test passes unchanged. The UI reads `pending()`.

## Out of scope
- New decision kinds (events).
- Removing the old queries (a later cleanup, once nothing uses them).

## Design notes
- One `_blocked_error(action)` replaces `_busy_error`, the copy inside `grow_error`, and the inline checks in
  `discard_card` and `end_turn`.

## Test plan
| AC | Test (`tests/test_pending.gd`) |
|---|---|
| AC1 | `test_pending_is_empty_when_nothing_is_owed` |
| AC2 | `test_pending_explore_lists_the_revealed_territories_top_first` |
| AC3 | `test_pending_research_lists_the_revealed_techs` |
| AC4 | `test_pending_discard_counts_down_and_offers_the_hand` |
| AC5 | `test_each_pending_kind_blocks_actions_as_before` |
| AC6 | the existing suite, unchanged; UI checked by `test_ui_smoke` and the Manual check |

## Manual check
- [ ] Explore, research and hand-limit discard play exactly as before (overlays, disabled buttons, messages).

## Log
- 2026-09-29: spec approved with these readings: `source` is a uid for explore only; game over isn't a pending
  kind; `sim/bot.gd` keeps the old queries. `pending_choice` stays the stored state (a test assigns it), and
  `pending()` is derived from it, `research_reveal` and `_discard_left`.
- Green phase: AC2's test expected deck order [Hills, Grassland]; the engine and UI have always listed the reveal
  zone's top first [Grassland, Hills]. With approval, the test's expected order was fixed (no engine change).
- `_blocked_error(action)` replaced `_busy_error`, `_choice_error`, the copy in `grow_error` and the inline checks in
  `discard_card` and `end_turn`. Kinds are constants `GameEngine.PENDING_EXPLORE/RESEARCH/DISCARD`. `main.gd` reads
  `pending()` through `_pending_kind()`. 341 → 346 tests.
- Follow-up (out of scope here): remove `research_options()` / `discard_needed()` once `sim/bot.gd` and the
  tests stop using them.
