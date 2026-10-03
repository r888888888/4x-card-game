---
id: 224
title: The Knowledge screen's slide moves the Hand, crosses the sidebar and shows the Realm through it
type: bug
status: review
branch: fix/224-knowledge-slide-polish
---

## Reproduction
- Seed: 5, civ sumer (`godot --path . -- --civ sumer --seed 5`), Reduce motion off.
- Steps:
  1. Wait for the opening deal to settle.
  2. Press T to open the Knowledge screen; press T again to close it.
- Expected: the Knowledge screen runs in over the Realm from the play area's right edge, as an opaque sheet; the
  Hand and the sidebar stay still.
- Actual (seen frame by frame with `--write-movie`, 60 fps):
  1. For the whole slide, in and out, the Hand section jumps to the top of the play area (its "In Hand" label over
     "Realm", its cards over the territories), then snaps back when the slide ends. `Navigator._slide_in` and
     `_slide_out` lift both the Realm and the Knowledge screen out of the play area's VBox (`top_level`), so the
     Hand is the only child left in its layout.
  2. The slide starts at the window's right edge, not the play area's, and nothing clips it: for the first frames the
     header and the tech tiles draw over the sidebar ("Realm › Knowledge" across "Sumer").
  3. The Knowledge screen has no background, so the Realm's cards show through its tech rows while it passes over.

## Acceptance criteria
- [x] AC1: Given a started game with Reduce motion off, when the Knowledge screen opens, then at every sampled frame
  of the slide (and once it is in place) the Hand section's global rect equals its rect before opening.
- [x] AC2: Given the Knowledge screen open, when it closes, then at every sampled frame of the slide out (and once it
  is gone) the Hand section's global rect equals its rect before opening.
- [x] AC3: Given the Knowledge screen opening with Reduce motion off, then it starts with its left edge at the play
  area's right edge (slide offset equals its own width) and, throughout the slide, it is clipped to the play area's
  rect: no part of it is drawn right of the play area, over the sidebar.
- [x] AC4: Given the Knowledge screen open, then it has an opaque background covering its whole rect (a fill with
  alpha 1, a `Palette` colour named for the board/sheet), so nothing under it shows through during the slide or at
  rest.
- [x] AC5: Given Reduce motion on, when the Knowledge screen opens and closes, then it still only fades (0.12 s), and
  the Hand section's global rect never changes.
- [x] AC6 (stays correct): the existing slide timings and the Realm's 24 px shift (`test_it_slides_in_from_the_right_
  as_the_realm_shifts_left`), and opening over a territory view, keep passing unchanged.

## Test plan
| AC | Test |
|---|---|
| AC1, AC2 | `test_knowledge_screen::test_bug_224_the_hand_stays_put_while_it_slides_in_and_out` |
| AC3 | `test_knowledge_screen::test_bug_224_it_runs_in_from_the_play_areas_edge_under_the_sidebar` |
| AC4 | `test_knowledge_screen::test_bug_224_the_sheet_is_opaque` |
| AC5 | `test_knowledge_screen::test_bug_224_with_reduce_motion_the_hand_stays_put` (a guard: passes already) |
| AC6 | the existing `test_knowledge_screen` slide, fade and territory-view tests, unchanged |

## Design notes
- Likely fix for AC1/AC2: while a screen that occupies its container's layout is lifted, a stand-in Control with its
  size flags and size holds its slot, removed when it lands (only one stand-in per slide: the screen in the layout
  at the start, i.e. the one below on the way in, the leaving screen on the way out).
- AC3: the slide's travel is the screen's width (to the play area's edge), and the sliding screens are clipped to the
  play area (e.g. a clipping holder, or the sidebar drawing over them); pick whichever keeps `Navigator` free of
  game knowledge.
- AC4: a background on `KnowledgeScreen` (a `GameTheme` panel variation), not a per-control colour override.
- `Navigator` is UI, so this needs no engine change; the Knowledge screen is the only screen pushed with `slide`.

## Root cause
`Navigator._slide_in` / `_slide_out` take both sliding screens out of the play area's VBox (`top_level`) so they can
move freely, which left the Hand the only child in its layout: it moved up into the Realm's slot until the screens
landed. Now `_hold` puts an empty stand-in of the lifted screen's size and size flags in its slot (the Realm on the way
in, the Knowledge screen on the way out) and `_release` removes it when the screens land. The slide's travel was the
distance to the window's right edge, past the sidebar; it is now the screen's own width, and the sidebar (z_index 1,
the Rail filled with `Palette.BACKGROUND`) draws over it: a lifted screen is parented to the canvas, so its container
can't clip it. The Knowledge screen, a VBoxContainer, drew no background; it now fills its rect with `sheet_color()`.
The 208 tests checked the slide's offsets and timings, never where the sections around it were or what it covered.

## Manual check
- Record the open and close (`--write-movie`, seed 5) or watch at 1920×1080 and at a narrow window: the Hand never
  moves, nothing crosses the sidebar, the Realm doesn't show through the sheet, and the slide feels like one sheet
  running along a rail.

## Log
- 2026-10-02: specced from a frame-by-frame recording of the transition (seed 5, sumer).
- 2026-10-02: AC3 met by drawing the sidebar over the sheet rather than clipping it (a top_level Control escapes its
  parent's clip). That conflicted with 221's "the rail has no fill of its own"; with the user's approval that check now
  also allows a fill in the board's colour (`test_sidebar::test_the_rail_is_open_on_the_board_with_a_hairline_to_its_left`).
  Re-recorded after the fix: the hand stays still, nothing crosses the sidebar, the Realm doesn't show through.
- Follow-up idea (not specced): the tech tree has only the Realm's height; if more eras make it scroll a lot on short
  windows, consider a taller sheet that leaves the Research cards in view.
