---
id: 233
title: Make tooltips readable: more contrast and padding
type: feature
status: red-review
branch: feat/233-tooltip-readability
---

## Goal
Tooltips fall back to Godot's default look: a grey box with grey text and little padding, hard to read over the
board. The style guide (§11.11, component 9) calls a tooltip a printed tab: `ink` fill with inverse `sheet` text, in
Night and Day alike, cut square. Styling the theme's `TooltipPanel` and `TooltipLabel` that way gives the highest
contrast the palette has, and roomier padding makes the text easier to read. The locked tip (187) uses the same types,
so it follows.

## Acceptance criteria
- [ ] AC1: Given the theme built in Night or in Day mode, then `TooltipPanel`'s panel is a flat box filled with ink
  (`Palette.TEXT`), square (`RADIUS_0`), with content margins of `SPACE_4` across and `SPACE_3` down.
- [ ] AC2: Given the same theme, then `TooltipLabel` draws sheet-coloured text (`Palette.RAISED`) at `TYPE_BODY_S`.

## Out of scope
- The guide's notch, 320 px max width, show delay and slide-in.

## Test plan
| AC | Test |
|---|---|
| AC1, AC2 | `test_theme::test_tooltips_are_ink_tabs_with_room` |

## Manual check
- [ ] Hover a card, the End turn key and a top-bar stat in Night and in Day mode: the tooltip is a dark ink tab in
  Night's light-ink / Day's dark-ink inverse, readable, with clear space around the text.

## Log
