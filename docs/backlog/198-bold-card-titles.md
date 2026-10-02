---
id: 198
title: Card names in bold
type: feature
status: ready
branch: feat/198-bold-card-titles
---

## Goal
A card's name stands out from its rules at a glance, as on the specimen's index cards (`docs/design/transitions.html`'s
`.mh`: Barlow Semi Condensed 600).

## Acceptance criteria
- [ ] AC1: Given any card face (a hand card, a Realm card, a frontier territory, a supply card, a choice overlay's
  card), then its name label uses the `CardTitle` theme variation, whose font is `GameTheme`'s semibold label face
  (`BarlowSemiCondensed-SemiBold.ttf`) at `Tokens.TYPE_BODY`.
- [ ] AC2: The rest of the face (type line, rules, cost figures, info line) keeps its current font.
- [ ] AC3: Card details (`CardDetailsModal`) and the territory view's box title are unchanged (they already use the
  Title variation).

## Out of scope
- Other changes to the card face.

## Design notes
- New `GameTheme` variation `CardTitle` (a repeated text look is a variation, not an override). `CardFace` sets
  `theme_type_variation` on the title label instead of a font override.

## Test plan
| AC | Test |
|---|---|

## Manual check
- [ ] Seed 5: hand and Realm names read bold in Night and Day; long names ("Lumber Camp") still fit beside the cost.

## Log
- Specced 2026-10-02 from the notes list.
