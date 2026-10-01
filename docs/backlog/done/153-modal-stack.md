---
id: 153
title: Stack modals on one Modal base
type: feature
status: done
branch: feat/153-modal-stack
---

## Goal
Any modal can open another modal over itself, and the player can always close just the top one: with its Close
button, Esc (or its own close key), or a click anywhere outside its panel. Today the four modals (card details,
identity, event, tech tree) each copy the same scrim, key and click-outside code, and only tech tree → details stacks,
by an accident of tree order and z_index. This item gives them one `Modal` base and a `ModalStack` that owns the
order, so the linked-terms item (deferred, see Out of scope) can open term and card modals over any modal.

## Acceptance criteria
<!-- "tree + details": a game started, the tech tree open, then a tech's details opened over it (main.details.open_def). -->
- [x] AC1: Given tree + details, when Esc is pressed, then the details close and the tree stays open
  (`main.modals.depth()` 2 → 1); a second Esc closes the tree (depth 0).
- [x] AC2: Given tree + details, when the player clicks outside both panels, then only the details close and the tree
  stays open. When instead the click lands on the tree's panel where the details' panel doesn't cover it, then also
  only the details close: the tree stays open and nothing on it is pressed (no tech's details open, no tech learned).
- [x] AC3: Given tree + details, keys go to the top modal only: T (the tree's close key) leaves both open, E doesn't end
  the turn, and I (the details' close key) closes the details.
- [x] AC4: Given tree + details, when the tree is closed (`main.tech_tree.close()`), then the details close too and
  depth is 0. When instead the tree is opened again (`main.tech_tree.open()`), it comes back to the top: the details
  close and depth is 1.
- [x] AC5: Given a modal open alone, its panel is centred on the screen; given tree + details, the details' panel is
  centred 36 px right and 28 px down of centre (one cascade step per level below it), so the tree's panel shows
  beside it.
- [x] AC6: Every modal (card details, identity, event, tech tree) opens on `main.modals`: opening it from nothing makes
  depth 1 with it on top, its Close (or OK) button makes depth 0, and the toasts stay hidden while any modal is open.
- [x] AC7: Given tree + details open, when a new game starts or the player leaves the game for the title screen, then
  depth is 0.

## Out of scope
- **Linked terms (deferred):** clickable glossary terms, territory keywords, resources and card names in a modal's
  text, each opening a term or card modal over it. Spike `spike/modal-stack` found the engine should mark links while
  it generates card text, not match words in the finished text (tags like "city cards" collide with card names).
- Animating modals in and out; following links by keyboard.
- Changing any modal's content or layout beyond the cascade.

## Design notes
- From spike `spike/modal-stack` (worktree `../4x-spike-modals`), whose code passed the existing suite unchanged.
- `ui/modal.gd` (`Modal extends ColorRect`): the scrim (`Palette.SCRIM`, z_index 20), a centred `DarkPanel` (`panel`
  for subclasses to fill), `close_keys` (default Esc), `present()`, `close()`, `closed()` (subclasses forget what they
  showed), `cascade(level)`. Its `_input` acts only while it is the stack's top, and takes every key then.
- `ui/modal_stack.gd` (`ModalStack extends RefCounted`, like `Navigator`): `push`, `close` (closes the ones above too),
  `close_all`, `top`, `is_open`, `depth` (test hook). The modals stay children of the board (siblings of the log drawer,
  as `test_identity_lines` expects); push moves the top one last, since input goes by tree order.
- `main.modals` is created before the modals; `TechTreeModal.new(modals, details.open_def)` replaces its
  `get_parent().details` reach. The tech tree's z_index goes from 15 to 20 with the others; tree order decides among
  them. Toasts ask `modals.is_open()` instead of four `visible` checks.
- UI only: no change to `engine/`, `autoload/` or the loader.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_modal_stack::test_esc_closes_the_details_over_the_tree_then_the_tree` |
| AC2 | `test_modal_stack::test_a_click_outside_both_panels_closes_only_the_details`, `test_a_click_on_the_tree_beside_the_details_closes_only_the_details` |
| AC3 | `test_modal_stack::test_keys_go_to_the_top_modal_only` |
| AC4 | `test_modal_stack::test_closing_the_tree_closes_the_details_over_it`, `test_reopening_the_tree_brings_it_to_the_top` |
| AC5 | `test_modal_stack::test_a_modal_alone_is_centred`, `test_a_modal_over_another_is_one_cascade_step_from_centre` |
| AC6 | `test_modal_stack::test_details_open_on_the_stack_and_close_with_close`, `test_the_tree_opens_on_the_stack_and_close_closes_it`, `test_the_identity_modal_opens_on_the_stack_and_hides_the_toasts`, `test_the_event_modal_opens_on_the_stack_and_ok_closes_it` |
| AC7 | `test_modal_stack::test_a_new_game_closes_every_modal`, `test_leaving_for_the_title_screen_closes_every_modal` |

## Manual check
`godot --path . -- --seed 1`, start a game:
- [ ] Knowledge (or T), click Pottery's tile: its details open 36 px right and 28 px down of centre, over the tree,
  which shows dimmed behind.
- [ ] Click a visible part of the tree beside the details (its left column): only the details close; nothing on the
  tree is pressed. Click Pottery again, press Esc: only the details close. Esc again closes the tree.
- [ ] Click Pottery again, press T: nothing happens (the details are on top). Press I: the details close.
- [ ] Click a hand card: its details open centred, Close (Esc) closes them. The civilization button's modal and a drawn
  event's modal still open centred and close with Close / OK, Esc or a click outside.

## Log
- Ported from `spike/modal-stack` without its links and term modal (deferred). The four modals lost their copies of
  the scrim, `_input` and click-outside code; `main.modals.close_all()` replaces the separate closes on a new game and
  on leaving. Behaviour change beyond the criteria: the tech tree is now z_index 20 like the other modals (was 15).
- Suite 998 → 1012 tests.
