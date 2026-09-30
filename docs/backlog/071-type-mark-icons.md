---
id: 071
title: Icons for the tech and event type marks
type: feature
status: review
branch: feat/071-type-mark-icons
---

## Goal
Action, building, city and territory cards draw their type mark as an icon (`ui/icons.gd`), but techs (✦) and events
(❖, 068) fall back to the text glyph, which looks different and depends on the font. Give both an icon in the same
hand-drawn style.

## Acceptance criteria
- [x] AC1: `Icons.GLYPHS` has an entry for every mark in `CardView.TYPE_MARKS` (so a new card type can't be added
  without an icon), each loading an SVG from `assets/icons/`.
- [x] AC2: The UI smoke test still passes (no missing-resource errors).

## Out of scope
- Redrawing the existing icons.

## Design notes
- New `assets/icons/tech.svg` and `assets/icons/event.svg`: white, 24×24, imported as DPITexture like the others,
  scale 0.6 like the other type marks.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_ui_smoke::test_every_type_mark_has_an_icon` |
| AC2 | `test_ui_smoke::test_main_scene_follows_a_whole_game_without_errors` (existing) |

## Manual check
- [ ] The tech and event marks read clearly beside the type name on a hand card, a compact card and in the log,
  and match the other icons' weight.

## Log
- From 068's follow-ups.
- 2026-09-30: Red. `TYPE_MARKS` moved to `CardFace` in 086; the test reads it there.
- 2026-09-30: Green. `assets/icons/tech.svg` (a four-point star) and `event.svg` (an eight-point burst), drawn as
  single filled paths like the other marks; import settings copied from `city.svg.import` (DPITexture, same params).
  Both in `Icons.GLYPHS` at scale 0.6. PLAN.md needs no change (it describes the icon folder, not each icon).
