---
id: 085
title: Script size limits across engine/ and ui/
type: feature
status: review
branch: feat/085-script-size-limits
---

## Goal
Replace 052's 500-line cap on `ui/main.gd` with one size check over every script in `engine/` and `ui/`: a hard
limit of 700 lines that fails the suite, and a soft limit of 500 that prints a warning. Today the cap covers only
the file that was already split, so features trim lines just to fit it. Meanwhile `game_engine.gd` (527),
`data_loader.gd` (587) and `card_view.gd` (674) have no cap at all. Crossing the hard limit should mean "spec a
split item", not "evict a helper".

## Acceptance criteria
- [x] AC1: Given a map of script path → line count `{a: 701, b: 700, c: 501, d: 500}`, when it is checked against
  hard 700 / soft 500, then the hard-limit list is `[a]` and the soft-limit list is `[b, c]` (so 700 and 500
  themselves are within their limits).
- [x] AC2: Given every `.gd` file under `engine/` and `ui/`, including subfolders such as `engine/effects/`, when
  the suite runs, then a test fails if any file has more than 700 lines, and its failure message names each such
  file with its line count. It passes on today's code (largest: `ui/card_view.gd`, 674).
- [x] AC3: Given files over 500 lines but at most 700, when `scripts/test.sh` runs, then its output has one
  `WARN <path>: <N> lines (soft limit 500)` line per file, and the suite still exits 0. Today that is
  `engine/game_engine.gd`, `engine/data_loader.gd` and `ui/card_view.gd`.
- [x] AC4: Line counts match `wc -l` for the same file (a trailing newline doesn't add a line).
- [x] AC5: `test_main_script_is_at_most_500_lines` and `MAX_MAIN_LINES` are gone. The other checks in
  `tests/test_ui_structure.gd` (components in their own scripts, main uses each, no engine internals) are unchanged.

## Out of scope
- Splitting any file now. `game_engine.gd` stays at 527 lines and just triggers a warning.
- `autoload/`, `tests/` and `scripts/`.
- Making the Stop hook show warnings (it only reports failures).

## Design notes
- New file `tests/test_script_size.gd`, since the check is no longer UI-only. Put the pure classification (AC1)
  in a function the file-walking test also uses, so the boundaries are tested on fixed numbers rather than on the
  repo's current sizes.
- The warning is a plain `print`, so it's one clean line in `scripts/test.sh` output. `push_warning` would pass too (the
  runner's logger ignores warnings), but it adds engine backtrace noise.
- Docs: in `docs/testing.md`, drop "`main.gd` at most 500 lines" from the `test_ui_structure` row and add a
  `test_script_size` row. Add one line under Style in `CLAUDE.md`: scripts in `engine/` and `ui/` stay within 700
  lines; past 500 the suite warns; when a file crosses 700, spec a split along a real boundary instead of trimming.
- This changes 052's approved test with the user's approval (2026-09-29): hard 700, soft 500.

## Test plan
| AC | Test (`tests/test_script_size.gd`, helpers in `tests/lib/script_sizes.gd`) |
|---|---|
| AC1 | `test_files_over_700_break_the_hard_limit_and_501_to_700_the_soft` |
| AC2 | `test_scripts_in_engine_and_ui_are_counted_including_subfolders`, `test_no_script_in_engine_or_ui_is_over_700_lines` |
| AC3 | `test_a_warning_names_the_file_its_lines_and_the_soft_limit`; the real warnings are printed by `test_no_script_in_engine_or_ui_is_over_700_lines` |
| AC4 | `test_line_count_matches_wc` |
| AC5 | `test_ui_structure::test_main_script_is_at_most_500_lines` deleted; checked by grep |

## Log
- 2026-09-29: Built in worktree `../4x-card-game-085` because the main checkout had other sessions' uncommitted
  backlog edits. Helpers are static functions in `tests/lib/script_sizes.gd` (`line_count`, `count_lines_in`,
  `classify`, `warning`). Tests 478 → 482 (+5 new, −1 main.gd cap). On `main`, the warnings are
  `engine/data_loader.gd` (597), `engine/game_engine.gd` (522) and `ui/card_view.gd` (674). The 059 branch adds lines
  to `game_engine.gd` (527) and doesn't reach 700.
