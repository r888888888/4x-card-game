---
id: 118
title: Click the parent title in the header to go back
type: feature
status: red-review
branch: feat/118-click-the-title-to-go-back
---

## Goal
Every navigated screen carries a "← Realm" back button next to a "Realm › River Meadow" breadcrumb. The button says the
same thing the breadcrumb does. Drop the button and make the breadcrumb's parent segment ("Realm") the way back.

## Acceptance criteria
<!-- UI tests in the real main.tscn on test_screen_header's fixtures. -->
- [ ] AC1: Given the territory view is open on River Meadow, then its header has no "←" back button, and the
  breadcrumb still reads "Realm › River Meadow" with "Realm" a clickable segment (hand cursor, tooltip "Back to
  Realm"). Clicking it closes the view like Esc does (the Realm is back at once, the view shrinks away).
- [ ] AC2: The same for the New game screen ("Main menu › New game") and the Settings screen ("Main menu › Settings"):
  no back button, and clicking "Main menu" returns to the title screen.
- [ ] AC3: The last segment ("River Meadow", "New game") is plain text: clicking it does nothing. At the root of a
  stack the header shows just its title, with nothing clickable.
- [ ] AC4: Esc and the menu's New game still go back / close as before (guard); keyboard focus after going back is
  where it was after the button (guard: the same tests, driven by the segment).

## Out of scope
- Breadcrumbs deeper than two levels (none exist yet; a segment per level would each go back to its level).
- Restyling the header beyond the link look (underline on hover).

## Design notes
- UI only: `ScreenHeader` replaces `back_button` and its Label with a row of segments (`RichTextLabel` with meta links,
  or flat buttons). The hook keeps its name, `header.back_button`: it is now the parent's title as a flat link button
  ("Realm"), followed by a label " › River Meadow"; it keeps its focus behavior (Tab reaches it, Settings focuses it). `Navigator.titles()`
  stays the source. `UIKit.button_column`/`test_button_widths` don't involve it.
- Tests that read `header.back_button` change: `test_screen_header`, `test_start_screen`, `test_navigator`,
  `test_territory_view`, `test_button_widths`. Name them at the red checkpoint.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_screen_header::test_the_territory_header_goes_back_through_its_realm_link` |
| AC2 | `test_screen_header::test_the_new_game_and_settings_headers_go_back_through_their_main_menu_link` |
| AC3 | the same two (the link is the header's only button); `test_navigator` (at the root: no link) |
| AC4 | the existing suite, unchanged in behavior; changed texts "← Realm" / "← Main menu" → "Realm" / "Main menu" in `test_screen_header` (2 tests), `test_navigator`, `test_start_screen` (2 lines) |

## Manual check
- [ ] Open a territory, then click "Realm" in the header; open New game and Settings and click "Main menu".
- [ ] The link reads as clickable (hover underline, hand cursor) and the current page title doesn't.

## Log
