---
id: 410
title: Upgrade a building from its details, not a chip on its card
type: feature
status: done
branch: feat/410-upgrade-only-from-building-details
---

## Goal
In the territory view, a building that could take an upgrade carries a "+ Upgrade" chip at the foot of its card (302),
which opens the Build modal on that upgrade. Since 387 the building's details have an Upgrades section that lists and
builds its upgrades. After this the chip is gone: a building's upgrades are built from its details (a click on its card),
so the territory view's cards show only the card and its ribbons, and everything about one building is in one place.

## Acceptance criteria
Engine fixture: `test_upgrades`' cards and menu (Farm ← Plough, Ditch, Weir; Chapel ← Sanctum, Rampart; Sanctum ←
Cathedral). UI fixture: `test_upgrade_ribbons`' engine (Farm ← Plough, Ditch; Chapel ← Sanctum (Village) ← Cathedral
(Town)), Homeland's view open.

- [x] AC1 (engine): `has_unbuilt_upgrades(uid)` is true when some row of `upgrade_rows(uid)` is not built, whatever its
  `error`. Given a Farm on Homeland with 0 food and Plough locked, then it is true, and still true once the Ditch is
  built (Plough locked, the Weir short of fresh water) and while a decision is owed (Explorer played). Given a Chapel
  carrying a Sanctum and a Rampart, then it is true (the Cathedral, on the Sanctum), and false once the Cathedral
  stands. It is false for a territory, a city, a unit or an unknown uid.
- [x] AC2 (no chip): Given a Farm and a Chapel carrying a Sanctum on Homeland at pop 8, when the territory view shows
  them, then no button on either card reads "+ Upgrade", and the Chapel still shows the Sanctum's ribbon.
- [x] AC3 (the badge): Given that view at pop 3, then the Farm's card and a Chapel's each show the upgrade badge (a ▲ in
  the card's corner) with a tooltip saying the card's details list its upgrades, the Chapel's though its Sanctum needs a
  Village. Once the Farm carries a Plough and a Ditch its badge goes; at pop 8, once the Chapel carries a Sanctum and a
  Cathedral, its badge goes.
- [x] AC4 (whatever stops it now): Given the Farm with 0 food and a decision owed (Explorer played), then its badge
  still shows, and no chip.
- [x] AC5 (the way to upgrade): Given the Farm carrying a Plough, when its card in the territory view is clicked, then
  its details open with the Upgrades section, whose Ditch row has an enabled Upgrade button; pressing it builds the
  Ditch on the Farm, and the Farm's card then shows the Ditch's ribbon.

## Out of scope
- The Build modal: Build… and "+ Build" still open it, and it still lists upgrades under their own heading (302).
- The badge anywhere but a building's card in the territory view (the Realm row, the hand, details).
- The Upgrades section itself (387).

## Design notes
- New engine query `has_unbuilt_upgrades(uid) -> bool` beside `upgrade_rows` (`TerritoryQueries`, via `Upgrades`), so
  the UI decides nothing: the badge shows exactly when the details list an upgrade not yet built.
- UI: remove the chip: `TerritoryView.upgrade_requested` and its connection in `board_layout.gd`, the chip half of
  `CardView.set_upgrades` and `CardFace.set_ribbons`, and the `UpgradeChip` look in `ui/theme/upgrades.gd`, which
  gains the badge's look (`UpgradeBadge`). `CardView` gets the badge (test hook `upgrade_badge()`, null when none),
  set by `TerritoryView._show_upgrades` from `has_unbuilt_upgrades`. The chip's tests in `test_upgrade_ribbons.gd` (302's AC3)
  go.
- `BuildModal.open(t, select)`: with the chip gone, nothing in the game passes `select`, but tests do (the Build modal
  and ceremony tests select a row through it), so it stays as a test hook; say so in its doc comment.
- AC5 may pass before any change (387 built the section); it pins the path that replaces the chip.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_upgrades::test_a_farm_has_unbuilt_upgrades_whatever_stops_them_now`, `test_a_chain_has_unbuilt_upgrades_until_its_last_link_stands`, `test_no_unbuilt_upgrades_for_anything_but_a_building` |
| AC2 | `test_upgrade_ribbons::test_a_building_that_could_take_an_upgrade_shows_no_chip` |
| AC3 | `test_upgrade_ribbons::test_a_building_with_an_upgrade_not_yet_built_carries_the_badge` |
| AC4 | `test_upgrade_ribbons::test_the_badge_shows_whatever_stops_the_upgrade_now` |
| AC5 | `test_upgrade_ribbons::test_a_click_on_a_building_opens_its_details_which_build_its_upgrade` (passes already: 387) |

## Manual check
- [ ] Open a territory with a Farm (or any building with an upgrade): its card has ribbons and a ▲ badge in its corner
  (hover: its tooltip) but no "+ Upgrade"; click it,
  and the details' Upgrades section builds the next upgrade, with the ceremony on the territory view.

- [ ] A building with a long name: the ▲ sits over the end of its name line (the name is clipped there); check it reads.
- [ ] Paper and Night: the badge (Caption, territory colour) is legible on the card.

## Log
- 2026-10-08: specced. Assumption (not asked): the Build modal keeps its Upgrades heading; only the chip goes.
- 2026-10-08: at the red checkpoint the user asked for a mark that upgrades are available, and chose a corner badge with
  a tooltip, shown only when an upgrade can be built now; then changed it to whenever the building has an upgrade not yet built,
  whatever stops it now (locked, tier, cost, a decision owed).
- 2026-10-08: red. AC1 puts the Farm at pop 8 beside the Chapel (one home for both), not pop 3; the Farm takes a Plough
  or a Ditch at either. A chip is any button on the card reading "+ Upgrade", so the tests don't lean on
  `CardView.upgrade_chip`, which goes. Removed 302's four chip tests (shows the chip, opens the Build modal on the first
  upgrade, selects a chain's next link, disabled while a decision is owed).
- 2026-10-08: red again with the badge. The no-chip-while-blocked test folded into AC4's. The badge's mark is "▲"
  (the test checks it); its tooltip is only checked non-empty.
- 2026-10-08: green (2564 → 2566). `upgrades_for` and `Upgrades.for_base` fed only the chip, so they went with their test
  (`test_upgrades_for_lists_the_entries_a_base_could_take_now`); the approved no-chip test's setup check used
  `upgrades_for`, now `build_error("ditch", farm) == ""`, assertions unchanged. The badge is a `Label` child of the
  `CardView` panel, shrunk to its top right corner, `UpgradeBadge` (Caption, semibold, `Palette.TERRITORY`), with mouse
  filter Pass so it shows its tooltip and the click still opens the details. A render of the view showed it in the
  corner on the Farm and the Chapel and none on the Capital.
