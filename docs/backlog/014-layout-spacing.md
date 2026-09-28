---
id: 014
title: Fix card overlap and section spacing; explore choice as an overlay
type: feature
status: review
branch: feat/014-layout-spacing
---

## Goal
Every card and section can be read in full at any time. The design audit (2026-09-28)
found that cards draw over their neighbours, that the tableau shrinks to a thin strip while an explore
choice is open, and that the game-over text sits on top of the board with no background. Sections also
have too little space between them to read as separate areas.

## Acceptance criteria
<!-- UI-only item: each criterion is checked in the running game (see Manual check). No engine change. -->
- [x] AC1: Given any card in any zone (hand, tableau, frontier, choice), when it is laid out, then
  it is exactly its slot width (215px) and does not overlap the next card. Long title, cost, subtitle,
  rules and territory info lines wrap onto more lines, and the card gets taller. Checked with
  Floodplain Delta ("2 slots · 4 housing · Flood Plain, Coastal") and Lumber Camp ("Lumber Camp" + "2 food").
- [x] AC2: Given an explore choice is pending, when it is shown, then it is a centred modal panel over
  a dimmed board, not a row above the tableau. The tableau keeps its full height behind it, and the
  choice cards can still be clicked to choose.
- [x] AC3: Given 4 frontier territories and the game at 1280×720, when the board is shown, then the
  tableau area is at least as tall as one territory group (header + one 150px card row + padding).
  Anything that doesn't fit scrolls.
- [x] AC4: Given the game-over overlay, when it is shown, then its panel has an opaque background and
  no card or text from the board shows through it.
- [x] AC5: Given the play area, then each section (frontier, tableau, hand) is 20–24px from the
  section before it, and each heading is 6px or less from its own content. Territory group frames
  have 10–12px inner padding and a border you can see (at least 3:1 against the page).
- [x] AC6: Given the log column, then it sits in a panel with a background and 10px or more inner
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
Run `godot --path .`, type seed `4242`, and press Restart. Play cards and grow each turn, and play Scout
whenever you have it (by turn 7 there are about 3 frontier territories). Then repeat with the window
at about 1280×720.
- [ ] **AC1:** Grassland is fully visible next to Capital, and its info wraps to "2 slots · 4 housing ·
  Grassland". Nothing in any row is drawn over its neighbour. When Lumber Camp is in the hand, its title
  wraps to two lines, and "2 food" stays inside the card.
- [ ] **AC2:** play Scout. A centred "Explore" panel with 2 territories appears over a dimmed board, and the
  tableau behind it doesn't move or shrink. Click one: the panel closes, and the card flies to the frontier.
- [ ] **AC3:** with 3–4 frontier cards, the tableau still shows a whole territory group. It scrolls if the
  group is taller. The hand and End turn stay inside the window.
- [ ] **AC4:** play to turn 20. The game-over panel is solid, with no card showing through it.
- [ ] **AC5:** Frontier, Tableau and Hand are clearly separate, each heading sits on its own content, and
  the territory group has a purple frame with padding around its cards.
- [ ] **AC6:** the log is a darker panel with padding, and scrolled lines don't run under "Log".
- [ ] **Targeting:** play Settler with 2 frontier territories. Hovering a lit frontier card turns its border
  white with a shadow, but it doesn't lift (only hand cards lift now), so its top edge is never clipped.

## Log
- Root cause of the overlap: card labels didn't wrap, so a long line made the `PanelContainer` wider than
  its slot. `CardView._label` now wraps by default, and only the cost keeps its natural width.
- Territory cards had an empty rules label that still took a line. It's skipped when the text is empty,
  and the territory info sits at the bottom of the card instead.
- Vertical budget at 1680×1000 with 3-line frontier cards: frontier 168, tableau 265 (minimum 250), hand
  340. It fits exactly, with the hand ending at the bottom margin (982). The frontier row scrolls
  sideways if it gets wider than the play area.
- The frontier now sits in a ScrollContainer, so a lifted target card would be clipped (tableau targets
  already were). Hover lift and scale are for hand cards only now. Pickable cards keep the white border
  and shadow.
- Group frame border uses the territory colour (3.9:1 against the page). It turns gold (3px) when lit
  as a target.
- UI only; test count unchanged (155).
