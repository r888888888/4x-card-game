---
id: 351
title: Flavor text for action cards
type: feature
status: done
branch: feat/351-action-flavor
---

## Goal
Action cards (Settler, Scout, Barter, …) read like history, not just rules: every action carries a short flavor
line in its details window, like techs and events (215). Actions take no quote. Today only civilizations,
governments, techs and events may set `flavor`.

## Acceptance criteria
- [x] AC1: Given a `TEST_CARDS` action with `"flavor": "They went over the hill."`, when the cards load, then there
  are no errors or warnings, and both `def_details(id)` and `card_details(uid)` of that action in hand return that
  `flavor`.
- [x] AC2: Given an action whose `flavor` is `3` or `""`, when the cards load, then the loader reports
  "'flavor' must be a non-empty string", naming the card (as for a civilization, 107).
- [x] AC3: Given an action with `"quote": {"text": …, "by": …}`, when the cards load, then it warns that `quote`
  doesn't apply (ignored), and its details' `quote` is `{}`.
- [x] AC4: Given an action with a flavor, when its card face is built (`CardFace.build`), then the face's lines are
  the same as for the card without it: flavor shows only in the details window.
- [x] AC5 (content): in `data/cards.json` every action has a `flavor` (`test_content.gd` invariant).

## Out of scope
- Quotes on actions.
- Flavor on buildings, territories, cities or units.
- Flavor on any card face.

## Design notes
- Data: `TYPE_FIELDS.flavor` gains `CardDef.ACTION`; `quote` is unchanged. Update the `CardDef.flavor` comment and
  `_parse_flavor`'s doc comment.
- `card_details` / `def_details` already return `flavor`, and the details modal already shows it first, so no UI
  change.
- Content: one sentence per action (≤ ~25 words), historical in tone, no rules talk, matching the existing
  tech and event lines.
- PLAN.md: extend the Flavor (107) paragraph.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_tech_event_flavor::test_an_action_may_have_flavor` |
| AC2 | `test_tech_event_flavor::test_action_flavor_validation` |
| AC3 | `test_tech_event_flavor::test_a_quote_on_an_action_is_ignored_with_a_warning` (already passes: guards the rule) |
| AC4 | `test_tech_event_flavor::test_an_action_face_shows_no_flavor` |
| AC5 | `test_content::test_every_action_has_flavor` |

## Manual check
- [ ] Open each of the 10 actions' details from the hand: italic flavor, then the rules.
- [ ] Action card faces in hand look exactly as before.
- [ ] Read through the 10 lines for tone and length.

## Log
- 2026-10-06: AC3 held before the change (`quote` already excluded actions); its test guards the rule.
- `docs/testing.md` sits at its 25 KB cap (1 byte under on main), so the test file's row kept its length and cites
  215 only; the file's `##` header names 351. Any future row will need the file trimmed or split.
