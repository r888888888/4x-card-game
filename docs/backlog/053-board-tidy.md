---
id: 053
title: Tidy the board — Realm above Frontier, Buy Cards, Knowledge wording, seed in the menu
type: feature
status: ready
branch: feat/053-board-tidy
---

## Goal
Make the main screen quieter and more thematic (TODO 1–5, 8). The realm (today "Tableau") is what you look at most,
so it goes on top. Explanations move out of headings into tooltips. The seed leaves the top bar. The labels use game
words: Realm, Buy Cards, Knowledge. UI and one card name only; no rule changes.

## Acceptance criteria
<!-- Checked by the UI smoke test (045) where possible; the rest under Manual check. -->
- [ ] AC1 (order): From top to bottom, the play area's sections are Realm, Frontier, Known (researched techs), Hand.
  The smoke test finds each heading and checks that their y positions increase in that order (the Frontier and Known
  sections are shown for the check).
- [ ] AC2 (Realm): The section that was "Tableau" is headed "Realm". The hand hint says "drag a card into the realm".
  No visible UI text says "tableau". Code keeps the zone id `tableau`.
- [ ] AC3 (Frontier): The Frontier heading reads exactly "Frontier". The old explanation ("discovered, not yet settled")
  is the heading's tooltip.
- [ ] AC4 (seed): The top bar has no seed label. The menu's seed field shows the current game's seed when it opens
  (as today), and the game-over overlay still shows "Seed: N" (smoke test unchanged).
- [ ] AC5 (Buy Cards): The supply button reads "Buy Cards (S)". The screen it opens is still titled "Supply", and S
  still opens and closes it.
- [ ] AC6 (Knowledge): The research choice panel is titled "Knowledge". The researched row is headed "Known". The card
  `research` is named "Insight" in `data/cards.json` (its id and the `research` op stay). The real data still loads
  with no warnings.

## Out of scope
- Renaming code ids (`tableau`, `research`, `research_deck`, `researched`, …) or the `research` op.
- The "Techs: deck N · era N" label (replaced by the tech tree modal, 059).
- Any layout change beyond the section order.

## Design notes
- Build after 052 (split `ui/main.gd`). Each change then lands in one component.
- Check `engine/` for player-facing strings that say "tableau" or "Research" (errors and log lines shown in the UI), and
  reword them to "realm" and "Insight" or "knowledge". Tests assert state, not log text. Update any test that asserts
  an error string, and name it at the red checkpoint.
- The TEST_CARDS fixture `study` keeps the name "Research". It's a fixture, not shipped data.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_ui_smoke::test_…` |

## Manual check
- [ ] Realm on top, Frontier under it, then Known, then Hand. Nothing overlaps at the default window size.
- [ ] Hovering "Frontier" shows the explanation.
- [ ] The top bar has no seed. Esc shows it in the menu.
- [ ] "Buy Cards (S)" opens the Supply screen.
- [ ] The Insight card, the Knowledge panel and the Known row read naturally in a full game.

## Log
