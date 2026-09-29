---
id: 046
title: Table-driven loader validation tests
type: feature
status: draft
branch: feat/046-table-driven-loader-tests
---

## Goal
About 90 loader validation tests, spread over 12 files, each check one bad field with the same few lines.
Grouping them into case tables per config block or card field makes the loader refactor (047) cheaper to guard,
and adding a field means adding a row, not a test.

## Acceptance criteria
- [ ] AC1: For each of `supply`, `era_unlocks`, `population`, `territory_resources`, `research_deck`,
  `territory_deck`, `hand_limit`, territory card fields, tech card fields and `prereq`, the validation cases are
  one test that loops over rows `[label, input, expected message fragment]` and asserts each row with its label in
  the failure message.
- [ ] AC2: Every error and warning fragment asserted before this item is still asserted; the Log lists the
  fragment count before and after (they must be equal).
- [ ] AC3: The tests stay in their feature files (no single giant loader test file). Tests of valid input
  loading and normalizing stay as separate named tests.
- [ ] AC4: The loader validation test count drops from about 90 to 35 or fewer, and the suite is green.

## Out of scope
- Changing any loader message or rule.

## Design notes
- Uses the `config_errors` / `card_errors` helpers from 041.
- A table row that fails reports `file::test: <label>: …` so a failure is still easy to find.

## Test plan
| AC | Test |
|---|---|

## Log
