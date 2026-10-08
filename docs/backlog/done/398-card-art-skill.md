---
id: 398
title: A card-art skill takes the art list to reviewed pictures
type: feature
status: done
branch: feat/398-card-art-skill
---

## Goal
After the art list in `docs/design/card-art.md` changes, the developer runs one skill (`/card-art`) and Claude takes
every new or changed card from brief to an approved picture: revising the prompt, drawing, reviewing, fixing and
re-reviewing, and ends with a report of anything it couldn't resolve. It writes down the process this session worked
out by hand (2026-10-07), including what went wrong: unchecked fixes, edits the image editor can't do, prompts that ask
for something physically impossible, lost notes and clobbered records.

## Acceptance criteria
Built on 397's `status`, `generate` and `fix`. A skill is instructions, so each criterion is checked by reading
`.claude/skills/card-art/SKILL.md`, and by the dry run under Manual check.

- [x] AC1 (prompts): The skill says that for every card whose brief is new or changed, Claude writes its prompt into
  `assets/card-art-prompts.jsonl` from the §19.8 template, revising only the subject, for history (the card's culture
  and date) and for the style guide's §19; and checks the subject against the known weak spots: an exact count above
  four of the same figure, light and shadow direction, moon phases, reflections, and figures sitting on or holding
  things.
- [x] AC2 (approve spend): The skill says that before each `generate` or `fix` run Claude shows `status`'s list and the
  number of pictures, and runs it only after the developer says yes in the chat.
- [x] AC3 (review): The skill says Claude reviews every card `status` lists under "review", at most 8 pictures per
  batch, zooming into hands, counts, joins, shadows and reflections; writes each card's result to
  `assets/card-art-review.jsonl` as soon as it's judged; and either approves the picture's hash or records findings,
  each with an action: `edit` (a local fix, with an instruction naming where, describing the result and ending "Change
  nothing else"), `prompt` (rewrite the prompt, so the card is redrawn) or `accept` (with the reason).
- [x] AC4 (what not to report): The skill lists the house-style choices that are not errors (a cream sky at night,
  stars or a moon by day, vignette edges, flattened perspective), and the edits the image editor fails at, which go to
  `prompt` instead: flipping or mirroring, changing a count, turning figures round, rebuilding a structure.
- [x] AC5 (loop and stop): The skill says every fixed or redrawn picture goes back through review, a card gets at most
  2 edit rounds before its next finding must be `prompt`, and at most 1 redraw after that; a card still failing then is
  left unapproved and named in the report. The skill ends when `status` lists nothing, or only those cards.
- [x] AC6 (finish): The skill ends by reporting what was approved, accepted and left unresolved, and committing
  `assets/cards/`, the prompt list and the review file on the current branch with a `card art:` message (never the
  history folder).

## Out of scope
- The script changes the skill relies on (397).
- Writing or changing the briefs in `docs/design/card-art.md`: the developer's step before the skill.
- Hand edits to pictures (the Pillow fixes tried on 2026-10-07): not part of the skill.

## Design notes
- `.claude/skills/card-art/SKILL.md`, with a description that triggers on "card art", "generate the art", "review the
  card art". `CLAUDE.md`'s Commands list gains one line pointing at it, and `docs/design/card-art.md` gains a short
  "Making the pictures" section linking to the skill.
- Claude runs `generate` and `fix` itself: `OPENAI_API_KEY` is in its environment. If it isn't, the skill stops and
  says so rather than handing commands over.
- Not a spike and not game code: no engine tests. The checks are the skill text and the dry run.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1–AC6 | Read `SKILL.md`; dry run (Manual check) |

## Manual check
- [x] Dry run: change one brief in `docs/design/card-art.md` (for example solstice_rites' moon to a full moon) and run
  `/card-art`. Claude rewrites that prompt, asks before drawing 1 picture, reviews it, and either approves it or fixes
  and re-reviews it; the run ends with a report and one commit.

## Log
- 2026-10-07: built `.claude/skills/card-art/SKILL.md`, with a line in `CLAUDE.md`'s Commands and a "Making the
  pictures" paragraph in `card-art.md`. No tests (instructions only; the item's checks are reading the skill and the
  dry run). To tell a changed brief from an unchanged one, each prompt row now also holds `brief` and `inks` as they
  were when it was written (backfilled for all 189 from the current list, which hasn't changed since the prompts were
  revised; prompt hashes unchanged). The skill's two Python snippets (brief diff, review write) were run: the diff
  finds nothing changed, and the write approved a card in a copy of the files.
  Limits count from the start of a run (`edit_rounds` and `prompt` findings noted then), since the script never resets
  `edit_rounds`. Follow-up: `card-art.md` says an upgrade is drawn with its base picture as a reference, but
  `card_art.py generate` sends no reference image; the skill only asks the prompt to keep the base's viewpoint.
- 2026-10-07: dry run done as a real run instead of a changed brief: `/card-art` reviewed the 43 unapproved pictures
  (zoomed crops, results written per card), asked before each spend, fixed 4 and redrew 2, re-reviewed them, reported
  and committed (`4a62a7c8`), then redrew spearmen and tuna_run from rethought prompts (`cc325d5d`). Prompt writing
  for a changed brief wasn't exercised from the brief side: tuna_run's prompt was rewritten first and its brief
  updated to match. Lessons went into the skill's weak spots (counts, pose direction; `15ed0b1c`).
