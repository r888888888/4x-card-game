---
id: 396
title: Quotes for wonders
type: feature
status: done
branch: feat/396-wonder-quotes
---

## Goal
Wonders (Pyramids, Great Library, …) are the grandest cards in the game, yet their details carry only a flavor line
(352), while every tech, government and civilization also carries a quote. After this, a building may set a `quote`
and every wonder in the real data has one, shown in its details window under the flavor, as for a tech.

## Acceptance criteria
- [x] AC1: Given a `TEST_CARDS` building with `"quote": {"text": "Look on my works.", "by": "Shelley"}`, when the
  cards load, then there are no errors or warnings, its def's `quote_text` / `quote_by` are those strings, and both
  `def_details(id)` and `card_details(uid)` of that building on a territory return
  `quote == {"text": "Look on my works.", "by": "Shelley"}`.
- [x] AC2: Given a building whose `quote` is `"Look on my works."` (not an object), `{"text": "Look on my works."}`
  (no `by`) or `{"text": "", "by": "Shelley"}`, when the cards load, then the loader reports
  "'quote' must be {\"text\": …, \"by\": …} with non-empty strings", naming the card (as for a civilization, 107).
- [x] AC3: Given a building with no `quote`, when the cards load, then its details' `quote` is `{}` (quotes stay
  optional on buildings).
- [x] AC4: Given a territory, city or unit with a `quote`, when the cards load, then the loader still warns that
  `quote` doesn't apply (ignored), and its details' `quote` is `{}`.
- [x] AC5: Given a building with a quote, when its card face is built (`CardView.setup`, in hand and not), then the
  face's lines are the same as for the card without it: the quote shows only in the details window.
- [x] AC6 (content): in `data/cards.json` every building tagged `wonder` has a quote with its source
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
- [ ] Read through all nine quotes for tone and fit with the flavor line (sources in the Log).

## Log
- 2026-10-07: AC3 and AC4 held before the change; their tests guard the rules. 352's
  `test_a_quote_on_a_building_is_ignored_with_a_warning` was replaced (this item reverses that rule).
- No quote length cap exists in the suite, so AC6 dropped its "existing length cap" clause.
- Quotes, chosen by §18.5 (three modern: Thoreau, Kipling, Kafka) and checked against these texts:
  - Pyramids: Thoreau, Walden ch. 3 "Reading" (Project Gutenberg #205); cut at "booby" with an ellipsis.
  - Oracle of Delphi: Plato, Apology 21b, Jowett (Gutenberg #1656). Plato's second quote (Theaetetus, on a tech).
  - Walls of Uruk: Thucydides 7.77, Crawley (Gutenberg #7142).
  - Great Ziggurat: Genesis 11:4 KJV (Gutenberg #10); cut after "a name" with an ellipsis. The ziggurat of Babylon
    is the usual reading of Babel; the 10th Bible quote in the data.
  - Hanging Gardens: Berossus in Josephus, Against Apion 1.19, Whiston (Gutenberg #2849).
  - Great Library: Athenaeus 3.72a, Callimachus "used to say that a big book is equal (ἴσον) to a big evil": the
    line is Athenaeus's report, translated literally, so no translator is named. Callimachus compiled the Library's
    catalogue (the Pinakes); "librarian" is avoided since his headship is doubtful.
  - Great Harbor of Tyre: Kipling, Recessional, st. 3 (RPO, from Rudyard Kipling's Verse: Definitive Edition, 1940);
    the two verse lines run on, "Is" lowercased, as the other verse quotes do.
  - Lighthouse of Pharos: Lucian, How to Write History 62, Francklin (Gutenberg #10430, Trips to the Moon); the
    inscription Sostratus hid under the plaster bearing the king's name.
  - Royal Road: Kafka, An Imperial Message, last sentence, Willa and Edwin Muir (Babel Web Anthology). Kafka's second
    quote (Bureaucracy, a tech).
