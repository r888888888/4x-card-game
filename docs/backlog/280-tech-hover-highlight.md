---
id: 280
title: Highlight the hovered tech tile
type: feature
status: red-review
branch: feat/280-tech-hover-highlight
---

## Goal
The tech under the mouse on the Knowledge screen stands out, not just its neighbours (278). Today it only gets a 2 px
hard shadow, which is invisible on the Night board and easy to miss next to the gold link borders. The hover reuses
the game's existing hovers rather than a new look: the index cards' ink rule on a 4 px shadow (`CardView`,
`IdentityCard`) plus the buttons' lighter fill (`Button`, End turn).

## Acceptance criteria
- [ ] AC1: Given a tech tile of any state (researched, available, locked, or a later era's under its vellum), when it
  is hovered, then its hover look has a `Palette.TEXT` border, a solid `Palette.SHADOW` shadow (size 1) at offset
  `GameTheme.SELECTED_SHADOW` (4, 4), and its resting fill lightened by 0.08.
- [ ] AC2: Given a tile marked as linked (278), when it is hovered, then its hover look is the same as that state's
  unlinked hover look (ink border, not the gold `TECH_LINK` one): the hovered tile wins over the link mark.
- [ ] AC3: Given the hover look, then the tile's border width (2 px) and content margins are the same as at rest, so
  nothing moves.

## Out of scope
- Lifting the tile the way hand cards lift; keyboard focus (the focus ring stays); the link marks (278); tooltips.

## Design notes
- Theme only, in `GameTheme._tech_tiles`: the `hover` stylebox of `TechTile`, `TechTileResearched` and
  `TechTileLocked` gets `border_color = Palette.TEXT`, `shadow_offset = SELECTED_SHADOW` (was `PLINTH`) and
  `bg_color = <fill>.lightened(0.08)` (the same step as `_controls` and `_end_turn_key`); each `…Linked` twin's
  `hover` is that same stylebox. No new palette name, no engine change.
- Tried in `spike/tech-hover-highlight`: an `ACCENT` border clashed with the gold links; the cards' hover alone
  (ink border, 4 px shadow) showed no change in Night mode, where available tiles already rest with an ink border
  and the shadow is near-black on the board. The lighter fill is what shows in Night.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_knowledge_screen::test_a_hovered_tile_of_any_state_reuses_the_cards_and_buttons_hover`, `test_a_hovered_tile_of_a_later_era_reuses_the_hover` |
| AC2 | `test_knowledge_screen::test_a_hovered_linked_tile_shows_the_hover_not_the_link` |
| AC3 | `test_knowledge_screen::test_the_hover_keeps_the_tiles_border_and_margins` |

## Manual check
- [ ] Night mode: hover a researched, an available and a locked tile: each lightens, with an ink border and a 4 px
  shadow. Hover an available tile, then move onto one of its gold-bordered neighbours: it takes the same hover.
- [ ] Day mode: the same, the shadow now clearly visible.

## Log
