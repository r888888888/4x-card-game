---
id: 284
title: The test runner calls a test_* helper that takes arguments, and hangs
type: bug
status: done
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
- [x] AC1: Given a test file with `test_plain()` (no arguments) and `test_helper(id: String)`, when the runner picks the
  methods to run from it with no filter, then it runs `test_plain` only, and reports one failure
  `<file>::test_helper: test methods take no arguments; rename the helper`, without calling `test_helper`.
- [x] AC2: Given the same file, when the filter matches only `test_plain`, then `test_plain` runs and nothing is
  reported for `test_helper` (a method the filter leaves out is never reported).
- [x] AC3: Given the same file, methods whose names don't begin with `test_` (with or without arguments) are neither
  run nor reported.
- [x] AC4: The real suite still runs green: no test file in `tests/` has a `test_*` method with arguments.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_test_runner::test_bug_284_a_test_method_with_arguments_is_reported_not_run` |
| AC2 | `test_test_runner::test_bug_284_a_filtered_out_method_with_arguments_is_not_reported` |
| AC3 | `test_test_runner::test_bug_284_methods_not_named_test_are_ignored` |
| AC4 | the suite itself (`scripts/test.sh`) |

## Root cause
`tests/run_tests.gd` chose methods by name alone (`begins_with("test_")`) and called each with no arguments. A
helper named `test_*` that takes an argument then ran with a missing argument, and in 279 that hung the run before
any shard printed output. No test covered the runner's method selection. It now lives in
`tests/lib/test_methods.gd` (`select`), which reads each method's `args` and reports such a method as a failure
instead of calling it.

## Design notes
- The method selection moves out of `tests/run_tests.gd` into `tests/lib/test_methods.gd` (like `test_shards.gd`,
  223): `static func select(script: GDScript, file_label: String, filter: String) -> Dictionary` returning
  `{"run": Array[String], "failures": Array[String]}`, from `get_script_method_list()` and each method's `args`.
- The fixture is `tests/lib/fixtures/runner_fixture.gd`: the runner never scans `tests/lib/`, so its `test_helper`
  doesn't fail the real suite.

## Log
- 2026-10-05: specced from 279, where `test_card(id)` hung the suite.
- 2026-10-05: green. A misnamed helper filtered out by the run's filter isn't reported, so a filtered run isn't failed
  by unrelated files. A rejected method doesn't count in "N tests" but is one of the failures, so the run exits 1.
  Checked end to end with a throwaway `tests/test_zz_probe.gd` holding `test_card(id: String)`: the run finished in
  ~5 s with `FAIL test_zz_probe::test_card: test methods take no arguments; rename the helper` and exit 1.
