---
id: 050
title: One model for decisions the player owes
type: feature
status: draft
branch: feat/050-pending-decision-model
---

## Goal
"Waiting for the player" is tracked three ways: `pending_choice` (explore), a non-empty `research_reveal` zone
(research) and `_discard_left` (hand limit), and each action checks them its own way. One model with one
blocking rule makes the next kind (the event deck) a single addition.

## Acceptance criteria
- [ ] AC1: `pending()` is `{}` when nothing is owed.
- [ ] AC2: After a Scout-style explore reveals 2 territories, `pending()` is
  `{kind: "explore", options: [top uid, second uid], source: <card uid>}`.
- [ ] AC3: After a Research card reveals 2 techs, `pending()` is `{kind: "research", options: [the 2 tech uids]}`.
- [ ] AC4: With hand limit 5 and 7 cards in hand at `end_turn()`, `pending()` is
  `{kind: "discard", count: 2, options: [the 7 hand uids]}`; after one discard, `count` is 1.
- [ ] AC5: A table test over each kind checks `play_error`, `grow_error`, `buy_error`, `end_turn_error`,
  `supply_error` and `discard_card`: each returns the same message or result as today (explore: "Choose a
  territory first."; research: "Buy a tech or decline first."; discard: "Discard down to N cards first.", except
  `discard_card` and `supply_error` are allowed).
- [ ] AC6: `pending_choice`, `research_options()` and `discard_needed()` keep working (derived from `pending()`),
  and every existing test passes unchanged. The UI reads `pending()`.

## Out of scope
- New decision kinds (events).
- Removing the old queries (a later cleanup, once nothing uses them).

## Design notes
- One `_blocked_error(action)` replaces `_busy_error`, the copy inside `grow_error`, and the inline checks in
  `discard_card` and `end_turn`.

## Test plan
| AC | Test |
|---|---|

## Manual check
- [ ] Explore, research and hand-limit discard play exactly as before (overlays, disabled buttons, messages).

## Log
