---
id: 014
title: Fix card overlap and section spacing; explore choice as an overlay
type: feature
status: in-progress
branch: feat/014-layout-spacing
---

## Goal
Every card and section can be read in full at any time. The design audit (2026-09-28)
found that cards draw over their neighbours, that the tableau shrinks to a thin strip while an explore
choice is open, and that the game-over text sits on top of the board with no background. Sections also
have too little space between them to read as separate areas.

## Acceptance criteria
<!-- UI-only item: each criterion is checked in the running game (see Manual check). No engine change. -->
- [ ] AC1: Given any card in any zone (hand, tableau, frontier, choice), when it is laid out, then
  it is exactly its slot width (215px) and does not overlap the next card. Long title, cost, subtitle,
  rules and territory info lines wrap onto more lines, and the card gets taller. Checked with
  Floodplain Delta ("2 slots · 4 housing · Flood Plain, Coastal") and Lumber Camp ("Lumber Camp" + "2 food").
- [ ] AC2: Given an explore choice is pending, when it is shown, then it is a centred modal panel over
  a dimmed board, not a row above the tableau. The tableau keeps its full height behind it, and the
  choice cards can still be clicked to choose.
- [ ] AC3: Given 4 frontier territories and the game at 1280×720, when the board is shown, then the
  tableau area is at least as tall as one territory group (header + one 150px card row + padding).
  Anything that doesn't fit scrolls.
- [ ] AC4: Given the game-over overlay, when it is shown, then its panel has an opaque background and
  no card or text from the board shows through it.
- [ ] AC5: Given the play area, then each section (frontier, tableau, hand) is 20–24px from the
  section before it, and each heading is 6px or less from its own content. Territory group frames
  have 10–12px inner padding and a border you can see (at least 3:1 against the page).
- [ ] AC6: Given the log column, then it sits in a panel with a background and 10px or more inner
  padding, and scrolled text doesn't run under the "Log" heading.

## Out of scope
- Colours, font sizes and button styles (015).
- Reduced motion (016) and keyboard play (017).
- Fanning or overlapping the hand when it has many cards.

## Design notes
- Root cause of AC1: labels in `card_view.gd` don't wrap, so their minimum width is larger than
  `HAND_SIZE.x` / `TABLEAU_SIZE.x`, and `PanelContainer` grows past its slot. Use `AUTOWRAP_WORD_SMART`
  on every label with a fixed width. The header is title + cost: let the title wrap, and let the cost
  keep its natural width.
- AC2: `_choice_panel` moves to an overlay above `_fx`, like `_overlay()`, but must not be covered by
  `z_index = 10` overlays. `_leave_point` for a territory returned to the deck still aims at the
  panel's right edge. Drags are already blocked while a choice is pending.
- The explore heading text gets shorter here: title "Explore", hint "Keep one territory; the other
  goes to the bottom of the territory deck."
- No engine API change.

## Test plan
| AC | Test |
|---|---|
| all | Manual (UI only). Before/after screenshots from the scratch capture script at 1680×1000 and 1280×720. |

## Manual check
Run `godot --path .`. Resize the window to about 1280×720 for the second pass.
- [ ] **AC1:** in the tableau, the Grassland territory card is fully visible next to Capital, with no card
  drawn over another. Get Lumber Camp or Monument into the hand: the title and cost fit inside the card.
- [ ] **AC2:** play Scout. A centred panel shows 2 territories over a dimmed board, and the tableau
  behind it stays the same size. Click one: the panel closes, and the card goes to the frontier.
- [ ] **AC3:** keep exploring until there are 3–4 frontier cards. The tableau still shows a full
  territory group.
- [ ] **AC4:** play to turn 20. The game-over panel is solid, with no card showing behind it.
- [ ] **AC5/AC6:** the headings clearly belong to the section below them. You can tell territory groups
  apart. The log reads as its own panel.

## Log
