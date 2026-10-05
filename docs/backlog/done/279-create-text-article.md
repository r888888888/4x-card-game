---
id: 279
title: Create text says "a" before vowel-initial card names
type: bug
status: done
branch: fix/279-create-text-article
---

## Reproduction
- Seed: none (card text is deterministic)
- Steps:
  1. Look at Mysticism's or Irrigation's (272) rules text.
- Expected: "Add an Oracle of Delphi to your discard", "Add an Irrigation Canals to your discard".
- Actual: "Add a Oracle of Delphi to your discard", "Add a Irrigation Canals to your discard".

`create_effect.gd`'s `describe()` hard-codes "a" for both wordings ("Create a %s", "Add a %s to your %s").

## Acceptance criteria
- [x] AC1: Given a card whose effect is `{"op": "create", "card": "explorer", "zone": "discard"}` (Explorer from TEST_CARDS),
  when its rules text is generated, then it reads "Add an Explorer to your discard".
- [x] AC2: Given a card whose effect is `{"op": "create", "card": "explorer"}` (Explorer from TEST_CARDS, default
  tableau zone), when its rules text is generated, then it reads "Create an Explorer".
- [x] AC3: Given a consonant-initial card (City), the text is unchanged: "Create a City" and, with
  `"zone": "discard"`, "Add a City to your discard".
- [x] AC4: The rule is by first letter, case-insensitive: a name starting with A, E, I, O or U (either case) takes "an",
  anything else takes "a".

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_card_text::test_bug_279_create_uses_an_before_a_vowel` |
| AC2 | `test_card_text::test_bug_279_create_uses_an_before_a_vowel` |
| AC3 | `test_card_text::test_bug_279_create_keeps_a_before_a_consonant` |
| AC4 | `test_card_text::test_bug_279_article_is_by_first_letter_either_case` |

## Design notes
A simple vowel-letter rule, not true pronunciation ("a Unit", "an Hour" edge cases are out of scope; no current card
hits them).

## Root cause
`CreateEffect.describe()` wrote a literal "a" in both phrasings. Text tests only covered City, a consonant name, so
nothing exercised a vowel-initial card. The fix picks the article by first letter (`_article`).

## Manual check
- Mysticism reads "Add an Oracle of Delphi to your discard"; Irrigation reads "Add an Irrigation Canals to your discard".

## Log
- 2026-10-04: specced.
- 2026-10-04: red. AC1 uses Explorer (Omen is in TEST_EVENTS, not TEST_CARDS). AC3 passes already (regression guard).
- 2026-10-04: green (1191 → 1194 tests). A helper first named `test_card` was run as a test by the runner and hung the
  suite; renamed `fixture_card`, added the naming rule to CLAUDE.md's Test conventions, and flagged a runner guard as a
  follow-up.
