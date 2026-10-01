---
id: 086
title: Split ui/card_view.gd into content and motion
type: feature
status: done
branch: feat/086-split-card-view
---

## Goal
`ui/card_view.gd` has 674 lines, 26 under 085's hard limit. It does three jobs: building the card's content,
moving and animating the card, and handling input, hover and the border. Move content and motion into their own
components so a card change touches one small file and every script is under the 500-line soft limit. There's no
visible change.

## Acceptance criteria
- [x] AC1: The card's content lives in `CardFace` (`ui/card_face.gd`), and `CardView` uses it. That covers the title,
  the type line with its cost, the rules, the territory info line, VP, the info lines (`TechInfo`, `EventInfo`,
  `BuyInfo`), the reason strip and the label builders.
- [x] AC2: Movement and animation live in `CardMotion` (`ui/card_motion.gd`), and `CardView` uses it. That covers
  attach, pop in, squash, deal, fly to slot, return home, reject, begin drag, leave, the per-frame chase and fitting
  the slot.
- [x] AC3: `CardView`'s public API is unchanged: the signals, `setup`, the `set_*` methods, `event_info_text`, the
  movement methods, `slot_size`, `state`/`State`, `slot`, `uid`, `card_id`, `in_hand`, `pickable`, `lift_on_hover`,
  `fx_scale` and the constants other scripts read (`TYPE_COLORS`, `*_SIZE`, `WARN_COLOR`, `HIGHLIGHT_COLOR`,
  `FOCUS_COLOR`). Every existing test passes without edits.
- [x] AC4: `card_view.gd`, `card_face.gd` and `card_motion.gd` are each 500 lines or fewer, so `scripts/test.sh` prints
  no `WARN` line for any of them.
- [x] AC5: The new scripts read no engine internals (the existing `test_ui_structure` guard scans all of `ui/`).

## Out of scope
- Any visual, timing or input change.
- Splitting `game_engine.gd` or `data_loader.gd` (they still get warnings).

## Design notes
- `CardFace` is the content `VBoxContainer`. `CardView` keeps the panel style, the tooltip, the dimmed state and the
  border.
- `CardMotion` is a `RefCounted` helper that holds its `CardView` (a Node, so there's no reference cycle).
  `CardView._process` hands the frame to it. The movement methods stay on `CardView` as one-line delegators, so
  callers don't change (AC3).
- The input and hover code stays in `CardView`.

## Test plan
| AC | Test |
|---|---|
| AC1, AC2 | `test_ui_structure::test_card_view_content_and_motion_have_their_own_scripts`, `test_card_view_uses_its_content_and_motion` |
| AC3 | the existing suite, unedited (UI smoke, card slots, details modal, menu, event panel, board labels) |
| AC4 | `test_script_size` output: no `WARN` for the three files |
| AC5 | `test_ui_structure::test_ui_scripts_read_no_engine_internals` (a guard: passes already) |

## Manual check
- [ ] Deal, hover lift, drag with tilt, drop on a target, refused drop (shake and return), double-click play, discard
  (right-click), card leaving to the discard, pop in on the realm, supply cards lifting, focus ring, dimmed hand card
  with its reason strip, tech price and pass markers, event turns left, and reduce motion (fades, no lift): all as
  before.

## Log
- 2026-09-29: The content-only split would have left `card_view.gd` at about 550 lines, so the user picked content +
  motion. Built in worktree `../4x-card-game-086`. `card_view.gd` 674 → 342, `card_face.gd` 161, `card_motion.gd` 274,
  so none gets a size warning. `CardMotion` uses the view's `_hover`, `_focused`, `_target_size` and `_update_border`,
  the same way 051's engine modules use the engine's private members. `CardFace` has `replace_info` (tech and event
  lines are rebuilt at the bottom) and `update_info` (the buy line is updated in place, keeping its spot above the
  reason strip), matching the old behavior. `delay` (a dealt card waiting to fly) moved to `CardMotion`, and input
  reads `_motion.delay`. Tests 482 → 484, and no existing test was edited.
