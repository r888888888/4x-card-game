---
id: 378
title: Sim levels 1–4 pick seeds, strategies and civs in one flag
type: feature
status: done
branch: feat/378-sim-levels
---

## Goal
A developer asks for a balance run by how deep it goes instead of spelling out seeds, strategies and civs:
`scripts/sim.sh --level N` (and `--compare <checkout> --level N`). Level 1 is the quick, common check (one game);
each level up widens the run, up to level 4 (10 seeds × every strategy × every civ).

| Level | Seeds | Strategies | Civs | Games (6 civs, 3 strategies today) |
|---|---|---|---|---|
| 1 | 1 (seed 1) | `GenericBot.STRATEGY` (generic) | the baseline civ | 1 |
| 2 | 1 (seed 1) | all `GenericBot.STRATEGIES` | the baseline civ | 3 |
| 3 | 1 (seed 1) | all | every listed civ | 18 |
| 4 | 10 (seeds 1–10) | all | every listed civ | 180 |

The baseline civ is the config's `starting.civilization` (egypt today), which the loader already checks is a listed
civilization, and which a game started with no civ already plays. `--civ <id>` replaces it at levels 1 and 2.

## Acceptance criteria
- [x] AC1: Given the test config (civilizations listed, `starting.civilization` set), when the sim's job list is built
  for level 1, then it is exactly one job: seed 1, strategy `GenericBot.STRATEGY`, civ = `starting.civilization`; and
  the run prints the single-strategy table (no per-strategy blocks).
- [x] AC2: Given the same config, when the job list is built for level 2, then it is one job per
  `GenericBot.STRATEGIES` entry (3), each seed 1 and civ = `starting.civilization`, in strategy order; and the run prints
  a block per strategy whose "score by civilization" names that civ's id (not "default").
- [x] AC3: Given a config with N listed civilizations, when the job list is built for level 3, then it has
  3 × N jobs, all seed 1, one per strategy × civ (report order: strategy, then civ); for level 4 it has 10 × 3 × N jobs,
  seeds 1–10 for each strategy × civ.
- [x] AC4: Given `--level 1 --civ sumer` (or `--level 2 --civ sumer`), then every job's civ is `sumer`. Given
  `--level 3 --civ sumer` or `--level 4 --civ sumer`, then the run exits 1 before playing, with an error saying levels 3
  and 4 play every civilization. `--turns n` works with every level as it does today.
- [x] AC5: Given `--level` with a value other than 1, 2, 3 or 4 (`0`, `5`, `x`, or no value), then the run exits 1
  before playing with an error naming the bad value and the allowed levels. Given `--level` together with a positional
  seed count or strategy (`scripts/sim.sh 20 --level 2`, `scripts/sim.sh --level 2 wide`), then it exits 1 with an
  error saying `--level` replaces them.
- [x] AC6: Given `--compare <checkout> --level N`, then the compare plays the same strategy × civ cells as AC1–AC4 on
  both sides, with the level's seed count as the most a cell gets: at levels 1–3 each cell plays exactly seed 1 on each
  side; at level 4 each cell plays rounds of 5 up to 10 seeds (stopping early as compare does today).
- [x] AC7: Given a config whose `starting.civilization` is `""`, when levels 1 or 2 are asked for without `--civ`, then
  the run exits 1 before playing with an error naming `starting.civilization` (and `--civ`); with `--civ <id>` it plays.
  (A civ of `""` with every strategy would mean every civilization in `job_list`, so level 2 can't fall back to it.)
- [x] AC8: Given Godot runs a script (`--script`, as the sim does), when the `Game` autoload reads its launch options,
  then it reads none: `--level 2 --civ sumer` gives no error and no civ. Given the game itself, `--civ sumer` still
  starts as Sumer and `--level` is still an unknown option.

## Out of scope
- New metrics or report formats; levels only choose which games run.
- Changing what a run with no `--level` does (`scripts/sim.sh [seeds] [strategy] [--civ id]` stays as is).
- Any balance run as part of this item (manual; see Manual check).

## Design notes
- No data format change: the baseline civ is `starting.civilization`, already in `data/config.json` and validated by
  `ConfigLoader` (it must be in `civilizations`).
- Levels map onto `SimStats.job_list(config, seed_count, strategy, only_civ)`; levels 1–2 pass the baseline civ's id
  explicitly so reports name it. That gives them a different cache key (292) from a plain `sim.sh 1 generic` run (civ
  `""`) for the same game: one replay, then cached.
- Parsing: `--level` is sim-only, so it belongs with the sim (e.g. a `SimStats.level_options(level, civ, config)` →
  `{seeds, strategy, civ}` or an error), not in `LaunchOptions`, which the game shares. `run.gd` and parallel workers
  must agree on the job list, so the children get the resolved seeds/strategy/civ.
- Docs: `scripts/sim.sh` header, `sim/run.gd` doc comment, the `balance` skill (`/balance [level]`, compare at that
  level; level 1 as the default since it is the common check), CLAUDE.md's Commands line, and the sim row in
  `docs/testing.md` (at its size cap: trim to fit).

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
All in `tests/test_sim_levels.gd`, on `SimLevels.run_args(args, config)` and `SimStats.job_list` of its result.

| AC | Test |
|---|---|
| AC1 | `test_level_1_is_one_game_of_the_baseline_strategy_as_the_baseline_civ`, `test_a_level_1_run_prints_one_table` |
| AC2 | `test_level_2_is_seed_1_of_every_strategy_as_the_baseline_civ`, `test_a_level_2_run_names_the_baseline_civ_in_each_strategy_block` |
| AC3 | `test_level_3_is_seed_1_of_every_strategy_as_every_civ`, `test_level_4_is_seeds_1_to_10_of_every_strategy_as_every_civ` |
| AC4 | `test_civ_replaces_the_baseline_civ_at_levels_1_and_2`, `test_civ_is_refused_at_levels_3_and_4`, `test_turns_work_with_a_level` |
| AC5 | `test_a_level_other_than_1_to_4_is_refused`, `test_a_level_with_a_seed_count_or_strategy_is_refused` |
| AC6 | `test_a_compared_level_gets_its_seed_count_as_the_most_a_cell_plays` (the paired run itself: Manual check) |
| AC7 | `test_levels_1_and_2_need_a_baseline_civ` |
| AC8 | `test_launch_options::test_378_the_game_reads_no_options_when_godot_runs_a_script` |
| (unchanged) | `test_without_a_level_the_seed_count_and_strategy_are_positional` |

## Manual check
- [ ] `scripts/sim.sh --level 1` prints one game's table as egypt in seconds; `--level 2` prints three strategy blocks
  for egypt; `--level 3` 18 games; `--level 4` 180 games (about 1 CPU-hour, so several minutes).
- [ ] `scripts/sim.sh --compare <main worktree> --level 2` pairs 3 cells at 1 seed each.

## Log
- Red: AC7 changed from "plays with civ ''" to an error: `job_list` reads civ "" with every strategy as every
  civilization, so level 2 had no way to play the no-civ start.
- Green: `sim.sh --level 2` printed "ERROR: unknown option --level" from the `Game` autoload, which also parses the
  command line under `--script`. Added AC8 (`LaunchOptions.for_game`).
- Docs: README, sim.sh header, CLAUDE.md Commands, PLAN.md, the balance skill (`/balance [level]`, default 1). Not yet
  run on the real data: see Manual check.
