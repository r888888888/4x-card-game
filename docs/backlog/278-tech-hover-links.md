---
id: 278
title: Hovering an available tech highlights its prerequisite and the techs it opens
type: feature
status: red-review
branch: feat/278-tech-hover-links
---

## Goal
On the Knowledge screen, hovering a tech you can research shows where it sits in the tree: its prerequisite tile and
the tiles that need it light up, so the player can trace dependencies without opening each tech.

## Acceptance criteria
- [ ] AC1: Given a tree where tech B has prereq A and techs C and D have prereq B, when the engine is asked for the
  links of B, then it returns prereq `A` and unlocks `[C, D]` (in tree order); for A, prereq is "" and unlocks is `[B]`;
  for an unknown id, both are empty.
- [ ] AC2: Given the Knowledge screen with tech B available, when the mouse enters B's tile, then A's tile and the
  tiles of C and D are marked as linked (a distinct look from normal, and from B's own hover look).
- [ ] AC3: Given linked tiles marked by AC2, when the mouse leaves B's tile, then no tile is marked.
- [ ] AC4: Given a researched, locked or later-era tile, when the mouse enters it, then no tile is marked (those
  keep today's hover only).
- [ ] AC5: Given tiles marked by AC2, when the screen is rebuilt (a tech researched, a new turn), then no stale mark
  remains and the new tiles are unmarked until hovered again.

## Out of scope
- Hover on keyboard focus (focus ring stays as is); hover links for researched, locked or later-era tiles.
- Highlighting the whole prerequisite chain (only the direct prerequisite and direct unlocks).
- Changes to the tile's own hover look or its tooltip.

## Design notes
- New engine query `tech_links(tech_id) -> {prereq: String, unlocks: Array[String]}` in `engine_queries.gd`, built
  from `tech_tree()` (a derived value, so the UI doesn't compute it).
- UI: `KnowledgeScreen` connects `mouse_entered`/`mouse_exited` on available tiles and sets a marked state on the
  linked tiles. The mark is a new `GameTheme` variation or stylebox override via `Palette` (a named colour for the
  link; no colour literals in `ui/`), with spacing from `Tokens`. Marking must not change tile size or layout.
- Test hooks: a `linked(tech_name) -> bool` accessor on the screen, like `tile()`.
- Sim bot: no effect (UI only).

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_tech_tree::test_tech_links_name_the_prerequisite_and_the_techs_it_opens_in_tree_order`, `…_of_a_tech_with_no_prerequisite_have_none`, `…_of_an_unknown_id_are_empty` |
| AC2 | `test_knowledge_screen::test_hovering_an_available_tile_marks_the_techs_it_opens`, `…_marks_its_prerequisite`, `test_the_mark_is_a_look_of_its_own` |
| AC3 | `test_the_mark_clears_when_the_mouse_leaves` |
| AC4 | `test_hovering_a_researched_or_locked_tile_marks_nothing`, `test_hovering_a_later_era_tile_marks_nothing` |
| AC5 | `test_a_rebuild_leaves_no_mark_behind` |

## Manual check
- [ ] Open Knowledge, hover an available tech: its prerequisite and the techs it opens show the link look; move away
  and it clears. Hover a researched or locked tech: nothing else lights up. Check it reads in Reduce motion too.

## Log
