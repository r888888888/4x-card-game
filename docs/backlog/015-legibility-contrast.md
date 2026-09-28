---
id: 015
title: Legible text, contrast and button styles; say why a card can't be played
type: feature
status: ready
branch: feat/015-legibility-contrast
---

## Goal
All text meets WCAG AA contrast in every state, stays readable in a small window, and never relies
on colour or hover alone. The audit (2026-09-28) measured the red cost on a greyed card at ~3.5:1 and
"Idle: no worker" at ~2.7:1, because `modulate` dims the text along with the card. Text shrinks to
about 12px at 1280×720. Buttons look like plain text, and End turn barely stands out.

## Acceptance criteria
<!-- UI-only item: checked in the running game and with a contrast script (see Test plan). -->
- [ ] AC1: Given any text on a card in any state (playable, unplayable, idle, highlighted), then its
  contrast against the card background is at least 4.5:1. Greying and idling dim the card
  background, border and art, but not the text. Unplayable and idle cards stay easy to tell apart
  from normal cards.
- [ ] AC2: Given an unplayable hand card, then a strip at the bottom of the card shows "⊘ " + the
  engine's `play_error` text (e.g. "⊘ Settler needs 5 food (you have 2)"), wrapped, at 4.5:1 or
  more. A playable card has no strip. The tooltip still shows the reason.
- [ ] AC3: Given the window at 1280×720, then no text renders smaller than 14px on screen. The
  smallest font size at the 1680×1000 design size is 18px.
- [ ] AC4: Given the buttons, then each has a visible fill and border (at least 3:1 against the page)
  and a hover state. End turn is the only button in the accent colour. A disabled button still reads
  at 3:1 or more and looks disabled. Grow uses the normal button size (not 16px).
- [ ] AC5: Given each card type, then its border is at least 3:1 against the page, and the subtitle
  starts with a type marker that isn't only colour (e.g. a small glyph per type), so types can be told
  apart in greyscale.
- [ ] AC6: Given the seed field, then it has a visible field background and border (at least 3:1).

## Out of scope
- Layout and spacing (014).
- A UI scale setting (AC3 is met by raising the minimum sizes instead).
- Real card art or icons made from image assets.

## Design notes
- AC1: replace `modulate` greying in `CardView.set_play_error` and `set_idle` with dimmer colours on
  `_style` (bg, border). Label colours stay as they are. Idle marker: use a light colour on a darker
  red strip, not `ff8a80` on a greyed card.
- AC2 uses the existing `play_error` text (`_hand_error` in main.gd). There is no new engine API.
  If the text is too long for the card, shortening it is an engine change and gets its own item.
- A contrast check can live in a scratch script: render each card state, sample the colours, and
  compute the ratio. It isn't committed, since it is UI-only.

## Test plan
| AC | Test |
|---|---|
| all | Manual (UI only). Contrast ratios recomputed from the final colours with the audit's scratch script; before/after screenshots at 1280×720. |

## Manual check
Run `godot --path .` at about 1280×720.
- [ ] **AC1/AC2:** with 2 food, a 3-food card is dimmed, but its text is as crisp as on a playable card,
  with "⊘ Granary needs 3 food (you have 2)" under it.
- [ ] **AC1:** make a building idle: "Idle: no worker" is easy to read.
- [ ] **AC3:** the smallest text (subtitles, territory info, Grow) is comfortable to read.
- [ ] **AC4:** Restart and New game look like buttons, and End turn stands out as the main action.
  When disabled (explore pending) it is clearly disabled but still readable.
- [ ] **AC5:** in a greyscale screenshot you can still tell each card's type.

## Log
