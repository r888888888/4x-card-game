---
id: 354
title: Show the selected entry's flavor in the Build modal
type: feature
status: done
branch: feat/354-flavor-in-build-modal
---

## Goal
Choosing what to build is the moment a player looks hardest at a building, but its flavor (352, voiced in 353) shows
only in the details window, which the Build modal's display-only card can't open. Put the selected entry's flavor line
on the modal's sheet, under its card, so every building reads like history where it is chosen.

## Acceptance criteria
- [x] AC1: Given a territory whose build menu offers a building with `"flavor": "Mud brick, baked hard."`, when the
  Build modal opens with that row selected, then the sheet shows that flavor between the card and the
  "If built on <territory>" heading, in the `Flavor` look (italic, dim), wrapping at the card's width
  (`Modal.LEDGER_DETAIL_WIDTH`, 264).
- [x] AC2: Given the modal open, when another row is selected (by click or Up/Down), then the sheet's flavor is the
  newly selected entry's: never the previous one's, and never two.
- [x] AC3: Given a row the engine refuses (`build_error` non-empty), when it is selected, then its flavor still shows,
  above the refusal.
- [x] AC4: Given an upgrade row (302), when it is selected, then the flavor is the upgrade's own, not its base
  building's.
- [x] AC5: Given a row whose card has no flavor (a unit), when it is selected, then the sheet shows no flavor line and
  no gap for one: the "If built on" heading follows the card directly, as today.
- [x] AC6: Given the 1920 × 1080 window and the entry with the longest flavor and the most preview lines in the
  fixture, then the open modal's panel still lies wholly inside the viewport (343's AC4 holds).

## Out of scope
- Quotes in the Build modal (buildings take none; 352).
- Flavor on card faces anywhere, or in the territory view's building rows.
- Flavor in other modals that show a card (Buy, Renewal, Move…): a later item if wanted.
- The text itself (353).

## Design notes
- UI only: the flavor comes from the engine (`GameEngine.def_details(id).flavor`, "" when none), never from
  `CardDef` read in the UI. No engine change, no data change.
- `BuildModal._show_entry` adds a wrapped `Label` with `theme_type_variation = &"Flavor"` (the card face's italic foot
  look in `GameTheme`), `custom_minimum_size.x = LEDGER_DETAIL_WIDTH`, before the preview or the refusal, only when the
  flavor is non-empty. Test hook: `flavor_text()` returning the shown flavor ("" when none);
  `preview_lines()` stays the preview's heading, lines and cost (it does not include the flavor).
- Height: the card is 320 px; a ~120-character line wraps to three or four lines at 264 px in `TYPE_BODY_S`, about
  60–75 px. The sheet may grow taller than the 480 px list; AC6 guards the window. If it doesn't fit, report it at the
  red checkpoint rather than shrinking the card (343).
- Tests in `tests/test_build_modal.gd`; give a fixture building a flavor in `TEST_CARDS` (or the file's own fixture),
  and an upgrade fixture its own.
- Guide: §11.10's ledger sheet gains the flavor line under the card; the specimen (`mcm-specimen.html`) shows it if it
  draws the Build sheet.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_build_modal::test_the_selected_buildings_flavor_shows_under_its_card` |
| AC2 | `test_build_modal::test_the_flavor_follows_the_selection` |
| AC3 | `test_build_modal::test_a_refused_rows_flavor_shows_above_its_reason` |
| AC4 | `test_upgrade_ribbons::test_an_upgrade_rows_flavor_is_its_own_not_its_bases` |
| AC5 | `test_build_modal::test_a_card_without_flavor_shows_no_flavor_line` |
| AC6 | `test_build_modal::test_the_longest_flavor_keeps_the_modal_inside_the_window` |

## Manual check
- [ ] Open Build… on a territory (seed 5, Sumer): the Farm's flavor sits under its card in italics, then "If built
  on …". Arrow down through the list: the line follows the selection; a unit shows none.
- [ ] Select a refused row: its flavor, then the reason.
- [ ] At 1920 × 1080, select the longest-flavored building: nothing is clipped or pushed off screen.

## Log
- Green: `_show_entry` reads `def_details(id).flavor` and adds a `Flavor` label first in the sheet's lines, wrapping at
  `LEDGER_DETAIL_WIDTH` like the refusal; `preview_lines()` skips it. Hook `flavor_text()`. The fixture Chapel and
  Sanctum (`test_upgrade_ribbons.gd`) gained flavor for AC4; no existing expectation changed.
- Docs: guide §11.10 (the ledger sheet's detail column) and §18, the specimen's territory-view note, PLAN.md (the
  Build modal and the Flavor paragraph). `docs/testing.md` is at its 25 KB cap, so its row is unchanged; the test
  file's `##` header names 354.
