---
id: 229
title: Clicking a tech opens its details; research from there
type: feature
status: red-review
branch: feat/229-research-from-tech-details
---

## Goal
On the Knowledge screen a click on an available tech tile learns it at once, so a click meant to read about a tech
spends insight by accident. After this, a click (or Enter) on any tile only opens the tech's details modal, and the
player commits to learning it with a Research button in that modal's footer, as 225 did for playing a hand card.

## Acceptance criteria
- [ ] AC1: Given the Knowledge screen open with Pottery available and 5 insight, when Pottery's tile is clicked (or
  focused and Enter pressed), then Pottery's details modal opens over the screen and nothing is learned (insight stays
  5, Pottery stays in the research deck).
- [ ] AC2: Given Pottery's details opened from its tile (cost 2, 5 insight), when the footer's Research button is
  pressed, then Pottery is learned (insight 3, Pottery in the researched zone), the modal closes, the Knowledge screen
  stays open and Pottery's tile reads `["Pottery", "✓"]`.
- [ ] AC3: Given a tech whose `buy_tech_error` is non-empty (Bronze Working with 4 insight, or Iron Working whose
  prerequisite isn't learned), when its details are opened from its tile, then Research is shown but disabled, its
  tooltip is that error, and pressing it learns nothing.
- [ ] AC4: Given the details of a researched tech or a later-era tech (under its vellum), or of any card opened
  outside the Knowledge screen (a hand card, a board card, a supply pile), then the modal shows no Research button.
- [ ] AC5: Given Writing's details open with Research shown, when the same modal is then opened for a board card, then
  Research is gone (the button follows what the modal is opened for).
- [ ] AC6: Given an available tile, its tooltip's last line no longer says a click learns it: it reads "Click, right
  click or I for the details." like every other tile.

## Out of scope
- A keyboard shortcut for Research inside the modal.
- Any change to the tile looks, markers, or the right click / I behaviour (still opens details).
- Engine changes: `buy_tech` / `buy_tech_error` are unchanged.

## Design notes
- UI-only. The engine already answers with `buy_tech_error(uid)` and `buy_tech(uid)`; the tile has `tech.uid`
  (from `tech_eras()`), -1 for a later-era tech.
- `KnowledgeScreen`'s `open_def` callback gains the tech's uid (or the screen passes a second callable) so
  `CardDetailsModal` can open a tech's details with Research: e.g. `open_tech(card_id, uid)`, Research shown when the
  tech is not researched and `uid >= 0`. Research is the footer's primary button, like Play; only one of Play and
  Research is ever visible. `closed()` forgets the uid.
- Removes the "click learns an available tile" path from `KnowledgeScreen._tile` and its tooltip line. Existing tests
  that encode the old behaviour (`test_a_click_on_an_available_tile_learns_it`,
  `test_enter_on_a_focused_available_tile_learns_it`, `test_a_click_on_a_tile_you_cant_learn_learns_nothing_and_says_why`,
  and any tooltip-text check) are rewritten to the new rule in this item; `test_there_is_no_learn_button` stays (no
  Learn button on the screen itself).
- Docs: update the class comment in `ui/knowledge_screen.gd` and `ui/card_details_modal.gd`.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_knowledge_screen::test_a_click_on_an_available_tile_opens_its_details_and_learns_nothing`, `test_knowledge_screen::test_enter_on_a_focused_available_tile_opens_its_details_and_learns_nothing` |
| AC2 | `test_knowledge_screen::test_research_in_a_techs_details_learns_it_and_closes_the_details` |
| AC3 | `test_knowledge_screen::test_research_is_disabled_with_the_reason_when_the_tech_cant_be_learned` |
| AC4 | `test_knowledge_screen::test_research_is_hidden_for_a_researched_tech`, `test_knowledge_screen::test_research_is_hidden_for_a_later_era_tech`, `test_details_modal::test_research_button_is_hidden_outside_the_knowledge_screen`, `test_details_modal::test_research_button_is_hidden_for_supply_pile_details` |
| AC5 | `test_knowledge_screen::test_research_goes_when_the_details_reopen_for_another_card` |
| AC6 | `test_knowledge_screen::test_an_available_tiles_tooltip_says_a_click_shows_the_details` |

## Manual check
- [ ] `godot --path . -- --seed 5`, press T: click an available tech; its details open and insight is unchanged.
  Research sits beside Close, sized to its text; press it and the tile turns to ✓.
- [ ] Open a locked tech's details: Research is dimmed and hovering it says which tech it needs.

## Log
- Red: replaced `test_a_click_on_an_available_tile_learns_it`, `test_enter_on_a_focused_available_tile_learns_it` and
  `test_a_click_on_a_tile_you_cant_learn_learns_nothing_and_says_why` (old rule) with AC1/AC3 tests.
