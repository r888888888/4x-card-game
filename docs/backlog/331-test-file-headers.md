---
id: 331
title: Each test file's header says what it covers; docs/testing.md keeps one line per file
type: chore
status: in-progress
branch: feat/331-test-headers
---

## Goal
`docs/testing.md` is 68 KB, most of it a table whose rows repeat (and drift from) each test file's own `##` header.
Every item edits it, and the `tdd` skill reads all of it at the start of every item. The file's header becomes the one
place that says what a test file covers; `docs/testing.md` keeps how to run and write tests, the helpers, and a short
index.

## Acceptance criteria
- [ ] AC1: Given every `tests/test_*.gd` and `tests/balance/test_*.gd`, when the suite runs, then a test fails naming each
  file whose first lines after `extends` aren't a `##` header comment (at least one line saying what it covers).
- [ ] AC2: Given `docs/testing.md`'s file table, when the suite runs, then a test fails naming any test file with no row,
  any row for a file that doesn't exist, and any row longer than 160 characters.
- [ ] AC3: `docs/testing.md` is under 25 KB.
- [ ] AC4: No test changes behaviour: every test passes, and the test count is unchanged.

## Out of scope
- Rewriting tests or moving them between files.

## Design notes
- Move what a long row says that its file's header lacks (backlog ids, fixtures, hooks used) into the header, then cut
  the row to a phrase (e.g. "`test_raids.gd` | Barbarian raids (162, 257, 271)").
- AC2 replaces `scan.sh`'s "Test files missing from docs/testing.md" section.
- Update the `tdd` skill: step 1 reads `docs/testing.md`'s conventions and the target file's header (not the whole
  table); a new test file gets a header and a one-line row. Update the `spec` skill's and `development-process.md`'s
  mentions to match.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_docs::test_a_test_file_without_a_header_after_extends_is_named`, `test_every_test_file_opens_with_a_header` |
| AC2 | `test_docs::test_table_problems_name_missing_rows_rows_for_no_file_and_long_rows`, `test_testing_md_indexes_every_test_file_in_one_short_row` |
| AC3 | `test_docs::test_testing_md_is_under_25_kb` |
| AC4 | The full suite; the count rises only by these 5 tests |

## Log
- 2026-10-06: specced from the project review; the user chose headers as the source of truth.
