---
id: 241
title: Navigated screens open under a coloured title bar with a divider tab back
type: feature
status: red-review
branch: feat/241-screen-title-bar
---

## Goal
Off the Realm (Knowledge, a territory, the New game screen) it's hard to notice you've left it, and the way back is a
small underlined word. Every navigated screen now opens under a full-width title bar filled with its colour, and the
bar's left end is the index tab of the sheet underneath: "◂ Realm", a tab in the board's colour with a slanted right
edge that takes you back. The Realm has no bar, so a coloured bar always means you are somewhere else.

Design: [navigation-options.html](../design/navigation-options.html) option B, with the back control from
[back-button-options.html](../design/back-button-options.html) option 3 (the divider tab), without its Esc keycap.

## Acceptance criteria
- [ ] AC1: Given a game on the board, when a territory (Homeland) is opened, then its header's bar is filled with
  `Palette.TERRITORY`; when Knowledge is opened from the Realm, its bar is `Palette.TECH`; when New game is opened
  from the title screen, its bar is `Palette.CIVILIZATION`. The screen's title ("Homeland", "Knowledge",
  "New game") is in the bar, after the tab.
- [ ] AC2: Given a territory open over the Realm, then the header's back button reads "◂ Realm", has the tooltip
  "Back to Realm" and a pointing-hand cursor, uses the `DividerTab` theme variation, and is the header's only button;
  no text in the header mentions Esc. When it is pressed, the view closes and the Realm shows.
- [ ] AC3: Given Knowledge opened over a territory (Realm › Homeland › Knowledge), then its tab reads "◂ Homeland"
  (the parent only, not the whole path) and its title is "Knowledge"; when the tab is pressed, Knowledge closes and
  the Homeland view is still open.
- [ ] AC4: Given New game opened from the title screen, then its tab reads "◂ Main menu", and pressing it returns to
  the title screen.
- [ ] AC5: Given Knowledge open on turn 1, then its turn-and-era line ("Turn 1 · <era>") is inside the header's bar
  at its right end, after the title; the territory and New game bars have no such line.
- [ ] AC6: Given a game on the board with no screen open, then no ScreenHeader is visible: the Realm has no bar.

## Out of scope
- The sheet treatment of navigated screens (docs/design/sheet-options.html) and the key plan back control.
- A context line for the territory bar.
- Changing what Esc or T do (Esc and T still go back one step).
- The Supply screen, which is not a navigated screen.

## Design notes
- UI only: no engine, data or loader change.
- `ScreenHeader.new(nav, on_back, color)` takes the bar's colour; the bar is a `PanelContainer` filled with it, text
  in `Palette.TEXT_ON_PLANE`. The tab is the existing `back_button`, now not flat, with a new `GameTheme` variation
  `DividerTab` (fill `Palette.BACKGROUND`, text `Palette.TEXT`, a slanted right edge drawn by the variation's
  stylebox or a small `_draw`). Hover lightens it to the sheet colour, as in the mock.
- The tab names only the parent (`titles[-2]`), prefixed "◂ ". The bar's title label shows `titles[-1]`.
- `breadcrumb_text()` is replaced by `title_text()` (the bar's title) since the full path is no longer shown;
  tests that read the path move to `back_button.text` + `title_text()`.
- An optional `context` Control can be added to the bar's right end (`header.add_context(label)`); Knowledge moves
  its `_context` label there.
- This supersedes 118's "flat link" look (118's tests check `flat` and "Realm › …" link text). Those tests change
  with this item's criteria, not to make anything pass: the tab is still the parent's title and still the header's
  only button.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_screen_header::test_a_territory_opens_under_a_territory_coloured_bar`, `test_screen_header::test_new_game_opens_under_a_civilization_coloured_bar`, `test_knowledge_screen::test_knowledge_opens_under_a_tech_coloured_bar_with_its_context_at_the_right` |
| AC2 | `test_screen_header::test_the_territory_header_goes_back_through_its_realm_link` (`check_link_back`), `test_screen_header::test_the_territory_view_has_a_header`, `test_knowledge_screen::test_knowledge_is_a_screen_on_the_play_areas_navigator_with_a_header`, `test_navigator::test_the_header_names_the_screen_below_and_the_path` |
| AC3 | `test_knowledge_screen::test_over_a_territory_its_tab_goes_back_one_step_to_the_view`, `test_knowledge_screen::test_over_a_territory_view_it_pushes_on_top_and_back_returns_to_the_view` |
| AC4 | `test_screen_header::test_the_new_game_header_goes_back_through_its_main_menu_link`, `test_screen_header::test_the_new_game_screen_has_a_header`, `test_start_screen::test_new_game_opens_the_new_game_screen_without_starting` |
| AC5 | `test_knowledge_screen::test_knowledge_opens_under_a_tech_coloured_bar_with_its_context_at_the_right`; no context: the territory and New game bar tests |
| AC6 | `test_screen_header::test_the_realm_has_no_bar` (passes already: a guard) |

## Manual check
- [ ] The tab reads as the sheet underneath showing through: board colour, slanted right edge, flush with the bar's
  left and top and bottom edges, in Night and Day.
- [ ] Teal (Knowledge), sage (territory) and plum (New game) bars all keep their title legible.
- [ ] The territory view's grow-out-of-the-card transition and Knowledge's slide still look right with the bar.
- [ ] Tab focus reaches the tab and its focus ring shows on the board-coloured tab.

## Log
