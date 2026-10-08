---
id: 397
title: card_art.py tracks each card's art state and only generates and fixes
type: feature
status: in-progress
branch: feat/397-card-art-script-pipeline
---

## Goal
The developer (and the `card-art` skill, 398) can ask `scripts/card_art.py` which cards need drawing, reviewing or
fixing, and run only that work. Today the script can't tell a changed prompt from an unchanged one, `generate --force`
loses the old picture, two runs at once undo each other's records, and its GPT `revise` and `critique` steps duplicate
work Claude now does (and did worse: the critic missed the physical errors and its edits made new ones).

## Acceptance criteria
All run against a temporary art folder and a fake image API (no network, no key needed unless stated).

- [ ] AC1 (status): Given five cards: A with no picture; B whose picture was approved at its current hash with its
  prompt unchanged; C whose picture's hash differs from its approved hash; D whose prompt changed since its picture was
  drawn; E with a pending `edit` finding for its current picture; when `card_art.py status` runs, then it lists A and D
  under "generate", C under "review", E under "fix", does not list B, makes no API call and exits 0.
- [ ] AC2 (generate): Given cards A and D from AC1 and an existing picture for D, when `generate` runs, then it draws
  exactly A and D, D's old picture is in `assets/card-art-history/` as `D-<timestamp>.png`, and each card's state
  records the hash of the prompt it was drawn from and of the new picture; a second `generate` draws nothing.
- [ ] AC3 (force keeps history): Given card B with a picture, when `generate --force --only B` runs, then B is redrawn
  and the old picture is in `assets/card-art-history/` (today it is overwritten).
- [ ] AC4 (fix): Given card E with one pending `edit` finding written for its current picture's hash, when `fix` runs,
  then the image editor gets E's picture and the finding's instruction, the old picture moves to history, the finding is
  marked done, E's edit-round count goes from 0 to 1, and `status` now lists E under "review".
- [ ] AC5 (stale finding): Given card E whose pending `edit` finding was written for an older picture hash, when `fix`
  runs, then E is skipped with a message naming E and "stale", its picture is unchanged and no API call is made.
- [ ] AC6 (one run at a time): Given a run holding the lock file, when a second `generate` or `fix` starts, then it exits
  non-zero naming the lock file and changes nothing; when the first run ends, normally or by an error, the lock file is
  gone.
- [ ] AC7 (key): Given no `OPENAI_API_KEY`, when `status` runs it works; when `generate` or `fix` runs with work to do,
  it exits non-zero with "Set OPENAI_API_KEY" before writing any file.
- [ ] AC8 (GPT steps gone): When `card_art.py revise` or `card_art.py critique` runs, then argparse rejects the
  subcommand (exit 2); the script makes no text-model call anywhere.

## Out of scope
- The skill and Claude's review and prompt-revision steps: 398.
- Cleaning up old pictures in `assets/card-art-history/` (kept on disk, only ignored by git).
- Any change to how the game shows art (`ui/`, 381).

## Design notes
- **Files.** `assets/card-art-prompts.jsonl` stays the one prompt list: one row per card, the final prompt Claude
  revised from the brief in `docs/design/card-art.md`, with `culture`, `date` and a `notes` field for what the revision
  changed and why. (Done before this item: `assets/card-art-revised.jsonl` was folded into the prompt list and deleted,
  and the `revise` step removed; AC8 still covers `critique`.)
  `assets/card-art-critique.jsonl` becomes `assets/card-art-review.jsonl`, one row per card:
  `{"id", "prompt_hash", "image_hash", "approved_hash", "edit_rounds", "findings": [{"problem", "action":
  "edit"|"prompt"|"accept", "fix", "for_hash", "done"}]}`. The script writes the hashes and `edit_rounds`; Claude writes
  `approved_hash` and `findings`. Hashes are SHA-256 of the prompt text and of the PNG bytes.
- **Derived state** (what `status` reports): generate = no picture, or the prompt's hash ≠ `prompt_hash`; fix = a
  finding with `action: edit`, not done, `for_hash` = the picture's hash; review = the picture's hash ≠
  `approved_hash` and nothing to fix. A `prompt` finding means Claude rewrites the prompt, so the card reaches
  "generate" on its own; there is no regenerate command.
- **Words.** `apply` becomes `fix`; `critique` (the file and the step) becomes review; `revise` goes. Commands:
  `status`, `generate`, `fix`, each with `--only id,id`; `generate` and `fix` take `--force`, `--image-model`,
  `--quality`.
- **Saving** goes through one function that re-reads the review file and replaces only the one card's row (already in
  the script as `save_critique`), and the lock file `assets/.card-art.lock` stops two runs at once.
- **History**: `assets/card-art-history/` goes in `.gitignore`; every replaced picture lands there, by both commands.
- **Migration**, once: hash every current picture and prompt into the review file. Cards whose pictures were changed
  after their last review (the 13 major and 30 minor cards fixed on 2026-10-07) start unapproved; the rest are approved
  at their current hash.
- **Tests**: `scripts/tests/test_card_art.py`, stdlib `unittest`, with the HTTP call replaced by a fake that returns a
  fixed PNG and records its requests. `scripts/test.sh` runs them too (they take well under a second), so the Stop hook
  covers them.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `StatusTest.test_status_lists_what_each_card_needs` |
| AC2 | `GenerateTest.test_generate_draws_only_new_and_changed_prompts_and_keeps_the_old_picture` |
| AC3 | `GenerateTest.test_generate_force_redraws_and_keeps_the_old_picture` |
| AC4 | `FixTest.test_fix_edits_the_picture_and_sends_it_back_to_review` |
| AC5 | `FixTest.test_fix_skips_a_finding_written_for_an_older_picture` |
| AC6 | `LockTest.test_a_second_run_stops_while_the_lock_is_held`, `LockTest.test_the_lock_is_released_when_a_run_ends`, `LockTest.test_the_lock_is_released_when_a_run_crashes` |
| AC7 | `KeyTest.test_status_needs_no_key_but_generate_and_fix_do`, `KeyTest.test_generate_with_nothing_to_draw_needs_no_key` |
| AC8 | `GptStepsGoneTest.test_revise_and_critique_are_not_commands`, `GptStepsGoneTest.test_the_script_makes_no_text_model_call` |

All in `scripts/tests/test_card_art.py`; `scripts/test.sh` runs them after the Godot shards (`-k <filter>`).

## Manual check
- [ ] With the key set, `python3 scripts/card_art.py status` on the real art lists only the unapproved cards from the
  migration, and `generate` with nothing to draw makes no request.

## Log
- 2026-10-07: before work started, the revised prompts were folded into `card-art-prompts.jsonl`, `card-art-revised.jsonl` deleted and `revise` removed from the script (it couldn't parse already-revised prompts).
