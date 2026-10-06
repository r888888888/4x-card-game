---
id: 353
title: Flavor text in a postwar American literary voice
type: feature
status: in-progress
branch: feat/353-flavor-voice
---

## Goal
Card flavor reads like a short story, not a museum label: every flavor line is rewritten in the voice of postwar
fiction (Calvino, O'Hara, Cheever, Highsmith, Bradbury, Didion), short enough to read in one glance; the governments
get the flavor and quote the civilizations have; and the style guide says how to write the next one so new cards
match.

## Acceptance criteria
- [ ] AC1 (content): in `data/cards.json`, every card's `flavor` other than a civilization's is at most 150
  characters, and a civilization's (a paragraph on the civilization picker, 107) at most 200
  (`test_content.gd` invariant; the guide's targets are ~120 and ~170).
- [ ] AC2 (content): every card that had a `flavor` still has one (the 107/215/351/352 invariants stay green).
- [ ] AC3 (content): in `data/cards.json` every government (Chiefdom, Kingship, Theocracy) has a `flavor` and a
  `quote` with its source (`test_content.gd` invariant, by card type; the loader already accepts both, 205).

## Out of scope
- Existing quotes (`quote` {text, by}): they are real sayings with real sources, unchanged.
- Card names, rules text, which cards carry flavor, and where flavor shows.
- Balance.

## Design notes
- Two spikes tried two voices. `spike/flavor-prose` (55855aa, 7aec761: Nabokov, Chandler, Yates, Cheever, O'Hara, past
  tense) ran ~158 characters a line (main: ~102); the wisecrack ending tired when cards were read in a row, image
  endings wore better, disasters read glib, and the period voice leaned on "men" and "himself".
  `spike/flavor-voice-b` (5439cbc, 80183f9: Calvino, O'Hara, Cheever, Highsmith, Bradbury, Didion, present tense)
  applied those lessons and was chosen: this item takes its text. Its rules, which the guide's §18 records:
  - present tense: a card happens now, which suits the event pop-up;
  - ~120 characters a line (civilizations ~170);
  - about one line in three ends on a wry turn, the rest on an image or a plain fact;
  - disasters and death (Plague, Pestilence, Famine, Drought, Storm at Sea, Library Burns, Granary Fire) stay plain;
  - "people", "they" or a role (farmers, scribes, the smith) unless a real person or group is meant;
  - every historical fact the old line taught is kept (civilizations and techs above all), British spelling, and
    nothing names a rule or a number of the game.
- Governments' quotes: Kingship, the Sumerian King List's opening; Theocracy, Psalm 127:1 (KJV); Chiefdom, Tacitus,
  Germania 7.
- Style guide: a new §18 "Voice: flavor text" in `docs/design/mcm-style-guide.md`; `tokens.md`'s topic list, the
  guide's opening and `index.html`'s guide card mention it; CLAUDE.md's UI design section points to it.
- No data format change, no engine change.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_content::test_flavor_lines_are_short` |
| AC2 | `test_content::test_every_building_has_flavor`, `test_every_action_has_flavor`, `test_every_tech_has_flavor_and_a_quote_and_every_event_flavor`, `test_every_listed_civilization_has_flavor_and_a_quote` (existing) |
| AC3 | `test_content::test_every_government_has_flavor_and_a_quote` |

## Manual check
- [ ] Read the lines by type, in a row: about a third end on a turn, the rest on an image; no disaster jokes.
- [ ] Facts kept: spot-check the civilizations and ten techs against main's lines.
- [ ] Open a few details windows (a wonder, an event as it's drawn, a tech, a civilization on the picker, a
  government in the government overlay): the
  flavor fits without crowding the rules.

## Log
- Red checkpoint approved with AC3 added (governments' flavor and quotes) and the second voice chosen over the first.
