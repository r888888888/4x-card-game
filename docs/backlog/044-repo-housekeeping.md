---
id: 044
title: Repo housekeeping and PLAN.md cleanup
type: chore
status: review
branch: feat/044-repo-housekeeping
---

## Goal
Remove small inconsistencies found in the architecture review, and slim PLAN.md down to design decisions and
rules, so that later items have less duplicated documentation to keep in sync. No behavior change and no tests.

## Acceptance criteria
- [x] AC1: `.DS_Store` is removed from git and listed in `.gitignore`; `git ls-files | grep DS_Store` finds nothing.
- [x] AC2: PLAN.md no longer lists engine API signatures (the doc comments are the reference); each system section
  keeps its rules and points to the engine file. The project layout matches the tree (no `GameState` until 051,
  no per-test-file list; that lives in docs/testing.md).
- [x] AC3: CLAUDE.md gains (a) the action convention: every action `foo()` has a `foo_error()` and the UI never
  re-derives a condition; (b) the red-phase tip: type the engine as `Object` in tests that call methods that don't
  exist yet, so the file still parses.
- [x] AC4: With the user's OK, `Bash(git merge *)` is removed from `.claude/settings.local.json` (it contradicts
  "ask before merging").
- [x] AC5: The triple blank line in `engine/game_engine.gd` (before `_start_turn`) is two. The suite stays green.

## Out of scope
- Anything that changes code behavior.

## Log
- 2026-09-29: Approved by the user, including AC4. Untracked `.DS_Store` and ignored it; PLAN.md's engine API
  lists replaced by pointers to the code, layout tree made generic (effects, zones, tests); CLAUDE.md gains the
  action/`_error` convention and the `Object` red-phase tip; `Bash(git merge *)` removed from local settings
  (untracked file); triple blank line fixed. Note: `choose`, `decline_research`, `discard_card` and `end_turn`
  have no `_error` query yet (049 adds `end_turn_error`). 378 tests green.
