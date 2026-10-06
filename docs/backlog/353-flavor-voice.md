---
id: 353
title: Flavor text in a postwar American literary voice
type: feature
status: red-review
branch: feat/353-flavor-voice
---

## Goal
Card flavor reads like a short story, not a museum label: every flavor line is rewritten in the voice of postwar
American fiction (Nabokov, Chandler, Yates, Cheever, O'Hara), short enough to read in one glance, and the style guide
says how to write the next one so new cards match.

## Acceptance criteria
- [ ] AC1 (content): in `data/cards.json`, every card's `flavor` other than a civilization's is at most 150
  characters, and a civilization's (a paragraph on the civilization picker, 107) at most 200
  (`test_content.gd` invariant; the guide's targets are ~120 and ~170).
- [ ] AC2 (content): every card that had a `flavor` still has one (the 107/215/351/352 invariants stay green).

## Out of scope
- Quotes (`quote` {text, by}): they are real sayings with real sources, unchanged.
- Card names, rules text, which cards carry flavor, and where flavor shows.
- Balance.

## Design notes
- Starts from `spike/flavor-prose` (55855aa), which rewrote all 143 lines at ~158 characters on average (main: ~102).
  The spike's finding: the voice works, but the wisecrack ending tires when cards are read in a row, image endings
  wear better, disasters read glib, and the period voice leans on "men" and "himself". So this item:
  - targets ~120 characters (civilizations ~170);
  - ends about one line in three on a wry turn (Chandler, O'Hara) and the rest on an image or a plain fact
    (Nabokov, Cheever, Yates);
  - keeps disasters and death (Plague, Pestilence, Famine, Drought, Storm at Sea, Library Burns, Granary Fire)
    plain and grave, without a joke;
  - says "people", "they" or a role (farmers, scribes, the smith) unless a real person is meant;
  - keeps every historical fact the old line taught (civilizations and techs above all), British spelling, and
    nothing that names a rule or a number of the game.
- Style guide: a new §18 "Voice: flavor text" in `docs/design/mcm-style-guide.md` with those rules and examples;
  `tokens.md`'s topic list and `index.html`'s guide card mention it. CLAUDE.md's UI design section points to it.
- No data format change, no engine change.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_content::test_flavor_lines_are_short` |
| AC2 | `test_content::test_every_building_has_flavor`, `test_every_action_has_flavor`, `test_every_tech_has_flavor_and_a_quote_and_every_event_flavor`, `test_every_listed_civilization_has_flavor_and_a_quote` (existing) |

## Manual check
- [ ] Read the lines by type, in a row: about a third end on a turn, the rest on an image; no disaster jokes.
- [ ] Facts kept: spot-check the civilizations and ten techs against main's lines.
- [ ] Open a few details windows (a wonder, an event as it's drawn, a tech, a civilization on the picker): the
  flavor fits without crowding the rules.

## Log
