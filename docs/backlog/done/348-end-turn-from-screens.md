---
id: 348
title: End Turn from the territory view or the Knowledge screen ends the turn
type: feature
status: done
branch: feat/348-end-turn-from-screens
---

## Goal
A left click outside the territory view (327) or the Knowledge screen (326) only closes it, End Turn included, so
the player has to click End Turn twice. After this a click on End Turn closes the screen and ends the turn in one go;
every other outside click still only closes it.

## Acceptance criteria
- [x] AC1: Given a settled territory's view open, when the player left-clicks End Turn, then the view closes (back to
  the Realm, one `Sfx.NAV_BACK`) and the turn ends (`turn` goes up by 1). This replaces 327's AC2 for End Turn.
- [x] AC2: Given the Knowledge screen open, when the player left-clicks End Turn, then the screen closes and the turn
  ends. This replaces 326's "does nothing else" for End Turn.
- [x] AC3: Given either screen open, a left click on any other control outside it (a hand card, a top-bar counter, the
  civilization's name) still only closes it (unchanged from 326, 327).
- [x] AC4: Given either screen open, when the player presses E (end turn), then the turn ends and the screen closes
  (290).

## Out of scope
- Other overlays (the supply screen, modals: a modal still takes the click first).
- A turn that can't end (a decision owed): the click closes the screen and the key refuses as it does today; no test
  of its own.

## Design notes
- UI only. The territory view's `handle_click` and the Knowledge screen's `_input` let a click on the End Turn key
  through after closing.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_territory_view::test_a_click_on_end_turn_closes_the_view_and_ends_the_turn` |
| AC2 | `test_knowledge_screen::test_a_click_on_end_turn_closes_the_screen_and_ends_the_turn` |
| AC3 | `test_territory_view::test_a_click_on_a_control_outside_the_box_only_closes_the_view` (End turn dropped from its list); `test_knowledge_screen::test_a_left_click_outside_the_screen_closes_it_and_does_nothing_else` |
| AC4 | `test_territory_view::test_e_in_the_view_ends_the_turn_and_closes_it`; `test_knowledge_screen::test_e_on_the_screen_ends_the_turn_and_closes_it` (pass already: guards) |

## Manual check
- [ ] Open a territory's view, click End Turn: the view slides away and the turn plate flips to the next turn.
- [ ] The same from the Knowledge screen (T).

## Log
- The territory view closes a beat later (deferred) on an End turn click: closing during the release starts the
  transition before the key sees it, so the key got button_up without pressed.
