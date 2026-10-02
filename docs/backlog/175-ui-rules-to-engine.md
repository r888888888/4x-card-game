---
id: 175
title: The last small rules leave the UI; one action-button class
type: feature
status: ready
branch: feat/175-ui-rules-to-engine
---

## Goal
The UI asks the engine whether hand cards can be picked up and what the hand limit is, instead of deciding from
`pending()` kinds and the config, and the board's action buttons share one class. Before 176 splits `main.gd`. From
the 2026-10-01 project review.

## Acceptance criteria
- [ ] AC1: `hand_input_error()` is "" when nothing is owed or a hand-limit discard is owed, and otherwise the blocking
  reason: "The game is over.", "Choose a territory first.", the renewal message, "Choose a government first.". `main.gd`'s
  drag and double-click call it instead of checking `is_over` and `PENDING_EXPLORE`. Given renewal is owed, dragging a
  hand card in the real `main.tscn` starts no drag (today it does, and the drop is refused).
- [ ] AC2: `hand_limit()` and `research_on()` (the config has a research deck) are engine queries; the top bar uses
  them, and `test_ui_structure` forbids `.config.` in `ui/`.
- [ ] AC3: A pick in the government overlay goes through `choose_government_error` and is refused with its reason like
  a renewal or explore pick: given the government was just chosen, a second pick on a stale view logs "No government to
  choose." and changes nothing.
- [ ] AC4: One class (e.g. `ActionButton`: text, when to show, error query, action, tooltip) replaces
  `relieve_button.gd`, `restore_order_button.gd` and `revolt_button.gd`; the buttons look and behave as today, and the
  tests using `relieve_button()`, `restore_order_button()` and `revolt_button()` pass unedited.
- [ ] AC5: Every other existing test passes unedited.

## Out of scope
- `_leave_point`'s zone lookups (176 gives them `zone_of`).

## Design notes
- `hand_input_error()` is `_blocked_error("discard")` with game over first; after 172 it reads `state.pending`.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|

## Manual check
- [ ] Famine relief, Restore order and Revolt buttons: same place, text, tooltips and disabled states as before.
- [ ] During renewal and the government choice, hand cards can't be picked up.

## Log
- 2026-10-01: Specced from the project review.
