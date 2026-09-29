---
name: balance
description: Compare game balance between main and the current checkout with the headless simulator (scripts/sim.sh), side by side per metric. Use after editing data/*.json or rules that change balance, when the user asks "what did this do to balance", "run the sim", "/balance", or when making a content-only change.
argument-hint: "[seeds, default 20]"
---

# Balance comparison

The simulator plays one ScriptedBot game per seed (1..N) and reports mean, min and max of `score`, `cities`
(founded beyond the starting ones), `pop` (at game end), `techs` (researched), `bought` (supply buys) and `era`.
The bot is fixed and simple, so read the numbers as *relative*: compare against `main`, not against a target.

## Run it

1. Seeds: the argument, or 20.
2. Current checkout: `scripts/sim.sh <seeds>`. If it exits 1, show the loader errors and stop.
3. `main`, without touching the working tree:
   ```bash
   git worktree add --detach "$SCRATCH/balance-main" main
   (cd "$SCRATCH/balance-main" && scripts/sim.sh <seeds>)
   git worktree remove --force "$SCRATCH/balance-main"
   ```
   If `main` has no `scripts/sim.sh` yet (the branch that adds it), copy `sim/` and `scripts/sim.sh` from the
   checkout into the worktree before running, and say so.
   Use the session scratchpad directory for `$SCRATCH`. The worktree has no `.godot/` cache, so its first run
   imports the project (a few seconds). Always remove the worktree, also when the run fails.
   If the current branch *is* `main` with no changes, say so and show one table.
4. Show one table: metric | main mean (min–max) | this mean (min–max) | Δ mean. Then two or three sentences
   on what moved and the likely cause from the diff (`git diff main -- data/`). Flag any metric whose mean
   moved by more than ~10%, and any `min` of `cities` or `techs` that fell to 0.

## Content change

For an edit that only touches `data/*.json` (numbers, new cards made from existing ops):

- No new tests. Content tests check invariants, not numbers; if one fails, the data broke an invariant
  (fix the data, or ask whether the invariant should change).
- Run `scripts/test.sh` (includes `test_real_data_loads` and the 20-seed smoke sweep), then this comparison.
- Put the exact shipped numbers and the comparison table in the backlog item's Manual check / Log.
- If a rule changed (not just a number), update PLAN.md.
