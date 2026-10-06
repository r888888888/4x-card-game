---
id: 329
title: Modifier text prints a stray "s" for nouns with no plural
type: bug
status: red-review
branch: fix/329-modifier-plural-text
---

## Reproduction
- Seed: any (card text, no randomness)
- Steps:
  1. Load the real data and read Monument's `rules_text` (modifiers `{"unrest_limit": 2}`).
- Expected: "Unrest limit +2"
- Actual: "Unrest limit +2s". `CardDef.MODIFIER_TEXT` writes "%.0s" for the plural argument of keys whose noun
  has no plural (housing, unrest_limit, insight_per_gain, administers), meaning to drop it; Godot's `%` ignores the
  precision and prints the "s". Amount ±1 hides it, since the plural argument is then "".

## Acceptance criteria
- [ ] AC1: Given a fixture building with modifiers `{"unrest_limit": 2}`, its `rules_text` is "Unrest limit +2";
  with `{"unrest_limit": -2}`, "Unrest limit −2".
- [ ] AC2: Given a fixture building with modifiers `{"housing": 2}`, its `rules_text` is
  "Every territory houses 2 more pop"; with `{"housing": -2}`, "Every territory houses 2 less pop".
- [ ] AC3: Given fixture buildings with `{"insight_per_gain": 2}` and `{"administers": 2}`, their `rules_text` is
  "Each insight gain +2" and "Administration cap +2".
- [ ] AC4: Keys whose noun has a plural still take it: `{"actions": 2}` reads "+2 actions each turn",
  `{"renewal": 2}` "Renewal trashes 2 more cards", and `{"actions": 1}` "+1 action each turn".

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_card_text::test_bug_329_unrest_limit_line_has_no_plural` |
| AC2 | `test_card_text::test_bug_329_housing_line_has_no_plural` |
| AC3 | `test_card_text::test_bug_329_insight_and_administration_lines_have_no_plural` |
| AC4 | `test_card_text::test_bug_329_countable_modifiers_keep_their_plural` (passes already: a regression guard) |

## Root cause
<!-- Filled in by Claude after the fix: what was wrong and why the tests didn't catch it. -->

## Manual check
- Monument's card face and tooltip read "Unrest limit +2" (and "Unrest limit +2 while active" never applies: it's a
  building).

## Log
- 2026-10-06: spec'd from a user report.
