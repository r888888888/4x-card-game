---
name: spec
description: Turn a feature idea, change request, or bug report into a backlog item in docs/backlog/ with testable Given/When/Then acceptance criteria. Use when the user describes something new to build, a rule change, or a bug, or asks to plan, spec, or add something to the backlog, before any code is written.
argument-hint: "<feature idea or bug report>"
---

# Spec a backlog item

Goal: a `docs/backlog/NNN-slug.md` file whose acceptance criteria are specific enough that each
one maps directly to a test. Don't write code or tests in this skill.

## Steps

1. **Understand the request.** Read the relevant parts of `PLAN.md` and the engine/data code the
   change touches, so your questions and criteria use the real rules (costs, triggers, zones,
   turn-loop phases).
   For a bug, try to reproduce it now: write a scratch reproduction in the Bash tool, or reason
   from the code with the seed. Record what you find; don't fix anything.

2. **Ask clarifying questions** (AskUserQuestion, at most 4 at a time) only about decisions that
   change behavior: edge cases, numbers, interaction with existing rules, what's out of scope.
   Propose a recommended answer for each. Skip questions the code or PLAN.md already answers.

3. **Pick the id**: highest `NNN` in `docs/backlog/` + 1, zero-padded to 3 digits. Slug is a short
   kebab-case summary.

4. **Write the item** from `docs/backlog/_templates/feature.md` or `bug.md`:
   - Acceptance criteria are Given/When/Then with concrete numbers. Cover the main path, each
     edge case agreed in step 2, and each rejection path (for example: can't afford, wrong zone,
     game over).
   - For bugs, AC1 is the reproduction turned into the expected behavior, and it includes the seed
     when randomness matters.
   - Behavior you can only judge by eye goes under **Manual check**, not in the criteria.
   - Note any data format change (new JSON fields, new ops) and new engine API under Design notes.
   - Leave **Test plan** for the `tdd` skill to fill in.
   - Keep items small: if it needs more than ~6 criteria or touches several systems, propose
     splitting it into several items.
   - `status: draft`.

5. **Get approval.** Show the user the criteria (not the whole file) and ask them to approve or
   edit. On approval, set `status: ready`. If the user already said to go ahead and build it, hand
   over to the `tdd` skill after approval.

## Quality bar for criteria

- Could someone else write the test from this line alone? If not, make it more concrete.
- Does it describe **observable behavior** (state, return values, signals, loader messages)
  rather than implementation?
- Is every number consistent with the current rules and the card data used in tests?
