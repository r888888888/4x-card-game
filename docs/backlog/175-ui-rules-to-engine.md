---
id: 175
title: The last small rules leave the UI; one action-button class
type: feature
status: red-review
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
| AC1 | `test_blocking::test_hand_input_error_names_what_blocks_picking_up_a_hand_card`, `test_renewal::test_a_hand_card_cant_be_dragged_while_renewal_is_owed`, `test_ui_structure::test_main_asks_the_engine_whether_a_hand_card_can_be_picked_up` |
| AC2 | `test_ui_queries::test_hand_limit_and_research_on_are_engine_queries`, `test_ui_structure::test_ui_scripts_read_no_engine_internals` (`.config.` added to `INTERNALS`) |
| AC3 | `test_government_deck::test_a_stale_government_pick_is_refused_with_its_reason` |
| AC4 | `test_ui_structure::test_each_ui_component_has_its_own_script` / `test_main_uses_each_component` (`ActionButton` added to `COMPONENTS`), `test_ui_structure::test_the_board_action_buttons_share_one_class`; the `relieve_button()`, `restore_order_button()`, `revolt_button()` tests unedited |
| AC5 | Every other existing test unedited |

## Manual check
- [ ] Famine relief, Restore order and Revolt buttons: same place, text, tooltips and disabled states as before.
- [ ] During renewal and the government choice, hand cards can't be picked up.

## Log
- 2026-10-01: Specced from the project review.
- 2026-10-01: Red. API: `hand_input_error() -> String`, `hand_limit() -> int`, `research_on() -> bool`; `ui/action_button.gd`
  (`ActionButton`). The stale-pick test takes the Chiefs view while the choice is open, chooses Kings through the
  overlay, then picks the stale Chiefs view: today it logs "There is no territory to choose." (the pick falls through
  to explore once nothing is pending), so `on_picked` has to route by the row the view is in, not by `pending()`.
