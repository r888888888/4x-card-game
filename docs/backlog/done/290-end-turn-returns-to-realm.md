---
id: 290
title: Ending the turn returns to the Realm
type: feature
status: done
branch: feat/290-end-turn-returns-to-realm
---

## Goal
When the player ends their turn from the Knowledge screen (the tech tree) or a territory view, the board goes back to
the Realm, so the new turn starts on the view that shows the whole realm and the freshly drawn hand in context,
instead of leaving the player inside a detail screen from the last turn.

## Acceptance criteria
- [x] AC1: Given a game on the board with the Knowledge screen open over the Realm, when the turn ends (the End turn
  key is pressed, or E), then the Knowledge screen is no longer shown and the Realm is the navigator's only screen
  (`territory_view.nav.depth() == 1`, its top is the Realm).
- [x] AC2: Given a territory view open, when the turn ends, then the territory view is closed (`is_open()` false,
  `uid == -1`) and the Realm is shown.
- [x] AC3: Given the Knowledge screen open over a territory view (navigator depth 3), when the turn ends, then both
  close and the Realm is the only screen (depth 1).
- [x] AC4: Given the Knowledge screen or a territory view open and `end_turn_error()` non-empty (a decision is owed),
  when End turn is pressed, then the turn doesn't end and the open screen stays open (depth unchanged).
- [x] AC5: Given the Realm already shown (no screen over it), when the turn ends, then the Realm is still the only
  screen and nothing else changes (no error, depth 1).
- [x] AC6: Given a territory view open while the player still has the turn (no turn ended: a card played, a card
  bought), when the board refreshes, then the territory view stays open (only a turn change returns to the Realm).

## Out of scope
- The Buy Cards (supply) screen and modals: the turn can't be ended while they are open.
- Returning to the Realm on other events (a new era, an event drawn) beyond what already happens.

## Design notes
- UI only; no engine change. Ending the turn has two paths (`EndTurnKey._end_turn` and `CardFocus`'s E key), so
  main notices the turn change itself: `_refresh` compares `Game.engine.turn` with the turn it last saw and, when it
  moved on, takes the shared navigator (`territory_view.nav`) back to the Realm, closing the territory view and the
  Knowledge screen through their normal close paths (so `uid` resets and `navigated` fires). A new game resets the
  remembered turn.
- The screens leave with their usual transitions (the territory shrinks back into its card, Knowledge slides out;
  fades with Reduce motion).

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_end_turn_returns::test_ending_the_turn_from_knowledge_returns_to_the_realm` (End turn key and E) |
| AC2 | `test_end_turn_returns::test_ending_the_turn_from_a_territory_view_returns_to_the_realm` (End turn key and E) |
| AC3 | `test_end_turn_returns::test_ending_the_turn_from_knowledge_over_a_territory_view_closes_both` |
| AC4 | `test_end_turn_returns::test_a_refused_end_turn_leaves_the_open_screen` (guard: passes before the change) |
| AC5 | `test_end_turn_returns::test_ending_the_turn_on_the_realm_stays_on_the_realm` (guard) |
| AC6 | `test_end_turn_returns::test_a_refresh_within_the_turn_leaves_the_territory_view_open` (guard) |

## Manual check
- [ ] Open the tech tree (T), press E: the tree slides away and the Realm shows the new hand.
- [ ] Open a territory, press End turn: the view shrinks back into its card on the Realm.
- [ ] Open a territory, then the tech tree over it, end the turn: both go, the Realm shows, nothing flickers.

## Log
- 2026-10-05: Built in `TerritoryView.close_if_stale` rather than `main._refresh`, which calls it: `main.gd` sits at its
  500-line soft limit, and the view owns the play area's navigator. It remembers the turn it last saw (`reset()`,
  run by a new game, forgets it) and, once the turn moves on, pops the navigator back to the Realm, closing the view
  through `close()` and Knowledge through `nav.back()`, so both leave with their transitions and Knowledge's lamp sees
  the techs (288). AC4–AC6 passed before the change: they guard what must stay.
