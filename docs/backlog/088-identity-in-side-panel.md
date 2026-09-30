---
id: 088
title: Civilization and government as side-panel lines, not card rows
type: feature
status: ready
branch: feat/088-identity-in-side-panel
---

## Goal
The civilization (062) and the government (065) each take a heading and a row of one compact card in the play area,
about 140px each, between Known and Events. That space is better spent on the Realm, the hand and the events. Show
each as one line in the side panel instead, with its rules on hover and its details on click.

## Acceptance criteria
<!-- UI tests run the real main.tscn (real data: Children of the River, Chiefdom at the start). -->
- [ ] AC1 (rows gone): Given the main scene after `start_game(1)`, then `main.section_headings()` has no
  "Civilization" or "Government" heading, and no card view shows the civilization or the government (neither uid is
  in `main.views`).
- [ ] AC2 (lines): Given the same game, then the side panel shows two lines, in this order, above the Knowledge
  button: "Civilization: Children of the River" and "Government: Chiefdom". Test hook: `main.identity_lines()`
  returns `[{text, tooltip}, …]` for the visible lines, top to bottom.
- [ ] AC3 (tooltip): each line's tooltip is its card's `rules_tooltip`: the civilization's contains
  "Each upkeep: +1 food". A card with no rules text (Chiefdom) has the tooltip "No bonus.".
- [ ] AC4 (details): Given the same game, when the civilization line is pressed, then the details modal shows
  Children of the River (`main.details.shown().name`). Pressing the government line shows Chiefdom's details.
- [ ] AC5 (government changes): Given a Kingship in hand, when it is played (`try_play` or `play_card` followed by the
  board's refresh), then the government line reads "Government: Kingship", its tooltip is Kingship's `rules_tooltip`,
  and Kingship's uid is not in `main.views` once the play has finished.
- [ ] AC6 (none): Given main running fixture data with no `starting.civilization` and no `starting.government`, then
  `main.identity_lines()` is empty (both lines hidden).

## Out of scope
- Any engine or data change: `civilization()`, `government()` and the card defs already give what the lines show.
- Keyboard focus on the lines beyond ordinary button focus (Tab), and a `I`-key shortcut for them.
- The start screen's civilization cards (063/064), the menu's "Playing as …" and the game-over text.

## Design notes
- UI only. `SidePanel` gets the two lines (flat buttons, like the Knowledge button's style but one line each) and a
  `refresh(e)` that reads `e.civilization()` / `e.government()`. Pressing one calls `details.open_def(card_id)`.
- `main.gd` drops `_row_sections.civilization` and `.government`, so the rows, their views and their headings go.
  A played government's view then leaves the board like any card that isn't shown: make it fly to the government
  line (`_leave_point`) instead of the discard counter.
- Long names: the line clips with an ellipsis at the panel's 360px; the tooltip still names the card in full.
- No engine query needed: the text is the card's name and `rules_tooltip`, which the UI already reads elsewhere.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_identity_lines::test_…` |

## Manual check
- [ ] At 1920×1080 the play area no longer has Civilization or Government rows, and the Realm and hand have more room.
- [ ] The two lines sit above Knowledge and don't squeeze the log noticeably; a long civilization name ends in "…".
- [ ] Hover shows the full rules; clicking opens the same details modal as before.
- [ ] Playing Kingship flies the card to the government line, which then reads "Government: Kingship".

## Log
