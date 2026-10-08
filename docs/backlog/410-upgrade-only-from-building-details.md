---
id: 410
title: Upgrade a building from its details, not a chip on its card
type: feature
status: red-review
branch: feat/410-upgrade-only-from-building-details
---

## Goal
In the territory view, a building that could take an upgrade carries a "+ Upgrade" chip at the foot of its card (302),
which opens the Build modal on that upgrade. Since 387 the building's details have an Upgrades section that lists and
builds its upgrades. After this the chip is gone: a building's upgrades are built from its details (a click on its card),
so the territory view's cards show only the card and its ribbons, and everything about one building is in one place.

## Acceptance criteria
Fixture: `test_upgrade_ribbons`' engine (Farm ← Plough, Ditch; Chapel ← Sanctum ← Cathedral), Homeland's view open.

- [ ] AC1 (no chip): Given a Farm on Homeland at pop 3 that could take a Plough or a Ditch, and a Chapel carrying a
  Sanctum at pop 8 that could take a Cathedral, when the territory view shows them, then neither card shows a
  "+ Upgrade" chip (no button among the card's controls reads "+ Upgrade"), and the Chapel still shows the Sanctum's
  ribbon.
- [ ] AC2 (no chip while blocked): Given the same Farm, when a territory choice is owed (Explorer played), then the
  Farm's card still shows no chip.
- [ ] AC3 (the way to upgrade): Given the Farm carrying a Plough, when its card in the territory view is clicked, then
  its details open with the Upgrades section, whose Ditch row has an enabled Upgrade button; pressing it builds the
  Ditch on the Farm, and the Farm's card then shows the Ditch's ribbon.

## Out of scope
- The Build modal: Build… and "+ Build" still open it, and it still lists upgrades under their own heading (302).
- A mark on a building's card saying it could take an upgrade.
- The Upgrades section itself (387).

## Design notes
- UI only, no engine change. Remove the chip: `TerritoryView.upgrade_requested` and its connection in
  `board_layout.gd`, the chip half of `CardView.set_upgrades` (`on_chip`, `chip_reason`, `upgrade_chip`) and of
  `CardFace.set_ribbons`, and the `UpgradeChip` look in `ui/theme/upgrades.gd`. The chip's tests in
  `test_upgrade_ribbons.gd` (302's AC3) go with it, and that file's header comment loses the chip.
- `BuildModal.open(t, select)`: with the chip gone, nothing in the game passes `select`, but tests do (the Build modal
  and ceremony tests select a row through it), so it stays as a test hook; say so in its doc comment.
- AC3 may pass before any change (387 built the section); it pins the path that replaces the chip.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_upgrade_ribbons::test_a_building_that_could_take_an_upgrade_shows_no_chip` |
| AC2 | `test_upgrade_ribbons::test_no_chip_while_a_decision_is_owed` |
| AC3 | `test_upgrade_ribbons::test_a_click_on_a_building_opens_its_details_which_build_its_upgrade` (passes already: 387) |

## Manual check
- [ ] Open a territory with a Farm (or any building with an upgrade): its card has ribbons but no "+ Upgrade"; click it,
  and the details' Upgrades section builds the next upgrade, with the ceremony on the territory view.

## Log
- 2026-10-08: specced. Assumption (not asked): the Build modal keeps its Upgrades heading; only the chip goes.
- 2026-10-08: red. AC1 puts the Farm at pop 8 beside the Chapel (one home for both), not pop 3; the Farm takes a Plough
  or a Ditch at either. A chip is any button on the card reading "+ Upgrade", so the tests don't lean on
  `CardView.upgrade_chip`, which goes. Removed 302's four chip tests (shows the chip, opens the Build modal on the first
  upgrade, selects a chain's next link, disabled while a decision is owed).
