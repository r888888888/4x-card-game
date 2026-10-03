---
id: 215
title: Flavor text and quotes for techs and events
type: feature
status: red-review
branch: feat/215-tech-and-event-flavor
---

## Goal
Techs and events read like history, not just rules: every tech carries a one-line Civilization-style quote
(a real, attributed quotation) and a short flavor line, and every event a short flavor line. Today only
civilizations may set `flavor` and `quote` (107).

## Acceptance criteria
- [ ] AC1: Given a `TEST_CARDS` tech with `"flavor": "Fire, tamed."` and `"quote": {"text": "Knowledge is power.",
  "by": "Francis Bacon"}`, when the cards load, then there are no errors or warnings, and `def_details(id)` returns
  `flavor` "Fire, tamed." and `quote` `{"text": "Knowledge is power.", "by": "Francis Bacon"}`.
- [ ] AC2: Given a `TEST_CARDS` event with `"flavor": "The sky burned."`, when the cards load, then there are no
  errors or warnings, and both `def_details(id)` and `card_details(uid)` of the drawn event return that `flavor`.
- [ ] AC3: Given an event with `"quote": {...}`, when the cards load, then it warns "'quote' only applies to
  civilizations (ignored)" (the existing message names the field's first type; quotes are for civilizations and
  techs only) and its details' `quote` is `{}`.
- [ ] AC4: Given a tech or event whose `flavor` is `3` or `""`, or a tech whose `quote` lacks `by`, when the cards
  load, then the loader reports the same errors as for a civilization (107), naming the card.
- [ ] AC5: Given a building with `flavor`, when the cards load, then it warns that `flavor` doesn't apply to
  buildings (ignored), as before.
- [ ] AC6 (content): in `data/cards.json` every tech has a `flavor` and a `quote`, and every event has a `flavor`
  (`test_content.gd` invariant).
- [ ] AC7: Given a tech or event with a flavor, when its card face is built (`CardFace.build` or `build_board`),
  then the face shows no flavor or quote line: its lines are the same as for the card without them. Flavor appears
  only in the details window.

## Out of scope
- Flavor on actions, buildings, territories, cities or governments.
- Quotes on events.
- Flavor or quotes on any card face (hand, board, research row, the drawn-event modal's card) or in the tech tree
  rows: the details window is the only place they show.

## Design notes
- Data: `TYPE_FIELDS.flavor` becomes `[CIVILIZATION, TECH, EVENT]`, `TYPE_FIELDS.quote` becomes
  `[CIVILIZATION, TECH]`. `_parse_flavor` is unchanged; update the `CardDef` field comments.
- `card_details` / `def_details` already return `flavor` and `quote` for every card, and the details modal already
  shows them first, so techs (opened from the tech tree) and events (opened from the board) need no UI change there.
- Content: one flavor sentence per tech and event (≤ ~25 words, present the idea historically, no rules talk) and
  one short real quotation per tech with its source, Civilization-style (e.g. Writing: a line on the written word).
  Quotes must be real and correctly attributed; prefer ancient or public-domain sources.
- PLAN.md: extend the Flavor (107) paragraph.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_tech_event_flavor::test_a_tech_may_have_flavor_and_a_quote` |
| AC2 | `test_tech_event_flavor::test_an_event_may_have_flavor` |
| AC3 | `test_tech_event_flavor::test_a_quote_on_an_event_is_ignored_with_a_warning` (already passes: guards the rule) |
| AC4 | `test_tech_event_flavor::test_tech_and_event_flavor_validation` |
| AC5 | `test_tech_event_flavor::test_flavor_on_a_building_is_still_ignored_with_a_warning` (already passes: guards the rule) |
| AC6 | `test_content::test_every_tech_has_flavor_and_a_quote_and_every_event_flavor` |
| AC7 | `test_tech_event_flavor::test_a_tech_face_shows_no_flavor_or_quote`, `test_an_event_face_shows_no_flavor` |

## Manual check
- [ ] Open a few techs from the tech tree: italic flavor, then the quote and its source, then the rules.
- [ ] Open an event's details from the board: italic flavor, then the rules.
- [ ] Tech and event card faces (hand, board, drawn-event modal) look exactly as before: no flavor.
- [ ] Read through all 19 tech quotes and 19 event lines for tone, accuracy of attribution and length.

## Log
