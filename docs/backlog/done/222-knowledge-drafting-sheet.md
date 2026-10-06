---
id: 222
title: Draw the Knowledge screen as the mock's drafting sheet
type: feature
status: done
branch: feat/222-knowledge-drafting-sheet
---

## Goal
The Knowledge screen (208) has the mock's slide and breadcrumb, but its tiles are still the old modal's tall text
buttons with a Learn button beside them. This item gives it the look of `docs/design/mocks/transitions.html` transition 1
and style guide §11.3: each era a band with its title block at the left, compact index-card tiles whose fill says
their state, and a vellum sheet over an era not reached yet. Learning becomes a click on the tile.

## Acceptance criteria
- [x] AC1: Given the screen is open, each era row is a title block (the era name in caps, a fixed-width column) at the
  left of that era's tiles, with a hairline rule above the row; the rows keep `tech_eras()` order.
- [x] AC2: Each tile is one fixed size (a `Tokens` step, as wide as the mock's 120×62 at 1×) showing the tech's name and
  one marker at its top-right, by state: researched "✓"; available its insight cost now (`tech.cost`); locked
  "needs <prerequisite name>"; future no marker. A tile that isn't researched and whose eureka is met also shows "✔ Eureka". The state is also in words (the tile's tooltip begins with it: Researched, Available, Locked, Later
  era), not colour alone.
- [x] AC3: Tile looks, as theme variations in `GameTheme` with colours from `Palette`: researched filled with the teal
  plane, text in the on-plane colour; available the sheet colour with a 2 px ink border; locked the well colour, a
  rule-coloured border and ink-3 text; future like available (the vellum covers it). There is no Learn button.
- [x] AC4: Given an available tech with `buy_tech_error(uid) == ""`, when its tile is left-clicked (or focused and
  Enter/Space pressed), then the tech is learned and the screen stays open with that tile now researched. Given
  `buy_tech_error` is non-empty, the click learns nothing and the tile's tooltip shows that error.
