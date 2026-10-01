---
id: 088
title: Civilization and government as side-panel lines, not card rows
type: feature
status: done
branch: feat/088-identity-in-side-panel
---

## Goal
The civilization (062) and the government (065) each take a heading and a row of one compact card in the play area,
about 140px each, between Known and Events. That space is better spent on the Realm, the hand and the events. Show
each as one line in the side panel instead, with its rules on hover and its details on click.

## Acceptance criteria
<!-- UI tests run the real main.tscn (real data: Children of the River, Chiefdom at the start). -->
- [x] AC1 (rows gone): Given the main scene after `start_game(1)`, then `main.section_headings()` has no
  "Civilization" or "Government" heading, and no card view shows the civilization or the government (neither uid is
  in `main.views`).
- [x] AC2 (lines): Given the same game, then the side panel shows two lines, in this order, above the Knowledge
  button: "Civilization: Children of the River" and "Government: Chiefdom". Test hook: `main.identity_lines()`
  returns `[{text, tooltip}, …]` for the visible lines, top to bottom.
- [x] AC3 (tooltip): each line's tooltip is its card's `rules_tooltip`: the civilization's contains
  "Each upkeep: +1 food". A card with no rules text (Chiefdom) has the tooltip "No bonus.".
- [x] AC4 (details): Given the same game, when the civilization line is pressed, then the details modal shows
  Children of the River (`main.details.shown().name`). Pressing the government line shows Chiefdom's details.
- [x] AC5 (government changes): Given a Kingship in hand, when it is played (`try_play` or `play_card` followed by the
  board's refresh), then the government line reads "Government: Kingship", its tooltip is Kingship's `rules_tooltip`,
  and Kingship's uid is not in `main.views` once the play has finished.
- [x] AC6 (none): Given main running fixture data with no `starting.civilization` and no `starting.government`, then
  `main.identity_lines()` is empty (both lines hidden).
- [x] AC7 (fits the screen, regression from 065): Given the main scene after `start_game(1)`, then its minimum height
  after layout, End turn's bottom edge is at most 1080 in a 1920×1080 window, so it is on screen. Measured before
  this item: the side panel ends at 1183px (1062px before 065 added the Government row).

## Out of scope
- Any engine or data change: `civilization()`, `government()` and the card defs already give what the lines show.
- Keyboard focus on the lines beyond ordinary button focus (Tab), and a `I`-key shortcut for them.
- The start screen's civilization cards (063/064), the menu's "Playing as …" and the game-over text.

## Design notes
- UI only. `SidePanel` gets the two lines (flat buttons, like the Knowledge button's style but one line each) and a
  `refresh(e)` that reads `e.civilization()` / `e.government()`. Pressing one calls `details.open_def(card_id)`.
- `main.gd` drops `_row_sections.civilization` and `.government`, so the rows, their views and their headings go.
  A played government's view then leaves the board like any card that isn't shown: make it fly to the government
  line (`_leave_point`) instead of the discard counter.
- Long names: the line clips with an ellipsis at the panel's 360px; the tooltip still names the card in full.
- No engine query needed: the text is the card's name and `rules_tooltip`, which the UI already reads elsewhere.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_identity_lines::test_no_civilization_or_government_rows_in_the_play_area` |
| AC2 | `test_identity_lines::test_side_panel_shows_civilization_then_government`, `::test_identity_lines_sit_above_the_knowledge_button` |
| AC3 | `test_identity_lines::test_side_panel_shows_civilization_then_government` |
| AC4 | `test_identity_lines::test_pressing_a_line_opens_its_details` |
| AC5 | `test_identity_lines::test_playing_a_government_updates_its_line` |
| AC6 | `test_identity_lines::test_no_lines_without_a_civilization_or_government` |
| AC7 | `test_identity_lines::test_bug_088_end_turn_is_on_screen_at_1080` |

## Manual check
- [ ] At 1920×1080 the play area no longer has Civilization or Government rows, and the Realm and hand have more room.
- [ ] The two lines sit above Knowledge and don't squeeze the log noticeably; a long civilization name ends in "…".
- [ ] Hover shows the full rules; clicking opens the same details modal as before.
- [ ] Playing Kingship flies the card to the government line, which then reads "Government: Kingship".

## Log
- 2026-09-29: AC7 added when 078's rendered check found End turn off screen at 1920×1080 (065 regression). Moved
  ahead of 087 in the planned order.
- Red at 586 tests (was 579), 7 failing. AC7 first used `main.get_combined_minimum_size().y`, but without a layout
  pass minimum sizes are meaningless (main 0, the board 2021px). So the runner now awaits each test
  (`await t.call(...)`, a plain test returns at once), and `test_case.wait_frames(n)` lets a UI test lay out first.
  The test sets the window to 1920×1080 (headless starts at 1920×1920) and measures End turn at 1183px, the same as
  the rendered game. New hook besides `identity_lines()`: `identity_buttons()`, to press a line.
- Approved at red. Green: `SidePanel` builds the two lines above Knowledge (left-aligned, ellipsis) and fills them in
  `refresh`; `main.gd` drops the two row sections; a played government's view flies to its line
  (`SidePanel.identity_point`). No engine change. 586 tests.
- Rendered at 1920×1080 (seed 1): the side panel ends at 1062px (was 1183), End turn fully visible.
