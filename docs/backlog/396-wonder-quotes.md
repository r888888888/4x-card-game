---
id: 396
title: Quotes for wonders
type: feature
status: in-progress
branch: feat/396-wonder-quotes
---

## Goal
Wonders (Pyramids, Great Library, …) are the grandest cards in the game, yet their details carry only a flavor line
(352), while every tech, government and civilization also carries a quote. After this, a building may set a `quote`
and every wonder in the real data has one, shown in its details window under the flavor, as for a tech.

## Acceptance criteria
- [ ] AC1: Given a `TEST_CARDS` building with `"quote": {"text": "Look on my works.", "by": "Shelley"}`, when the
  cards load, then there are no errors or warnings, its def's `quote_text` / `quote_by` are those strings, and both
  `def_details(id)` and `card_details(uid)` of that building on a territory return
  `quote == {"text": "Look on my works.", "by": "Shelley"}`.
- [ ] AC2: Given a building whose `quote` is `"Look on my works."` (not an object), `{"text": "Look on my works."}`
  (no `by`) or `{"text": "", "by": "Shelley"}`, when the cards load, then the loader reports
  "'quote' must be {\"text\": …, \"by\": …} with non-empty strings", naming the card (as for a civilization, 107).
- [ ] AC3: Given a building with no `quote`, when the cards load, then its details' `quote` is `{}` (quotes stay
  optional on buildings).
- [ ] AC4: Given a territory, city or unit with a `quote`, when the cards load, then the loader still warns that
  `quote` doesn't apply (ignored), and its details' `quote` is `{}`.
- [ ] AC5: Given a building with a quote, when its card face is built (`CardView.setup`, in hand and not), then the
  face's lines are the same as for the card without it: the quote shows only in the details window.
- [ ] AC6 (content): in `data/cards.json` every building tagged `wonder` has a quote with its source
  (`test_content.gd` invariant).

## Out of scope
- Quotes on non-wonder buildings in the real data (the loader allows them; none are written here).
- Showing the quote in the Build modal (354 shows the flavor there) or on any card face.
- Quotes on territories, cities or units.

## Design notes
- Data: `DataLoader.TYPE_FIELDS.quote` gains `CardDef.BUILDING`. The rule stays type-based: the engine has no notion
  of the `wonder` tag (it is content), so any building may take a quote and the content invariant asks it of wonders.
- Update the `CardDef.quote_text` / `quote_by` comments and `_parse_flavor`'s doc comment.
- Existing tests that change: `test_tech_event_flavor::test_a_quote_on_a_building_is_ignored_with_a_warning` (352
  AC3) states the old rule; it is replaced by AC1's test, and AC4's warning case uses a territory instead.
- `card_details` / `def_details` already return `quote` and the details modal shows it after the flavor, so no UI change.
- Content: 9 wonders today. Choose each quote by the style guide's §18.5; prefer an ancient source on the monument
  itself (Herodotus on the Pyramids, Strabo or Diodorus on Babylon, …) or a well-known later line about it; no quote
  already used on another card.
- PLAN.md: the Flavor (107) paragraph says a building may not carry a quote; update it (and note that events may,
  253, which it also gets wrong).
- Test rows go in `docs/testing-index.md`.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_tech_event_flavor::test_a_building_may_have_a_quote` |
| AC2 | `test_tech_event_flavor::test_building_quote_validation` |
| AC3 | `test_tech_event_flavor::test_a_building_without_a_quote_has_none` (already passes: guards the rule) |
| AC4 | `test_tech_event_flavor::test_a_quote_on_a_territory_city_or_unit_is_still_ignored_with_a_warning` (already passes) |
| AC5 | `test_tech_event_flavor::test_a_building_face_shows_no_quote` |
| AC6 | `test_content::test_every_wonder_has_a_quote` |

## Manual check
- [ ] Open each wonder's details from hand and from a territory: italic flavor, then the quote and its source, then
  the rules.
- [ ] Wonder faces in hand, on the board, in the territory view and in the Build modal look as before.
- [ ] Read through all nine quotes for accuracy (wording, attribution, translator) and fit with the flavor line.

## Log