- [x] AC5: A left click on a researched, locked or future tile, or a right click or I on any tile, opens the card
  details modal for that tech over the screen (as 208's AC4). The tooltip of every tile lists what it gives and its
  eureka text when it has one.
- [x] AC6: Given an era not reached, its row is covered by a vellum panel (the `vellum` colour, sheet at 88%) that
  reads "<ERA NAME> · OPENS AT 8 POP OR 15 WEALTH" (from its `unlocks`, the same wording as today's status, in caps;
  "· OPENS THROUGH A TECH" when it has no thresholds). Its tiles stay underneath, and a click on the vellum opens
  nothing. The whole row is no longer dimmed with `FUTURE` modulate.

## Out of scope
- Prerequisite lines between tiles, the learn burst and lamps (§11.3's animation), the breakthrough sound.
- The slide in and out (done in 208).
- Tech rules.

## Design notes
- New `Palette` entries (both palettes) named for their use, e.g. `TECH_RESEARCHED_FILL` (`p-teal`: night 5FB0A9,
  paper 5E9C97), `TECH_LOCKED_FILL` (`well`), `VELLUM` (sheet at 88%), unless matching ones already exist.
- New `GameTheme` variations, e.g. `TechTile`, `TechTileResearched`, `TechTileLocked`, `Vellum`.
- The insight line and context caps at the top stay as they are.
- `buy_tech_error` and `buy_tech` already exist; no engine change is expected. If the tile needs a derived value
  that isn't in `tech_tree()`, add it to the engine under TDD.
- Tests from 208 that look for the Learn button (`test_an_available_tech_has_a_learn_button_that_learns_it`,
  `test_a_learn_button_you_cant_use_is_disabled_with_the_reason`, `test_a_locked_tech_says_what_it_needs_and_has_no_learn_button`,
  `test_a_future_era_row_is_dimmed_and_shows_its_unlocks`) change with this item's criteria.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_knowledge_screen::test_each_era_is_a_row_headed_in_caps`, `test_each_era_has_its_title_block_at_the_left_of_its_tiles` (the hairline rule is a manual check) |
| AC2 | `test_each_tile_shows_its_name_and_a_marker_for_its_state`, `test_a_future_tile_has_no_marker_and_says_later_era`, `test_every_tile_is_one_fixed_size`; `test_eurekas::test_the_tree_shows_a_eureka_and_ticks_it_when_met` |
| AC3 | `test_tiles_look_like_their_state`, `test_there_is_no_learn_button`, `test_a_tiles_texts_all_have_room_to_show` (added in green: a corner marker had clipped to 1 px) |
| AC4 | `test_a_click_on_an_available_tile_learns_it`, `test_enter_on_a_focused_available_tile_learns_it`, `test_a_click_on_a_tile_you_cant_learn_learns_nothing_and_says_why` |
| AC5 | `test_a_click_on_a_tile_that_isnt_available_opens_its_details`, `test_a_right_click_on_an_available_tile_opens_its_details_and_learns_nothing`, `test_i_on_a_focused_tile_opens_its_details`, `test_a_tiles_tooltip_lists_what_it_gives`; the eureka text in the tooltip in `test_eurekas` |
| AC6 | `test_a_future_era_is_under_vellum_with_its_unlocks`, `test_the_vellum_names_each_threshold` |

Replaced (208's Learn-button and dimmed-row tests): `test_an_available_tech_has_a_learn_button_that_learns_it`,
`test_a_learn_button_you_cant_use_is_disabled_with_the_reason`, `test_a_locked_tech_says_what_it_needs_and_has_no_learn_button`,
`test_a_future_era_row_is_dimmed_and_shows_its_unlocks`, `test_a_click_on_a_tile_opens_its_details_over_the_screen`
(it clicked Writing, which is available and now learns). `test_eurekas::test_the_tree_shows_a_eureka_and_ticks_it_when_met`
now reads the eureka from the tooltip and "✔ Eureka" from the tile.

## Manual check
Run `godot --path . -- --seed 5`, gain some insight (play Research), press T.
- [ ] Each era row has a hairline rule above it; the era names sit in one left column.
- [ ] Compare with `transitions.html` transition 1 in both palettes (Settings → Day mode): tile size and markers
  (✓, the cost at the top right, "needs …" on its own line), teal researched tiles with dark text, well locked tiles,
  the vellum over the Bronze and Iron Age bands with how each opens.
- [ ] The 3-era tree fits at 1280×720 (it did in a headless capture: 7 tiles a row, all three bands, no scroll).
- [ ] Hovering a tile puts it on its 2 px plinth shadow; the focus ring shows when tabbing to a tile.
- [ ] Click an available tile you can afford: it turns teal with ✓ and the next tile with that prerequisite becomes
  available. Click one you can't afford: nothing happens; hover says why. Right-click any tile: its details.

## Log
- 2026-10-02: Built in a worktree. Tiles are Buttons (`TechTile`, `TechTileResearched`, `TechTileLocked` in
  `GameTheme`, with `TechTileText*` labels) of `KnowledgeScreen.TILE_SIZE` (192×96); the vellum is an `EraVellum`
  panel over the era's band (a `MarginContainer`), taking its clicks. New `Palette.RESEARCHED_FILL` and
  `TEXT_ON_PLANE`; the old `RESEARCHED`, `AVAILABLE`, `FUTURE` and `LOCKED` roles had no users left and went.
  The vellum test's fixture threshold went from 15 to 30 wealth: the fixture starts with 20, so 15 opened the era.
  A headless capture showed the corner markers clipped to 1 px (`clip_text` on a non-expanding label); fixed, and
  `test_a_tiles_texts_all_have_room_to_show` added (seen failing without the fix).
- Follow-up: learning by Enter rebuilds the rows, so the keyboard focus is lost after each learn; keeping it on the
  same tile would make keyboard research smoother.
- Specced 2026-10-02 from the request "model the tech tree after transitions.html". Decided: compact tiles, a click
  learns an available tech (no Learn button), details on right-click / I / click on other tiles; the vellum keeps the
  unlock thresholds rather than the mock's "OPENS IN ERA III".
