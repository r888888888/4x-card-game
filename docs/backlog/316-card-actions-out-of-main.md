---
id: 316
title: Move the card handlers out of main.gd into CardActions
type: feature
status: review
branch: feat/316-card-actions-out-of-main
---

## Goal
`ui/main.gd` sits at exactly its 500-line soft limit (176's `test_main_is_under_the_soft_limit`), and every function
in it is used, so 297 (Build from a territory's view) can't add its `build_modal` field. Its card handlers are a real
boundary: what the player does with a card view (play it, click it, double-click it, discard it, pick it as a target
or choice, start dragging it), which main only wires up. They move to their own component, `CardActions`, and main
gets room to grow. No behaviour changes.

## Acceptance criteria
- [x] AC1: `ui/card_actions.gd` declares `class_name CardActions` and holds `try_play(view, target_uid := -1)`,
  `on_clicked(view)`, `on_double_clicked(view)`, `discard(view)`, `on_picked(view)` and
  `on_drag_requested(view, grab_offset)`; `ui/main.gd` declares none of them (nor `_refuse`) and holds the component as
  `main.card_actions`. `test_ui_structure`'s component table lists it, so main is checked to use it.
- [x] AC2: `ui/main.gd` is at most 450 lines.
- [x] AC3: The engine questions 094 and 175 check main for now live in `card_actions.gd`: it asks
  `needs_target_choice(` and `hand_input_error()`; `test_ui_structure`'s two checks read `card_actions.gd` instead of
  `main.gd`.
- [x] AC4: Behaviour is unchanged: every existing test passes with its calls moved from `main.try_play`,
  `main.on_double_clicked`, `main.on_picked` and `main.discard` to `main.card_actions.…` (the drag controller, card
  focus and card views' signals call the component too), and with no other change to any test.

## Out of scope
- Moving main's test hooks (event_modal(), menu_buttons(), …): many test files call them; a later split if main fills
  up again.
- Any change to what a click, double-click, drag or discard does.

## Design notes
- `CardActions` is a `RefCounted` holding main (`MainScreen`), like `CardFocus` and `DragController`: it reads
  `main.drag`, `main.territory_view`, `main.details`, `main.fx` and calls `main.log_note`; `BoardLayout` builds it next
  to them. `_refuse` (log the refusal, show it over the card) moves with it.
- Changed tests (call sites only): `test_counter_and_card_sounds`, `test_resource_tokens`, `test_grow_meter`,
  `test_toasts`, `test_territory_cards`, `test_trash_targeting`, `test_vellum`, `test_territory_view`,
  `test_action_errors`, `test_cabinet_doors`, `test_government_deck`; and `test_ui_structure`'s two source checks
  (AC3).

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_ui_structure::test_the_card_handlers_live_in_card_actions_not_main`; `CardActions` in `COMPONENTS` (`test_each_ui_component_has_its_own_script`, `test_main_uses_each_component`) |
| AC2 | `test_ui_structure::test_main_has_room_under_its_limit` |
| AC3 | `test_ui_structure::test_ui_asks_the_engine_for_targeting_tech_eras_and_open_piles`, `test_main_asks_the_engine_whether_a_hand_card_can_be_picked_up` (now read `card_actions.gd`) |
| AC4 | the whole suite, call sites moved to `main.card_actions` (green phase) |

## Log
- 2026-10-05: Specced while building 297, which needs a `build_modal` field on main; the user chose a split over a
  raised limit or moving the hook to the territory view.
- 2026-10-05: Built. `ui/card_actions.gd` (95 lines) holds the seven handlers word for word, reaching main's parts as
  `_board.…`; `BoardLayout` builds it after `CardFocus`. `main.gd` is 418 lines. Callers moved: `BoardViews` (the card
  views' signals, the right-click discard included), `DragController`, `CardFocus`, the details' Play; eleven test
  files' `main.<handler>(` calls became `main.card_actions.<handler>(`.
