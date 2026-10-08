---
id: 411
title: A building's Upgrades row squeezes its status to one letter a line
type: bug
status: review
branch: fix/411-upgrade-status-wraps-per-letter
---

## Reproduction
- Seed: any
- Steps:
  1. Build a Farm, then click it in the territory view.
- Expected: the Irrigation Canals row reads why it can't be built ("Irrigation Canals isn't unlocked yet.") beside its
  name and rules.
- Actual: the reason runs down the right edge one letter a line ("I r r i g a t i o n …").

## Acceptance criteria
- [x] AC1: Given a Farm on Homeland with 0 food (each upgrade row refused, so each shows its reason), when its details
  open, then each row's status label lays out in no more lines than its text has words.
- [x] AC2: Given a Farm carrying a Plough, then the Plough's "Built" reads on one line.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_upgrade_ribbons::test_bug_411_an_upgrade_rows_status_wraps_at_words_not_letters` |
| AC2 | `test_upgrade_ribbons::test_bug_411_an_upgrade_rows_built_reads_on_one_line` |

## Root cause
The status label wraps (`AUTOWRAP_WORD_SMART`) inside the row's `HBoxContainer` but didn't expand, and a wrapping
label's minimum width is about one character, so the row gave it that and it broke after every letter. 387's tests
checked each row's status text, not how it laid out. Fix: `UpgradeList._status` makes it expand at half the stretch of
the name-and-rules column (a third of the row), right-aligned.

## Manual check
- [ ] Open a Farm's details before researching Irrigation: the Irrigation Canals row's reason sits to the right of its
  name and rules, wrapped at words, and the name and rules still have most of the row.

## Log
- 2026-10-08: specced from the user's report. The status label (`UpgradeList._label`) wraps (`AUTOWRAP_WORD_SMART`) in
  an `HBoxContainer` without expanding, so its minimum width is ~0 and it wraps every letter. The rows hook gains the
  status label (`status_label`, null for a row with a button) so the test can read its line count.
- 2026-10-08: red. Both tests reproduce it: "Built" lays out in 6 lines, a 7-word reason in 28.
- 2026-10-08: green. Status labels expand at stretch 0.5, right-aligned; full suite green.
