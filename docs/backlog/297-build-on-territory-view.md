---
id: 297
title: Build and recruit from a territory's view
type: feature
status: in-progress
branch: feat/297-build-on-territory-view
---

## Goal
After 295, 296 and 299 the engine can build buildings, recruit units and preview either, but nothing on screen does
it. After this, a territory's view (101) builds: a **Build…** key beside Rename… (B), or a click on one of its empty
slots, opens a modal laid out like the style guide's selectable list beside a detail sheet ("Ledger", design 1 of the
build-menu canvas). The list holds every unlocked build-menu entry; the sheet shows the selected one's card and what
building it here would change, and one key builds it. Building happens where you look at slots and workers, not on the
Buy screen, which goes back to selling action cards only. Follows 299.

## Acceptance criteria
- [ ] AC1: Given a territory view open on Homeland and a game whose `build_menu()` is Farm, Well, Granary (buildings)
  then Warriors (a unit), when Build… is pressed (or B while the view is open), then a modal titled "Build on Homeland"
  opens over the view. Its list, in a well, has a "Buildings" heading over Farm, Well, Granary and a "Units" heading
  over Warriors, in `build_menu()` order; each row shows the entry's name and its cost after discounts. A row that
  `build_error(id, Homeland)` refuses is dimmed with that reason under its name; the others are not. No row has a lamp
  or other state light.
- [ ] AC2: When the modal opens, the first row `build_error` allows is selected (the first row when none is): it is
  drawn as the selectable list's selected row (an index card pulled out, with the orange index tab). ↑/↓ or a click
  selects another row. The sheet beside the list shows the selected entry's card face and, under "If built on
  Homeland", one line per `build_preview(id, Homeland)` line ("Food at next upkeep +1 → +3", "Free slots 2 → 1", …)
  and the cost it pays.
- [ ] AC3: With a row selected that `build_error` allows, the sheet's key reads "Build Farm" ("Recruit Warriors" for a
  unit); pressing it, or Enter, calls `build(id, Homeland)`: the modal closes, the territory view stays open and shows
  the new card, and the top bar's figures and actions update. With a refused row selected, the sheet shows its card
  and the refusal in place of the preview, and the key is disabled.
- [ ] AC4: Each free slot outline in the territory view reads "+ Build" and is a button: clicking it opens the same
  modal on that territory, as Build… does. A territory with no free slot shows no outlines (as today).
- [ ] AC5: Esc, Cancel or a click outside the panel closes the modal and builds nothing. Given a game over or a
  decision owed, Build… and the "+ Build" outlines are disabled with the engine's reason (`build_error`'s blocked
  message) as their tooltip; given an empty `build_menu()`, Build… is hidden and outlines don't read "+ Build".
- [ ] AC6: The Buy screen (Buy Cards, S) lists the supply's open piles only; with the real data that is action cards,
  and its intro and tooltip no longer say buildings are bought. A build-menu unit's details offer Disband with the text
  "Dismiss it; its worker is freed." instead of "Send it to your discard; …".

## Out of scope
- Showing locked entries or what unlocks them (the Knowledge screen and 289 do that).
- Choosing which slot a building takes: the engine has no slot positions; a "+ Build" outline only opens the modal.
- Dragging an entry onto a territory on the Realm, building from the Buy screen.

## Design notes
- Design: the build-menu canvas (Claude artifact "Build Menu Design", row 3, "1 · Ledger: list and forecast"), minus its
  lamps, plus "2 · Plots" for the "+ Build" outlines without its hatching or its anchored popover.
- New modal in `ui/` extending `Modal`, opened from `TerritoryView`. The list reuses the selectable list (`SelectList`,
  217; the guide's §7.16) inside the modal; the detail sheet holds a compact card face and the preview lines. One orange
  key per view: the sheet's Build key is the modal's primary (`AccentButton`).
- Everything shown comes from the engine: `build_menu()`, `build_error(id, t)` (dimming, reasons, the key's state),
  `build_preview(id, t)` (the lines; their keys map to labels in the UI) and the costs. Nothing is re-derived in `ui/`.
- B is unused anywhere in `ui/` today; name it in Build…'s tooltip as the other keys are (120).
- Item 290 (ending the turn returns to the Realm) and this both touch the territory view; whichever lands second
  rebases.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_build_modal::test_build_opens_a_modal_listing_the_build_menu_by_kind`, `test_b_opens_the_build_modal_from_the_territory_view`; engine: `test_build_menu::test_build_cost_is_an_entrys_cost_after_discounts` |
| AC2 | `test_build_modal::test_the_first_buildable_row_is_selected_and_the_sheet_previews_it`, `test_a_refused_first_row_is_skipped_and_none_buildable_selects_the_first`, `test_arrows_and_clicks_select_another_row` |
| AC3 | `test_build_modal::test_build_builds_the_selected_entry_and_closes`, `test_enter_builds_and_a_unit_reads_recruit`, `test_a_refused_row_shows_its_reason_and_disables_the_key` |
| AC4 | `test_build_modal::test_a_free_slot_reads_build_and_opens_the_modal`; existing `test_territory_view` outline tests |
| AC5 | `test_build_modal::test_esc_and_cancel_close_without_building`, `test_build_is_disabled_with_the_reason_while_a_decision_is_owed`, `test_an_empty_build_menu_hides_build_and_leaves_plain_outlines`; engine: `test_build_menu::test_build_menu_error_says_why_nothing_can_be_built` |
| AC6 | `test_build_modal::test_the_buy_screen_sells_no_buildings_or_units_on_the_real_data` (passes already: 295, 296), `test_a_recruited_units_disband_says_dismiss`; engine: `test_recruit::test_disbands_to_discard_tells_a_dealt_unit_from_a_recruited_one` |

## Manual check
- [ ] Open a territory, press Build…: the modal reads well at 1280×720 and 1920×1080 with the full era-1 build menu
  (5 buildings and Warriors) and with a long era-3 list (it scrolls inside the well); refusal reasons wrap without
  overlapping; the selected row's tab and pull-out match the selectable list elsewhere.
- [ ] Click an empty slot's "+ Build", build a Farm, then recruit Warriors: each appears in the territory view at once;
  the Buy screen shows only action cards.

## Log
- Redesigned before work started: from a grid of card tiles to the list-and-forecast modal ("Ledger"), with empty
  slots as a second way in; state lamps dropped at the user's request.
