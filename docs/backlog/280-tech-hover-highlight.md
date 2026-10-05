---
id: 280
title: Highlight the hovered tech tile
type: feature
status: red-review
branch: feat/280-tech-hover-highlight
---

## Goal
The tech under the mouse on the Knowledge screen stands out, not just its neighbours (278): today it only gets a
hard shadow, which is easy to miss next to the gold link borders.

## Acceptance criteria
- [ ] AC1: Given a tech tile of any state (researched, available, locked, or a later era's under its vellum), when it
  is hovered, then its border is the `ACCENT` colour, different from its resting border, and its shadow stays.
- [ ] AC2: Given a tile marked as linked (278), when it is hovered, then it shows the same hover border as any other
  tile (the hovered tile wins over the link mark).
- [ ] AC3: Given the hover look, then the tile's size and layout don't change (the border width stays 2 px).

## Out of scope
- Keyboard focus (the focus ring stays as is), the link marks (278), tooltips.

## Design notes
- Theme only: the `hover` styleboxes of `TechTile`, `TechTileResearched`, `TechTileLocked` and their `…Linked`
  twins in `GameTheme._tech_tiles` take `Palette.ACCENT` as their border. No new palette name, no engine change.
- Tests read `get_theme_stylebox("hover")` on tiles of the real Knowledge screen.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_knowledge_screen::test_a_hovered_tile_of_any_state_has_an_accent_border` |
| AC2 | `test_knowledge_screen::test_a_hovered_linked_tile_shows_the_hover_border` |
| AC3 | `test_knowledge_screen::test_the_hover_border_keeps_the_tiles_width` |

## Manual check
- [ ] Hover each kind of tile: an orange border plus the shadow; the gold link borders are still distinct from it.

## Log
