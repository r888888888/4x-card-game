---
name: balance
description: Compare game balance between main and the current checkout with the headless simulator (scripts/sim.sh), side by side per metric. Use only in a dedicated balance item or when the user asks ("what did this do to balance", "run the sim", "/balance"). Balance is a separate step: don't run it after ordinary feature, bug or content changes.
argument-hint: "[seeds, default 20]"
---

# Balance comparison

The simulator plays one ScriptedBot game per seed (1..N) and reports mean, min and max of `score`, `cities`
(founded beyond the starting ones), `pop` (at game end), `techs` (researched), `bought` (supply buys), `era`,
`explored` (turns the territory deck lasted) and, per era with techs (143), `era_<n>_open` / `era_<n>_done` (the turn
the era was added / its last tech was learned; the turn limit if never).
Anarchy and governments (158): `anarchies`, `revolts`, `anarchy_turns` (turns that started under it), `restored`
(order bought), `gov_changes` (ruling government changed, Anarchy not counted), `famine_turns`, `trashed`, and
`<id>_turns` per government a game can have (turns that started with it ruling).
The bot is fixed and simple, so read the numbers as *relative*: compare against `main`, not against a target.

Since 134 it plays five strategies (`baseline`, `growth`, `wealth`, `wide`, `tall`) as every listed civilization.
`scripts/sim.sh <seeds>` prints a block per strategy (its mean score per civilization, then its metrics over all of
them). That is 600 games at 20 seeds, and since the bot looks ahead (159, 240, 269) one 100-turn game costs 12–25 s of
CPU: about 3 CPU-hours, so 20–30 minutes on this machine. It runs on the performance cores but one (291; `SIM_PROCS=n`
to change). Only one parallel run at a time, across every checkout: a second one exits 1 at once with "another sim run
is using the CPU (pid N)". Wait for that run, don't start the two sides side by side. Each game's result is cached
by the code and data that played it (292), shared by every checkout: a side that hasn't changed since its last run
(usually `main`) reads every game back in seconds, and the header says how many came from the cache. `scripts/sim.sh <seeds> <strategy>` prints one table for that strategy
as the default civilization (seconds). `baseline` is the pre-134 bot: it never grows pop.

## Run it

1. Seeds: the argument, or 20.
2. Current checkout: `scripts/sim.sh <seeds>` (all strategies), or `scripts/sim.sh <seeds> baseline` for a quick
   check. If it exits 1, show the loader errors and stop.
3. `main`, without touching the working tree:
   ```bash
   git worktree add --detach "$SCRATCH/balance-main" main
   (cd "$SCRATCH/balance-main" && scripts/sim.sh <seeds>)   # same strategy argument as step 2
   git worktree remove --force "$SCRATCH/balance-main"
   ```
   If `main` has no `scripts/sim.sh` yet, or no strategies (before 134), copy `sim/` and `scripts/sim.sh` from the
   checkout into the worktree before running, and say so.
   Use the session scratchpad directory for `$SCRATCH`. The worktree has no `.godot/` cache, so its first run
   imports the project (a few seconds). Always remove the worktree, also when the run fails.
   If the current branch *is* `main` with no changes, say so and show one table.
4. Show one table: metric | main mean (min–max) | this mean (min–max) | Δ mean; with all strategies, one row per
   strategy × civilization for score, then that table per strategy only where something moved. Then two or three sentences
   on what moved and the likely cause from the diff (`git diff main -- data/`). Flag any metric whose mean
   moved by more than ~10%, and any `min` of `cities` or `techs` that fell to 0.

## Content changes

For an edit that only touches `data/*.json` (numbers, new cards made from existing ops):

- No new tests. Content tests check invariants, not numbers; if one fails, the data broke an invariant
  (fix the data, or ask whether the invariant should change).
- Run `scripts/test.sh` (includes `test_real_data_loads` and the 20-seed smoke sweep). Don't run this comparison
  as part of an ordinary content item: balance is a separate step. Note any balance worry in the item's Log.
- In a balance item: run this comparison, and put the exact shipped numbers and the table in its Manual check / Log.
- If a rule changed (not just a number), update PLAN.md.
