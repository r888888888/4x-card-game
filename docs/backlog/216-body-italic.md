---
id: 216
title: A real italic for the body face
type: feature
status: in-progress
branch: feat/216-body-italic
---

## Goal
Flavor text (`[i]…[/i]` in a RichBody, e.g. a card's details) shows in Barlow Italic instead of upright Barlow
Regular. 178 shipped only Barlow Regular for body text, so RichBody had an italics size but no italics face (noted
in 205's Manual check); 215's flavor expects italics.

## Acceptance criteria
- [ ] AC1: Given `GameTheme.build()`, then the `RichBody` variation's `italics_font` is set, and its base font is
  `assets/fonts/Barlow-Italic.ttf`, through `GameTheme.tabular()` (`tnum` and `lnum` on) like the body font.
- [ ] AC2: Given a RichTextLabel with `theme_type_variation = &"RichBody"` in the main scene, then its resolved
  `italics_font` is the Barlow Italic face (not the theme's default font), while its `normal_font` stays Barlow
  Regular.

## Out of scope
- A bold italic (`[b][i]`): would need `Barlow-SemiBoldItalic.ttf`; not asked for.
- Italic for plain `Label`s or other variations.

## Design notes
- `assets/fonts/Barlow-Italic.ttf` from google/fonts (`ofl/barlow/`, 109,624 bytes), the same source as
  `Barlow-Regular.ttf` (byte-identical copy); covered by the existing `OFL-Barlow.txt`.
- `GameTheme.ITALIC_FONT` beside `BODY_FONT`.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_type_tokens::test_rich_body_italics_are_barlow_italic_with_the_body_fonts_figures` |
| AC2 | `test_type_tokens::test_a_rich_body_in_the_main_scene_draws_italics_in_barlow_italic` |

## Manual check
- [ ] Open a card with flavor in its details: the flavor is slanted Barlow, the rules upright.

## Log
