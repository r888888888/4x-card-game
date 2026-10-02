---
id: 212
title: The new game screen as a civilization list and a detail pane
type: feature
status: review
branch: feat/212-civilization-list-and-detail
---

## Goal
Choosing a civilization reads like a master–detail list instead of a row of cards: the civilizations down the left,
the selected one's full story and rules on the right, with Start beside them. The player compares civilizations
without opening a details modal for each.

## Acceptance criteria
- [x] AC1: Given the new game screen opens with the six civilizations, then the left pane lists one row per
  civilization in config order (`civilization_ids()` unchanged), each a list-row button with its name (and the
  civilization type band colour as a left edge); the preselected one's row is selected (pressed look) and focused.
- [x] AC2: The right pane shows the selected civilization: its name (Title), its flavor paragraph and quote
  (attributed), its rules as card details give them (`CardDetailsModal.body_bbcode`: discounts, modifiers), and its
  home territory's name and keywords.
- [x] AC3: When another row is clicked, or the arrows move through the list, then `selected` becomes that civilization
  and the right pane shows it; no modal opens (the click no longer opens card details with Play as, 107).
- [x] AC4: The seed field and Start sit at the foot of the right pane; Start (or Enter in the seed field) starts a game
  as the selected civilization, as today (`start_requested`); an empty or non-numeric seed behaves as today.
- [x] AC5: The list and the pane are in one focus loop with the seed field, Start and the header's Back.
- [x] AC6: With no civilizations offered (a config without them), the list is hidden and the pane says the game
  offers none; Start still works (`selected` "").

## Out of scope
- New civilization content.

## Design notes
- `NewGameScreen.civilization_view(civ_id)` (a CardView) becomes `civilization_row(civ_id)`; its tests move.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_start_screen::test_the_list_has_a_row_per_civilization_with_its_band_and_the_preselected_one_pressed`; changed: `test_each_screen_focuses_its_first_button` (the selected row has the focus, not Start), `test_enter_presses_the_focused_button` (focuses Start before its Enter) |
| AC2 | `test_the_detail_pane_shows_the_selected_civilizations_story_rules_and_home` |
| AC3 | `test_a_click_or_the_arrows_select_without_opening_details`, `test_the_new_game_screen_opens_no_details_modal` |
| AC4 | `test_the_seed_field_and_start_sit_at_the_foot_of_the_pane`; existing Start / seed tests unchanged; changed: `test_button_widths::test_title_settings_and_new_game_columns_share_one_width` (Start fits its text instead of a centred column) |
| AC5 | changed: `test_tab_and_arrows_stay_on_the_open_screen_and_wrap` (Tab reaches every row, the seed field, Start and Back, and wraps) |
| AC6 | `test_with_no_civilizations_the_pane_says_so_and_start_still_works` |

Removed (107's click → details with "Play as", which AC3 ends): `test_clicking_a_civilization_selects_it_and_shows_its_flavor_and_bonuses`,
`test_a_click_on_close_closes_the_details_over_the_new_game_screen`, `test_play_as_in_the_details_starts_a_game_as_that_civilization`,
`test_details_in_play_have_no_play_as_button`. The details modal's action button ("Play as") has no other caller, so
the green phase removes it from `CardDetailsModal` too (207's footer test with an action must drop it if 207 lands first).

New hooks: `civilization_row(id)` (a toggle Button with an `Edge` band), `civilization_list`, `detail_pane`,
`detail_body`, `detail_title()`, `detail_text()`.

## Manual check
- [ ] Title → New game: the list and pane read well at 1280×720 in both palettes; a long flavor paragraph wraps
  inside the pane.

## Log
- Specced 2026-10-02 from the notes list.
- 2026-10-02: Built. `NewGameScreen` builds the list (toggle rows with an `Edge` band, Up/Down select) and the pane
  (title, `CardDetailsModal.body_bbcode` plus a Home line, the seed field, Start under it); `first_focus()` gives main the
  selected row. `CardView.type_color(type)` names the band colour. The details modal's "Play as" action went with 107's
  click-to-details (no other caller). Balance/content note: a civilization has no type colour of its own, so the band
  is the grey fallback; worth a palette role if the manual check finds it too faint.
