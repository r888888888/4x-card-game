---
id: 202
title: A right sidebar with the civilization and government
type: feature
status: review
branch: feat/202-civilization-sidebar
---

## Goal
The board gets the mock's rail (`docs/design/transitions.html`, `.rail`) on the right: the civilization's name and its
government, which open the civilization modal. It replaces the top bar's "Sumer · Chiefdom" button and gives End turn
(203) a home.

## Acceptance criteria
- [x] AC1: Given a game in progress, then a sidebar is shown at the board's right edge, full height under the top
  strip, with the Realm and the hand to its left: a "CIVILIZATION" heading, the civilization's name (Title variation,
  e.g. "Sumer") and the government as a link button ("Chiefdom ›").
- [x] AC2: When the civilization's name or the government link is clicked (or focused and Enter pressed), then the
  civilization modal (`IdentityModal`) opens, as the top bar's button does today; it grows out of / plays from the
  clicked control's position where the old button's did.
- [x] AC3: Given the government changes (Anarchy falls, a new government is chosen), then the sidebar's government
  updates on the next refresh; under Anarchy it reads "Anarchy ›".
- [x] AC4: The top bar no longer has the civilization button (`TopBar.identity_button()` goes; its callers use the
  sidebar's).
- [x] AC5: The sidebar's controls are in the board's focus order, after the top strip's buttons.
- [x] AC6: Given the title screen or the new game screen is showing, the sidebar is hidden with the board.

## Out of scope
- End turn's move (203); Revolt (205).

## Design notes
- New `ui/sidebar.gd` (`Sidebar`), built by `BoardLayout`, `DarkPanel`-style sheet with a top rule like the mock's.
  Width is a token step (e.g. `Tokens.SPACE_9 * 3`); judge at the manual check.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_sidebar::test_the_sidebar_names_the_civilization_and_its_government`, `test_the_sidebar_runs_down_the_right_edge_with_the_realm_and_hand_to_its_left`; changed: `test_board_layout::test_no_side_panel_and_the_board_spans_the_window` → `…_reaches_the_sidebar` |
| AC2 | `test_sidebar::test_the_name_or_the_government_opens_the_civilization_modal` |
| AC3 | `test_sidebar::test_under_anarchy_the_sidebar_reads_anarchy`; changed: `test_identity_lines::test_choosing_a_government_updates_the_sidebar_and_an_open_modal` |
| AC4 | `test_sidebar::test_the_top_bar_has_no_civilization_button`; changed: `test_board_layout::test_the_top_bar_holds_supply_and_knowledge_before_menu`; removed: `test_identity_lines::test_one_top_bar_button_names_the_civilization_and_government` (replaced by the sidebar tests) |
| AC5 | `test_sidebar::test_tab_from_the_strips_last_button_reaches_the_sidebar` |
| AC6 | `test_sidebar::test_the_sidebar_is_hidden_on_the_title_and_new_game_screens` |
| — | `main.identity_button()` goes with the top-bar button: `test_identity_lines` (civilization-only, government-only, neither), `test_modal_stack`, `test_government_deck` press `main.sidebar.government_button` (or `name_button`) instead |

Decisions made writing the tests: with no civilization the name is hidden, with no government the link is hidden (the
sidebar itself stays, for End turn in 203); the name is a Button at `TYPE_TITLE`, the government a `Link` button.

## Manual check
- [ ] Seed 5: the rail reads like the mock's (rule, caps heading, name, "Chiefdom ›") in both palettes; the Realm and
  hand reflow to its left without overlap at 1280×720 and 1920×1080.

## Log
- Specced 2026-10-02 from the notes list.
- 2026-10-02: Built. `ui/sidebar.gd` (`Sidebar`, `main.sidebar`, `Sidebar.WIDTH` = `SPACE_9 * 3`) beside the play area in
  `BoardLayout`; the name in a new `TitleLink` variation (Link in ink), the government a `Link`. The top bar lost its
  civilization button and its `on_identity` argument; the Menu button's focus_next is the sidebar's name. A played
  government flies to `Sidebar.government_point()`. `test_sidebar`'s AC4 check reads TopBar's method list instead of
  building one (its constructor lost an argument).
