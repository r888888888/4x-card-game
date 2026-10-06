---
id: 198
title: Card names in bold
type: feature
status: done
branch: feat/198-bold-card-titles
---

## Goal
A card's name stands out from its rules at a glance, as on the specimen's index cards (`docs/design/mocks/transitions.html`'s
`.mh`: Barlow Semi Condensed 600).

## Acceptance criteria
- [x] AC1: Given any card face (a hand card, a Realm card, a frontier territory, a supply card, a choice overlay's
  card), then its name label uses the `CardTitle` theme variation, whose font is `GameTheme`'s semibold label face
  (`BarlowSemiCondensed-SemiBold.ttf`) at `Tokens.TYPE_BODY`.
- [x] AC2: The rest of the face (type line, rules, cost figures, info line) keeps its current font.
- [x] AC3: Card details (`CardDetailsModal`) and the territory view's box title are unchanged (they already use the
  Title variation).

## Out of scope
- Other changes to the card face.

## Design notes
- New `GameTheme` variation `CardTitle` (a repeated text look is a variation, not an override). `CardFace` sets
  `theme_type_variation` on the title label instead of a font override.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_card_faces::test_the_theme_has_a_semibold_card_title_variation`, `test_every_card_face_names_its_card_in_the_card_title_variation` (hand, tableau, Realm, frontier, event faces) |
| AC2 | `test_card_faces::test_the_rest_of_a_card_face_keeps_its_font` (a guard: passes before and after) |
| AC3 | Existing: `test_type_tokens::test_a_title_keeps_its_case` and the details/territory view tests (no change) |

## Manual check
- [ ] Seed 5: hand and Realm names read bold in Night and Day; long names ("Lumber Camp") still fit beside the cost.

## Log
- Specced 2026-10-02 from the notes list.
- 2026-10-02: `GameTheme`'s `CardTitle` variation; `CardFace.title_label` builds every face's name with it (hand and tableau
  faces, board faces), so the details modal's card, the supply and the choice overlays follow.
