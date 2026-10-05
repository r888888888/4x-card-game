---
id: 297
title: Build and recruit from a territory's view
type: feature
status: ready
branch: feat/297-build-on-territory-view
---

## Goal
After 295 and 296 the engine can build buildings and recruit units from the build menu, but nothing on screen does it.
After this, a territory's view (101) has a **Build…** key beside Grow and Rename…: it opens a modal listing every
unlocked build-menu entry for that territory, with what each costs and, for the ones that can't go there now, why.
Picking one builds it on the spot. Building happens where you look at slots and workers, not on the Buy screen, which
goes back to selling action cards only. Follows 296.

## Acceptance criteria
- [ ] AC1: Given a territory view open on Homeland and a game whose `build_menu()` is Farm then Granary then Warriors,
  when Build… is pressed (or B while the view is open), then a modal titled "Build on Homeland" opens over the view
  and lists three entries in that order, each as its compact card face with its cost after discounts (as on a hand
  card). An entry that `build_error(id, Homeland)` allows is enabled; the others are disabled and show that reason
  under the face.
- [ ] AC2: Given the AC1 modal with Farm enabled, when Farm is clicked (or focused and Enter pressed), then
  `build("farm", Homeland)` happens: the modal closes, the territory view stays open and shows the new Farm among its
  buildings, and the top bar's food and actions update. A unit entry's key reads "Recruit" instead of "Build".
- [ ] AC3: Given the AC1 modal, when Esc, Cancel or a click outside its panel is used, then it closes and nothing is
  built (the standard `Modal` behaviour).
- [ ] AC4: Given a game over or a decision owed, then Build… is disabled and its tooltip is the engine's reason
  (`build_error`'s blocked message); given an empty `build_menu()`, Build… is hidden.
- [ ] AC5: The Buy screen (Buy Cards, S) lists the supply's open piles only; with the real data that is action cards,
  and its intro and tooltip no longer say buildings are bought. A build-menu unit's details offer Disband with the text
  "Dismiss it; its worker is freed." instead of "Send it to your discard; …".

## Out of scope
- Building from the Buy screen, or dragging an entry onto a territory on the Realm (possible later).
- A build-menu overview across all territories; the Knowledge screen shows what each tech unlocks (289).

## Design notes
- New modal in `ui/` extending `Modal`, opened from `TerritoryView`'s actions row; like `MoveModal` (163) it lists
  choices, but as card faces. Entries come from `build_menu()`; the enabled state and reason come from
  `build_error(id, t)`, never re-derived in the UI.
- B is unused anywhere in `ui/` today; name it in Build…'s tooltip as the other keys are (120).
- Item 290 (ending the turn returns to the Realm) and this both touch the territory view; whichever lands second
  rebases.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_territory_view::test_…` |

## Manual check
- [ ] Open a territory, press Build…: the modal reads well at 1280×720 and 1920×1080 with the full era-1 build menu
  (5 buildings and Warriors); disabled entries' reasons wrap without overlapping.
- [ ] Build a Farm, then recruit Warriors: each appears in the territory view at once; the Buy screen shows only action
  cards.

## Log
