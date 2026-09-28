---
id: 015
title: Legible text, contrast and button styles; say why a card can't be played
type: feature
status: review
branch: feat/015-legibility-contrast
---

## Goal
All text meets WCAG AA contrast in every state, stays readable in a small window, and never relies
on colour or hover alone. The audit (2026-09-28) measured the red cost on a greyed card at ~3.5:1 and
"Idle: no worker" at ~2.7:1, because `modulate` dims the text along with the card. Text shrinks to
about 12px at 1280×720. Buttons look like plain text, and End turn barely stands out.

## Acceptance criteria
<!-- UI-only item: checked in the running game and with a contrast script (see Test plan). -->
- [x] AC1: Given any text on a card in any state (playable, unplayable, idle, highlighted), then its
  contrast against the card background is at least 4.5:1. Greying and idling dim the card
  background, border and art, but not the text. Unplayable and idle cards stay easy to tell apart
  from normal cards.
- [x] AC2: Given an unplayable hand card, then a strip at the bottom of the card shows "⊘ " + the
  engine's `play_error` text (e.g. "⊘ Settler needs 5 food (you have 2)"), wrapped, at 4.5:1 or
  more. A playable card has no strip. The tooltip still shows the reason.
- [x] AC3: Given the window at 1280×720, then no text renders smaller than 13px on screen. The
  smallest font size at the 1680×1000 design size is 18px. *(Changed from "14px" during the build:
  the 0.72 stretch scale at 1280×720 makes 18px render at 13px. A UI scale setting would be its own item.)*
- [x] AC7: Given a territory in the frontier, then it shows as a compact card (name, then slots, housing
  and keywords, about 95px tall). When it is settled onto the tableau, it shows at full size again.
  *(Added during the build to win back the height the reason strips need.)*
- [x] AC4: Given the buttons, then each has a visible fill and border (at least 3:1 against the page)
  and a hover state. End turn is the only button in the accent colour. A disabled button still reads
  at 3:1 or more and looks disabled. Grow uses the normal button size (not 16px).
- [x] AC5: Given each card type, then its border is at least 3:1 against the page, and the subtitle
  starts with a type marker that isn't only colour (e.g. a small glyph per type), so types can be told
  apart in greyscale.
- [x] AC6: Given the seed field, then it has a visible field background and border (at least 3:1).

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
| all | Manual (UI only). Contrast ratios recomputed from the final colours with the audit's scratch script (all pairs pass: card text 7.5–9.5:1 in every state, reason strip 10.5:1, disabled button text 4.9:1, borders 3.8–5.4:1). Screenshots at 1680×1000 and 1280×720, plus a greyscale copy for AC5. |

## Manual check
Run `godot --path .`, type seed `4242`, and press Restart. Play cards each turn and use Scout when you
have it. Check again with the window at about 1280×720.
- [ ] **AC1/AC2:** an unplayable card has a grey background and border, but its text is as crisp as a
  playable card's. A dark red strip at the bottom gives the reason, e.g. "⊘ Temple needs 4 food (you
  have 3)." or "⊘ No territory with a free slot.". Hovering shows the same reason.
- [ ] **AC1:** grow past your buildings' workers (or let pop starve) so a building goes idle. It greys the
  same way, with "⊘ Idle: no worker" in the strip.
- [ ] **AC3:** at 1280×720 the smallest text (type lines, territory info, strips) is still comfortable to read.
- [ ] **AC4:** Restart, New game and Grow have a fill and border, and get lighter with a white border on
  hover. End turn is the only gold button. Grow with too little food is clearly disabled but readable.
- [ ] **AC5:** each type line starts with a shape (◆ action, ■ building, ● city, ▲ territory).
- [ ] **AC6:** the seed field is a dark box with a border, and its border turns gold when you click into it.
- [ ] **AC7:** frontier territories are short cards (name and info). Settle one, and it grows to a full
  card in the tableau.
- [ ] **Worst case:** with 3 frontier cards and Lumber Camp unplayable in the hand, the hand and End
  turn stay inside the window.

## Log
- AC3 amended (14px → 13px at 1280×720) and AC7 added, both agreed during the build. The 0.72 stretch
  scale made the original AC3 impossible with an 18px minimum. The reason strips needed height back.
- The height budget was tight. The worst case (3-line frontier info, and an unplayable Lumber Camp with
  4 rules lines and a 3-line reason) was 86px too tall. Won back with: the compact frontier (AC7); the
  cost moved from the title row to the type line, so titles no longer wrap; and hand cards widened from
  215 to 232 px, with the log narrowed from 400 to 360 px, so fewer lines wrap. That case now fits
  exactly: the hand ends at the bottom margin, and the tableau keeps 271px. A card with even more text
  would take a few px from the tableau, which scrolls.
- Found and fixed: `set_play_error` looked for the `Cost` label as a direct child of the card box, but
  it lived in the header row. The cost had never turned red. Once fixed, it turned red for any
  unplayable card, including one you can afford but can't place (a false signal). Deciding "can't
  afford" would be rule logic in the UI, so the cost now stays gold and the strip gives the reason.
- Dimming no longer uses `modulate`. It swaps the card's stylebox colours (`DIM_BG`, `DIM_BORDER`), so
  `modulate.a` stays free for the deal and discard fades.
- Hover lift from 014 is unchanged. Theme styles are set in `main.gd::_style_controls`. End turn uses the
  `AccentButton` type variation.
- UI only; test count unchanged (155).
- Follow-ups: shorter reason strings (e.g. without repeating the card name) would be an engine change
  and need their own item. A UI scale setting is also its own item.
