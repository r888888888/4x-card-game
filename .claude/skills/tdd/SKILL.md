---
name: tdd
description: Implement a backlog item (feature or bug fix) test-first. Branch, write failing tests from the acceptance criteria, stop at the red checkpoint for user review, then write minimal code, refactor, verify, and close the item. Use when the user asks to implement, build, fix, or work on a backlog item (e.g. "implement 004", "/tdd 004"), or to change game behavior that already has a ready item.
argument-hint: "<backlog item id>"
---

# Test-driven implementation of a backlog item

Follow the phases in order. The TDD rules in CLAUDE.md apply throughout.

## 0. Pick up the item

1. Read `docs/backlog/<id>-*.md`. If `status` is `draft`, or the criteria are too vague to test,
   stop and run the `spec` skill (or ask the user) first.
   If `status` is `red-review` and the user just approved, skip to phase 2.
2. Check that the working tree is clean (`git status`). If it isn't, ask the user what to do with
   the changes.
3. Branch from an up-to-date `main`: `git switch main && git switch -c <branch from the item>`.
   If the branch already exists, switch to it and read the item's Log to resume.
   Other sessions work in this checkout: when it's shared (another item's branch or edits are live, or other
   sessions are running), build in a worktree instead: `git worktree add -b <branch> ../<dir> main`, and run
   everything there.
4. Run `scripts/test.sh`. It must be green before you start; if not, report it and stop.
5. Set `status: in-progress`.

## 1. Red: write failing tests

1. Read `docs/testing.md` (running, conventions, helpers), skim `docs/testing-index.md` (one row per test file), and
   read the `##` header and tests of the file(s) you'll add to. Pick the file by area, or create `tests/test_<area>.gd`
   for a new area: open it with a `##` header saying what it covers (the source of truth) and add one short row to
   `docs/testing-index.md`, in path order (331, 391; the suite checks both).
   A UI test that reaches a control inside one of main's components reads it through `MainProbe` (`tests/lib/main_probe.gd`);
   add a function there, never a test hook on `main.gd` (392; the suite checks).
2. For each acceptance criterion, write one or more tests that express it exactly, named after
   the behavior (`test_bug_<id>_<what>` for bugs). Add any cards you need to `TEST_CARDS`.
   Call the engine API **as you want it to exist**: the tests design the interface.
3. Run `scripts/test.sh <filter>`. Check each new test:
   - It **fails**. A new test that already passes means either the behavior exists (tell the user)
     or the test is wrong.
   - It fails **for the right reason**: an assertion mismatch or a missing method/field the
     feature will add. A parse error or typo in the test itself doesn't count; fix it and re-run.
   - Existing tests still pass (unless an approved criterion changes an existing rule; name those
     tests explicitly at the checkpoint).
     `test_scaffolding` may fail too while the new tests hold engines as `Object`: expected until the refactor step.
4. Fill in the item's **Test plan** table (AC → test names) and set `status: red-review`.
5. Commit the red tests on the branch: `<id>: failing tests for <title>`. This is the only commit
   allowed with a red suite, and it stays on the feature branch.
6. `echo <id> > .claude/tdd-red` so the Stop hook doesn't block the expected failures.

## ⏸ Red checkpoint: stop and wait

Show the user, concisely:
- the AC → test table;
- for each test, a one-line summary of what it asserts and its current failure message;
- the proposed new/changed engine API (signatures) the tests imply;
- any existing tests whose expectations change, and why;
- any spec ambiguity you resolved while writing tests.

Then **end your turn**. Don't write production code until the user approves.
If they ask for changes, edit the tests, re-run, and present the checkpoint again.

## 2. Green: make the tests pass

1. `rm .claude/tdd-red`. Set `status: in-progress`.
2. Write the **minimum** production code to pass one test at a time. Re-run the filtered tests
   after each change. Don't add behavior no test asks for; if you notice missing behavior, add it
   to the item's Log as a follow-up, or ask whether it belongs in this item.
3. Follow the architecture rules: rules in `engine/`, the UI only calls the engine. For new effect
   ops use the `add-effect` skill.
4. Never change an approved test to make it pass. If one seems wrong, stop and explain.
5. When the full `scripts/test.sh` is green, commit: `<id>: <what now works>`.

## 3. Refactor with the suite green

1. Look at the code you touched and at its neighbors: duplication, unclear names, long functions,
   and helpers that belong in `test_case.gd`. Also check that comments and doc comments are still true.
   Remove red-phase scaffolding from the new tests (engines typed `Object`, untyped `load()`s, `has_method` and
   `== null` guards): the suite checks (333; a line that needs one says why with `# scaffolding-ok: <reason>`).
   Check `ui/` for any logic you added (a legality check, calculation or derived value): move it into an
   engine query under TDD and have the UI call it.
2. Refactor in small steps, running `scripts/test.sh` after each. Behavior must not change.
3. If you changed anything, commit: `<id>: refactor <what>`.

## 4. Verify and close

1. Run the full `scripts/test.sh`. It must be green, including `test_real_data_loads`.
2. If the change is visible in the UI: fill in the item's **Manual check** with concrete steps
   (seed, clicks, what to look for). You can launch `godot --path .` to confirm it starts without
   errors, but the user runs the checklist.
3. Update docs affected by the change: `PLAN.md` (layout, data format, milestones), `README.md`,
   a test file's `##` header (and its one-line `docs/testing-index.md` row) when what it covers grew, and
   `docs/testing.md`'s helper table if you added helpers.
4. Tick the acceptance criteria. Bugs: fill in **Root cause**. Add anything notable to the **Log**.
5. Set `status: review` and commit: `<id>: docs and backlog`.
6. Report to the user: what changed (files, new API), test count before → after, the manual
   check steps if any, and follow-ups. Ask whether to merge.

## 5. Merge (only when the user says so)

`git switch main && git merge --no-ff <branch>`, run `scripts/test.sh` on `main`, set
`status: done`, `git mv` the item into `docs/backlog/done/`, and commit on `main` (`<id>: done`). Then clean up (no need to ask): `git worktree remove` the item's worktree and
`git branch -d` its branch, do the same for any other branch in `git branch --merged main` whose worktree has no
uncommitted changes, and `git worktree prune`. Never touch unmerged branches; other sessions own them.
