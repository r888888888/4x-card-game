---
id: 284
title: The test runner calls a test_* helper that takes arguments, and hangs
type: bug
status: red-review
branch: fix/284-test-methods-with-args
---

## Reproduction
- Seed: none (no randomness)
- Steps:
  1. In a test file, write a helper whose name begins with `test_` and that takes an argument (in 279:
     `func test_card(id: String) -> Dictionary` in `tests/test_card_text.gd`).
  2. Run `scripts/test.sh`.
- Expected: the run finishes and fails, naming the helper.
- Actual: `tests/run_tests.gd` runs every method whose name begins with `test_`, so it calls the helper with no
  argument; the run hangs indefinitely with no output.

## Acceptance criteria
- [ ] AC1: Given a test file with `test_plain()` (no arguments) and `test_helper(id: String)`, when the runner picks the
  methods to run from it with no filter, then it runs `test_plain` only, and reports one failure
  `<file>::test_helper: test methods take no arguments; rename the helper`, without calling `test_helper`.
- [ ] AC2: Given the same file, when the filter matches only `test_plain`, then `test_plain` runs and nothing is
  reported for `test_helper` (a method the filter leaves out is never reported).
- [ ] AC3: Given the same file, methods whose names don't begin with `test_` (with or without arguments) are neither
  run nor reported.
- [ ] AC4: The real suite still runs green: no test file in `tests/` has a `test_*` method with arguments.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_test_runner::test_bug_284_a_test_method_with_arguments_is_reported_not_run` |
| AC2 | `test_test_runner::test_bug_284_a_filtered_out_method_with_arguments_is_not_reported` |
| AC3 | `test_test_runner::test_bug_284_methods_not_named_test_are_ignored` |
| AC4 | the suite itself (`scripts/test.sh`) |

## Root cause
<!-- Filled in by Claude after the fix: what was wrong and why the tests didn't catch it. -->

## Design notes
- The method selection moves out of `tests/run_tests.gd` into `tests/lib/test_methods.gd` (like `test_shards.gd`,
  223): `static func select(script: GDScript, file_label: String, filter: String) -> Dictionary` returning
  `{"run": Array[String], "failures": Array[String]}`, from `get_script_method_list()` and each method's `args`.
- The fixture is `tests/lib/fixtures/runner_fixture.gd`: the runner never scans `tests/lib/`, so its `test_helper`
  doesn't fail the real suite.

## Log
- 2026-10-05: specced from 279, where `test_card(id)` hung the suite.
