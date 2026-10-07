---
name: balance
description: Compare game balance between main and the current checkout with the headless simulator (scripts/sim.sh), side by side per metric. Use only when the user asks for a run in the chat ("what did this do to balance", "run the sim", "/balance"). Balance runs are manual: never start one on your own, not after a feature, bug, content or sim/ change, and not as a step of a balance item.
argument-hint: "[seeds, default 20]"
---

# Balance comparison

Balance runs are manual: they take tens of minutes to hours, so run this only when the user asks for it in the chat.
When a run would help and nobody asked, give the user the command (or note it in the item's Manual check) instead.

The simulator plays one GenericBot game per seed (1..N) and reports mean, min and max of `score`, `cities`
(founded beyond the starting ones), `pop` (at game end), `techs` (researched), `bought` (supply buys), `era`,
`explored` (turns the territory deck lasted) and, per era with techs (143), `era_<n>_open` / `era_<n>_done` (the turn
the era was added / its last tech was learned; the turn limit if never).
Anarchy and governments (158): `anarchies`, `revolts`, `anarchy_turns` (turns that started under it), `restored`
(order bought), `gov_changes` (ruling government changed, Anarchy not counted), `famine_turns`, `trashed`, and
`<id>_turns` per government a game can have (turns that started with it ruling).
Cost (294): `lookahead_turns`, the turns the bot's lookahead forks played (most of a game's CPU).
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

1. Max seeds: the argument, or 20.
2. Make a `main` worktree without touching the working tree, compare against it from the checkout, then remove it:
   ```bash
   git worktree add --detach "$SCRATCH/balance-main" main
   (cd "$SCRATCH/balance-main" && godot --headless --path . --import >/dev/null 2>&1)
   scripts/sim.sh --compare "$SCRATCH/balance-main" <max seeds>   # [strategy] [--civ id] [--turns n] narrow it
   git worktree remove --force "$SCRATCH/balance-main"
   ```
   `--compare` (293) plays each seed × strategy × civ on both checkouts and pairs them. Each strategy × civ cell gets
   seeds in rounds of 5 until its score change is known to ±5% of main's mean score, or it reaches max seeds. A branch
   that changes no rule stops every cell at 5. Games already played by the same code and data come from the cache.
   Both checkouts need 293's `sim/`: if `main` predates it, copy `sim/` and `scripts/sim.sh` from the checkout into
   the worktree before running, and say so.
   Use the session scratchpad directory for `$SCRATCH`. Always remove the worktree, also when the run fails. If it
   exits 1, show its errors (each names its side) and stop.
   If the current branch *is* `main` with no changes, say so and show a plain `scripts/sim.sh <seeds>` table instead.
3. Show the report. It already is the table: per strategy, one line per civ (`main`, `this`, `Δ ±` the 95% interval,
   the change in %, seeds played; `!` past 10%), then each other metric whose mean moved. Then two or three sentences
   on what moved and the likely cause from the diff (`git diff main -- data/`). Read a `!` whose interval includes 0
   as noise worth more seeds, not a finding.

## Content changes

For an edit that only touches `data/*.json` (numbers, new cards made from existing ops):

- No new tests. Content tests check invariants, not numbers; if one fails, the data broke an invariant
  (fix the data, or ask whether the invariant should change).
- Run `scripts/test.sh` (includes `test_real_data_loads` and the 20-seed smoke sweep). Don't run this comparison
  as part of an ordinary content item: balance is a separate step. Note any balance worry in the item's Log.
- In a balance item: put the exact shipped numbers in its Manual check, with the comparison command for the user.
  Run the comparison only when the user asks, then put its report in the Log.
- If a rule changed (not just a number), update PLAN.md.
