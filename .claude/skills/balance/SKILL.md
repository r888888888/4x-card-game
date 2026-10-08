---
name: balance
description: Compare game balance between main and the current checkout with the headless simulator (scripts/sim.sh), side by side per metric. Use only when the user asks for a run in the chat ("what did this do to balance", "run the sim", "/balance"). Balance runs are manual: never start one on your own, not after a feature, bug, content or sim/ change, and not as a step of a balance item.
argument-hint: "[level 1-4, default 1]"
---

# Balance comparison

Balance runs are manual: they take tens of minutes to hours, so run this only when the user asks for it in the chat.
When a run would help and nobody asked, give the user the command (or note it in the item's Manual check) instead.

The simulator plays one GenericBot game per seed (1..N) and reports mean, min and max of `score`, `settlements`
(cities founded beyond the starting ones; `cities` before 328), `pop` (at game end), `techs` (researched), `bought` (supply buys), `era`,
`explored` (turns the territory deck lasted) and, per era with techs (143), `era_<n>_open` / `era_<n>_done` (the turn
the era was added / its last tech was learned; the turn limit if never).
Anarchy and governments (158): `anarchies`, `revolts` (each Anarchy lasts `unrest.anarchy_turns`, 384), `gov_changes` (ruling government changed, Anarchy not counted), `famine_turns`, `trashed`, and
`<id>_turns` per government a game can have (turns that started with it ruling).
Deck (376): `deck_end`, the cards in the deck, hand and discard at the game's end (a drained deck shows as a low one).
Cost (294): `lookahead_turns`, the turns the bot's lookahead forks played (most of a game's CPU).
Raids (375): `raids` (strikes), `raids_repelled`, `raid_strength_max`, and what pillages took: `raid_pop_lost`,
`raid_units_lost`, `raid_food_lost`, `raid_wealth_lost`.
Tiers (328): `tier_<id>` per settlement tier in the config (only with tiers on), how many settled territories, the home
one included, ended the game in that tier; they add up to the settled territories. They tell wide (many hamlets) from
tall (a few big ones).
Trends (379): `food_t<n>` and `wealth_t<n>`, the food and wealth held as turn n starts, every 10 turns
(`SimStats.TREND_EVERY`) up to the turn limit. They print as one `food by turn: 10 12.0, 20 22.5, …` line and one for
wealth (means) at the end of each block, and in `--compare` as `food by turn  Δ 10 +0.4, 20 -1.2, …` when a sample
moved. They show when the bot starts hoarding, which raids grow with (374).
The bot is fixed and simple, so read the numbers as *relative*: compare against `main`, not against a target.

It plays three strategies (`generic`, `wide`, `tall`; GenericBot.STRATEGIES, 314) as every listed civilization.
`scripts/sim.sh <seeds>` prints a block per strategy (its mean score per civilization, its raids per civilization
with repels and pop lost (375), then its metrics over all of them). That is 360 games at 20 seeds, and since the bot looks ahead (159, 240, 269) one 100-turn game costs 12–25 s of
CPU: about 2 CPU-hours, so 15–20 minutes on this machine. It runs on the performance cores but one (291; `SIM_PROCS=n`
to change). Only one parallel run at a time, across every checkout: a second one exits 1 at once with "another sim run
is using the CPU (pid N)". Wait for that run, don't start the two sides side by side. Each game's result is cached
by the code and data that played it (292), shared by every checkout: a side that hasn't changed since its last run
(usually `main`) reads every game back in seconds, and the header says how many came from the cache. `scripts/sim.sh <seeds> <strategy>` prints one table for that strategy
as the default civilization (seconds).

## Run it

1. Level: the argument, or 1 (378). Level 1 is one game (seed 1, generic, the config's starting civilization); 2 every
   strategy as that civ; 3 every strategy and civ, seed 1; 4 every strategy and civ, up to 10 seeds a cell. Level 4 is
   180 games a side (about an hour of CPU uncached); the user asks for it by name. Only when the user gives a seed
   count instead of a level, use `<max seeds>` in place of `--level <level>` below.
2. Make a `main` worktree without touching the working tree, compare against it from the checkout, then remove it:
   ```bash
   git worktree add --detach "$SCRATCH/balance-main" main
   (cd "$SCRATCH/balance-main" && godot --headless --path . --import >/dev/null 2>&1)
   scripts/sim.sh --compare "$SCRATCH/balance-main" --level <level>   # [--civ id] (levels 1-2) [--turns n]
   git worktree remove --force "$SCRATCH/balance-main"
   ```
   `--compare` (293) plays each seed × strategy × civ on both checkouts and pairs them. Each strategy × civ cell gets
   seeds in rounds of 5 until its score change is known to ±5% of main's mean score, or it reaches the level's seeds
   (1 at levels 1-3, so one paired game a cell: read its Δ as a hint, not a finding). A branch
   that changes no rule stops every cell at 5. Games already played by the same code and data come from the cache.
   Both checkouts need 293's `sim/`: if `main` predates it, copy `sim/` and `scripts/sim.sh` from the checkout into
   the worktree before running, and say so.
   Use the session scratchpad directory for `$SCRATCH`. Always remove the worktree, also when the run fails. If it
   exits 1, show its errors (each names its side) and stop.
   If the current branch *is* `main` with no changes, say so and show a plain `scripts/sim.sh --level <level>` table instead.
3. Show the report. It already is the table: per strategy, one line per civ (`main`, `this`, `Δ ±` the 95% interval,
   the change in %, seeds played; `!` past 10%), then each other metric whose mean moved, then the food and wealth
   trend changes (379). Then two or three sentences
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
