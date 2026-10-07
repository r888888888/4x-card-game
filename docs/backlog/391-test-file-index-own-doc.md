---
id: 391
title: Move the test file index out of docs/testing.md into docs/testing-index.md
type: chore
status: ready
branch: feat/391-test-file-index
---

## Goal
`docs/testing.md` sits at its 25 KB cap (`test_docs::test_testing_md_is_under_25_kb`), and its test file index (one row
per `tests/test_*.gd`, 331) is ~14 KB of it and grows by one row with every new test file. So every item that adds a
test file has to shorten unrelated rows to fit (165, 166 and 379 did), and parallel sessions conflict on the rows they
each trimmed. The two halves have different jobs: `docs/testing.md` is the guide the `tdd` skill reads at the start of
every item (how to run and write tests, the helpers), which the cap keeps short; the index is a lookup table that
grows with the suite by design. Splitting along that boundary lets the guide keep its cap and the index grow, with each
file's `##` header staying the source of truth (331).

## Acceptance criteria
- [ ] AC1: Given `docs/testing-index.md`, when the suite runs, then a test fails naming each `tests/test_*.gd` and
  `tests/balance/test_*.gd` with no row there, each row for a file that doesn't exist, and each row over 160
  characters (331's AC2 checks, now on the new file; `DocChecks.table_problems` unchanged).
- [ ] AC2: Given `docs/testing.md`, when the suite runs, then a test fails if it contains any test file index row
  (`| \`tests/…test_x.gd\` | … |`), naming the rows found, so the index can't drift back into the guide.
- [ ] AC3: `docs/testing.md` stays under 25 KB (the existing check, unchanged), and after the move it is under 15 KB,
  leaving room for the guide to grow; `docs/testing.md` links to `docs/testing-index.md` where the table was.
- [ ] AC4: `docs/testing-index.md` has no size check; adding a test file means adding one row (≤ 160 characters) to it
  and touching no other row.
- [ ] AC5: The header check is unchanged: every test file still opens with a `##` header
  (`test_every_test_file_opens_with_a_header` passes untouched), and every path `docs/testing-index.md` names exists
  (it is under `docs/`, so `DocChecks.docs_to_check()` already includes it; assert it is in the list).
- [ ] AC6: No test changes behaviour: every test passes, and the count rises only by the new checks.

## Out of scope
- Generating the index from the headers (see Design notes).
- Rewording rows, moving the helper tables (`tests/lib/*` rows and the `test_case.gd` helper table stay in
  `docs/testing.md`), or changing the 160-character row limit.
- Raising or lowering the 25 KB cap.

## Design notes
- Move lines 47–252 (the "index below…" sentence's table) verbatim to `docs/testing-index.md`, under a one-paragraph
  intro: each file's `##` header is the source; one row per file, ≤ 160 characters, sorted by path; "UI" marks files
  that run the real `main.tscn`. `docs/testing.md` keeps the sentence about headers and points to the new file.
- `test_testing_md_indexes_every_test_file_in_one_short_row` reads `docs/testing-index.md` instead (rename it to
  `test_testing_index_lists_every_test_file_in_one_short_row`). AC2 reuses `table_problems`' row regex: e.g. a
  `DocChecks.index_rows(doc_text) -> Array[String]` that `table_problems` also uses, so the row format lives in one place.
- Rejected alternative: generate the index from each file's `##` header (a script plus an "index is current" check).
  It removes the hand-written row, but headers are multi-line prose with no one-line summary field, so it needs a new
  header convention across ~200 files and a regeneration step every item must remember; the separate file removes the
  cap friction with no new convention. Revisit if row drift from headers becomes a problem.
- Merge conflicts: rows are sorted by path, so two items adding different files touch different lines; conflicts
  only remain when two rows land adjacent.
- Docs to update: `docs/development-process.md` (its docs table: a row for `docs/testing-index.md`, `docs/testing.md`'s
  row drops "a one-line index"), the `tdd` skill (step 1: skim `docs/testing-index.md`; the new-file and close steps
  add or update the row there), `add-decision` (its new-test-file line), `project-review` (drift line), and
  `tests/test_docs.gd`'s and `tests/lib/doc_checks.gd`'s `##` headers and `ROW_LIMIT` comment.
- After merge: update the `testing-md-size-cap` memory (the friction is gone; the cap still applies to the guide).

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_docs::…` |

## Manual check
- [ ] `wc -c docs/testing.md docs/testing-index.md`: the guide is under 15 KB; the index holds every test file's row.
- [ ] The link from `docs/testing.md` to `docs/testing-index.md` opens the table.

## Log
- 2026-10-07: specced. Chose the separate file over generating from headers (Design notes). Assumed the helper tables
  stay in `docs/testing.md` (they are guide content and change rarely) and that the index gets no size cap.
