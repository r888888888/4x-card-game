---
id: 212
title: The new game screen as a civilization list and a detail pane
type: feature
status: ready
branch: feat/212-civilization-list-and-detail
---

## Goal
Choosing a civilization reads like a master–detail list instead of a row of cards: the civilizations down the left,
the selected one's full story and rules on the right, with Start beside them. The player compares civilizations
without opening a details modal for each.

## Acceptance criteria
- [ ] AC1: Given the new game screen opens with the six civilizations, then the left pane lists one row per
  civilization in config order (`civilization_ids()` unchanged), each a list-row button with its name (and the
  civilization type band colour as a left edge); the preselected one's row is selected (pressed look) and focused.
- [ ] AC2: The right pane shows the selected civilization: its name (Title), its flavor paragraph and quote
  (attributed), its rules as card details give them (`CardDetailsModal.body_bbcode`: discounts, modifiers), and its
  home territory's name and keywords.
- [ ] AC3: When another row is clicked, or the arrows move through the list, then `selected` becomes that civilization
  and the right pane shows it; no modal opens (the click no longer opens card details with Play as, 107).
- [ ] AC4: The seed field and Start sit at the foot of the right pane; Start (or Enter in the seed field) starts a game
  as the selected civilization, as today (`start_requested`); an empty or non-numeric seed behaves as today.
- [ ] AC5: The list and the pane are in one focus loop with the seed field, Start and the header's Back.
- [ ] AC6: With no civilizations offered (a config without them), the list is hidden and the pane says the game
  offers none; Start still works (`selected` "").

## Out of scope
- New civilization content.

## Design notes
- `NewGameScreen.civilization_view(civ_id)` (a CardView) becomes `civilization_row(civ_id)`; its tests move.

## Test plan
| AC | Test |
|---|---|

## Manual check
- [ ] Title → New game: the list and pane read well at 1280×720 in both palettes; a long flavor paragraph wraps
  inside the pane.

## Log
- Specced 2026-10-02 from the notes list.
