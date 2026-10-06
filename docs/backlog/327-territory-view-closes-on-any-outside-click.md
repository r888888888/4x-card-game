---
id: 327
title: A click anywhere outside the territory box closes the territory view
type: feature
status: red-review
branch: feat/327-territory-view-closes-on-any-outside-click
---

## Goal
Today (200) only a click on the view's own area beside or below the territory box closes the territory view; a click
on the top bar, the sidebar or the hand leaves it open. The view should close like the log drawer and the Knowledge
screen (326): a left click anywhere outside the box takes you back to the Realm. That click only closes the view and
does nothing else.

## Acceptance criteria
- [ ] AC1: Given a settled territory's view is open, when the player left-clicks (press and release) on the hand
  section's empty space, the top bar's empty space or the sidebar's empty space, then the view goes back to the Realm,
  as the breadcrumb's Back does (one `Sfx.NAV_BACK`). This replaces 200's AC3.
- [ ] AC2: Given the same, when the player left-clicks a control outside the box (a hand card, a top-bar counter,
  End Turn, a sidebar button), then the view closes and the click does nothing else: no card is selected, played or
  opened in a details modal, no modal opens, the turn doesn't end and the engine state is unchanged.
- [ ] AC3: Given the same, when the player presses on a hand card, drags it and drops it on the view (inside or outside
  the box), then the drop still targets the territory (101) and the view stays open.
- [ ] AC4: Given the same with a modal open over it, when the player clicks outside the modal's panel, then only the
  modal closes and the view stays open (unchanged from 200).
- [ ] AC5: Given the same, a click inside the box still does what it does today and leaves the view open, and a
  right-click anywhere outside the box leaves it open (unchanged from 200).
- [ ] AC6: Given the view closed or already leaving, when the player left-clicks a hand card or End Turn, then the
  click works as before (the view takes nothing), and a second outside click while it leaves steps back only once.

## Out of scope
- Other screens on the play area's navigator (Knowledge is 326).
- Keyboard behaviour (Esc, B) is unchanged.

## Design notes
- UI only, no engine change. Like the log drawer (`ui/log_drawer.gd` `_input`) and 326, but the close has to wait for
  the release so a press that starts a drag from the hand still reaches the drag controller (AC3): a press and a release
  outside the box with no drag between them close the view, and the release (and whatever click it would make) is
  marked handled. Card clicks and double-clicks must not fire for that click (AC2); check where `CardView` acts on a
  press vs a release.
- Modals take their clicks first (`ModalStack`); the view closes only with no modal open (AC4).
- `TerritoryView._gui_input` (200) may become redundant once the view watches `_input`; remove what the new path covers.
- The 200 test `test_a_click_on_the_hand_or_top_bar_or_a_modal_leaves_the_view_open` encodes the old rule; rewrite it
  under this item (the rule change is the user's, 2026-10-05).
- 326 edits the same pattern in `ui/knowledge_screen.gd`; if both land, consider sharing the outside-click helper.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_territory_view::test_a_click_on_the_hand_or_sidebar_space_closes_the_view` (hand's empty corner, the rail's padding; one `NAV_BACK`) |
| AC2 | `test_territory_view::test_a_click_on_a_control_outside_the_box_only_closes_the_view` (a hand card, the food counter, End turn, the civ name: closes; no details or modal, same turn, hand and actions; no drag on a later move) |
| AC3 | `test_territory_view::test_a_drag_from_the_hand_onto_the_view_still_targets_the_territory` (a real press and move on a hand card starts a drag; the release on the view drops it there and the view stays open) |
| AC4 | `test_territory_view::test_a_click_outside_a_modal_over_the_view_closes_only_the_modal` |
| AC5 | `test_territory_view::test_a_click_inside_the_box_leaves_the_view_open` (200), `test_a_drop_or_right_click_outside_the_box_leaves_the_view_open` (200), `test_a_right_click_on_the_hand_leaves_the_view_open` |
| AC6 | `test_territory_view::test_with_the_view_closed_end_turn_still_works`, `test_a_second_outside_click_while_leaving_does_nothing` (200) |

Replaced: 200's `test_a_click_on_the_hand_or_top_bar_or_a_modal_leaves_the_view_open` (its hand and top-bar half is the
rule this item reverses; its modal half is AC4's test).

## Manual check
- [ ] Open a territory, click the hand's empty space, the top bar and the sidebar rail: each shrinks it back into its
  card.
- [ ] Open it again and click a hand card once: the view closes and the card isn't picked up or opened.
- [ ] Open it again and drag a hand card onto the view: it plays on the territory and the view stays open.

## Log
- Specced 2026-10-05 from the user's request ("clicking outside of the view should dismiss it"). Decided with the user:
  any outside click closes the view, and that click only closes it (same as 326).
