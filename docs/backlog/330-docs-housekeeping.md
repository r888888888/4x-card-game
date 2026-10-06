---
id: 330
title: Bring PLAN.md and the docs back in line with the code, and clear tracked junk
type: chore
status: red-review
branch: feat/330-docs-housekeeping
---

## Goal
The 2026-10-06 project review found the docs describing a project that no longer exists in places: PLAN.md's
"Keeping the deck model open" describes a `move_card` effect, a `market` zone and a `buy_card` action that were never
built; its layout section misses 15 scripts; it places `upkeep_forecast` in `game_engine.gd`; its milestone headings
still say "in design" and "in progress"; CLAUDE.md and `docs/testing.md` say the suite takes ~4 s (it takes ~10 s
wall clock, ~50 s CPU). A profiling script from 223 still runs in the suite, and three orphan `.uid` files are
tracked. This item fixes all of that first, so the later review items have less to keep in sync, and adds a check so
named paths can't drift again.

## Acceptance criteria
- [ ] AC1: Given PLAN.md, CLAUDE.md, README.md, every `docs/*.md` and every `.claude/skills/*/SKILL.md`, when the suite
  runs, then a test fails naming the document and the path for every repo path it names in backticks or a link
  (`engine/…`, `ui/…`, `sim/…`, `autoload/…`, `scripts/…`, `tests/…`, `data/…`, `docs/…`) that doesn't exist;
  placeholder paths with `330` or `<…>` are skipped. It passes on the fixed docs.
- [ ] AC2: PLAN.md's "Project layout" describes each directory's role and names only its entry points and key
  classes (no per-script list to keep current); every script it does name exists (AC1).
- [ ] AC3: Given the tracked files, when the suite runs, then a test fails naming any `.gd.uid` under `engine/`, `ui/`,
  `sim/`, `autoload/` or `tests/` with no `.gd` beside it. `tests/test_growth.gd.uid`,
  `tests/test_tech_tree_modal.gd.uid` and `tests/test_zz_debug.gd.uid` are deleted.
- [ ] AC4: `tests/test_zz_bench.gd` (223's profiling script: `check(true, "ran")`, four main scenes, printed timings)
  and its `.uid` are deleted; the suite's test count drops by exactly 1.
- [ ] AC5: Every other test passes unedited.

## Out of scope
- Restructuring `docs/testing.md`'s file table (331 makes each file's header the source).
- Extending the 700-line limit to `sim/` (`sim/sim_stats.gd` is at 721; that needs its own split item).
- Any behaviour change.

## Design notes
- Text-only fixes (Manual check below, no test): PLAN's "Keeping the deck model open" rewritten to what exists (a
  fixed main deck; growth through the supply, the build menu and techs), and `ConfigLoader.DECK_MODELS`'s comment
  ("deckbuilding and era are planned") to match; `upkeep_forecast` and `turn_forecast` placed in
  `engine/engine_queries.gd` / `TurnLoop`; milestone headings say what is built; the doc comment
  "## The kinds of decision pending() can report." moved from `MAX_TERRITORY_NAME` to the `PENDING_*` constants
  (`engine/game_engine.gd:19`).
- Timings: measure `scripts/test.sh` (wall) and `TEST_JOBS=1 scripts/test.sh` on the dev machine with the load noted,
  and put the figures in CLAUDE.md's Commands and `docs/testing.md`'s Speed section.
- AC1 and AC3 are new tests in a docs/structure test file (e.g. `tests/test_docs.gd`); they replace the matching
  sections of `.claude/skills/project-review/scan.sh` ("Tracked files that shouldn't be"), which can then go.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_docs::test_paths_in_finds_backticked_and_linked_repo_paths`, `test_placeholders_globs_commands_and_web_links_are_skipped`, `test_link_paths_resolve_from_the_docs_folder`, `test_missing_paths_names_the_doc_and_the_path`, `test_the_checked_docs_are_plan_claude_readme_the_docs_and_the_skills`, `test_every_path_the_docs_name_exists` |
| AC2 | `test_docs::test_every_path_the_docs_name_exists` (the layout's named files), plus Manual check |
| AC3 | `test_docs::test_a_uid_with_no_script_beside_it_is_an_orphan`, `test_no_uid_file_in_the_project_has_lost_its_script` |
| AC4 | The deletion itself; the suite's count drops by 1 (checked at verify) |
| AC5 | The full suite, unedited |

## Manual check
- [ ] PLAN.md's deck-model, layout, forecast and milestone text read true against the code.
- [ ] The timings in CLAUDE.md and `docs/testing.md` match a fresh measurement.

## Log
- 2026-10-06: specced from the project review.
