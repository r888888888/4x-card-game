---
id: 293
title: Compare two checkouts game by game, adding seeds only where the difference isn't clear yet
type: feature
status: ready
branch: feat/293-sim-paired-comparison
---

## Goal
A balance comparison with far fewer games and a clearer answer. Today the balance skill runs `main` and the branch
separately, 600 games each, and compares the two averages. Seed-to-seed noise hides small changes, so it takes many
seeds. Here the sim plays each game on both checkouts and compares them game by game. A game is a seed, strategy and
civ, and pairing cancels most of the noise. It plays seeds in rounds of 5 and stops a strategy × civ cell once its
score difference is known to ±5% of `main`'s score, or at 20 seeds. A branch that doesn't touch the rules stops
everywhere after the first round.

## Acceptance criteria
- [ ] AC1: `SimStats.cell_done(deltas, main_mean, max_seeds)` says whether a cell needs no more seeds. Its rule: the
  95% CI half-width of the deltas is t(n−1) × sd / √n, with t = 2.776, 2.262, 2.145, 2.093 for n = 5, 10, 15, 20. The
  cell is done when the half-width is at most the tolerance, max(5% of `main_mean`, 1 point), or when n ≥ `max_seeds`.
  - `[0, 0, 0, 0, 0]`, main mean 200 → done (half-width 0);
  - `[10, -10, 10, -10, 0]`, main mean 200, max 20 → not done (half-width 2.776 × 10 / √5 ≈ 12.4 > 10);
  - the same 5 deltas repeated 4 times (n = 20), max 20 → done (the maximum);
  - `[2, 3, 2, 3, 2]`, main mean 0 → done (tolerance 1 point; half-width ≈ 0.68).
- [ ] AC2: Given two sides with the same code and data (this checkout against itself), when `SimStats.compare` runs
  `all` strategies with `--turns 5` and max 20, then every strategy × civ cell stops after seeds 1–5 with Δ 0.0 ±0.0.
  It plays 5 games per cell on each side, or reads them from 292's cache.
- [ ] AC3: Given side B using a copy of `config.json` with `turn_limit` one more than side A's (no `--turns`; a
  `baseline`, `--civ sumer` comparison), when it runs with max 10, then the cell reports seeds 5 or 10. Its Δ mean
  equals the mean over the played seeds of (B's score − A's score) for the same seed. When it reports 10, seeds 6–10
  were played on both sides; when 5, they were played on neither.
- [ ] AC4: The report has a header naming both sides and the seed rounds. Then, per strategy:
  - a line per civ: `sumer  main 249.0  this 262.4  Δ +13.4 ±4.1 (+5.4%)  seeds 10`, with a `!` at the end when
    |Δ| is more than 10% of main's mean;
  - then each other metric whose Δ mean over that strategy's pairs isn't 0: `<metric>  main <mean>  this <mean>  Δ <Δ>`.

  A strategy where nothing moved prints its civ lines only.
- [ ] AC5: Given an other-side path with no `project.godot`, then compare returns code 1 and
  "not a checkout: <path>", playing nothing. Given a side whose data doesn't load, it returns code 1 and that side's
  loader errors, each prefixed with the side ("main: …" / "this: …"). An unknown strategy fails as `run_files` does.
- [ ] AC6: Given the same comparison run twice with the cache on, then the second plays 0 games and prints the same
  report.

## Out of scope
- Adaptive seeds in a plain `scripts/sim.sh` run: it keeps a fixed seed count (user's choice).
- Stopping as soon as the direction is certain: a cell stops on precision (±5%) only.
- Statistics on metrics other than score: they're reported as Δ means over the pairs the score rule played.
- Making the bot cheaper (294).

## Design notes
- **CLI.** `scripts/sim.sh --compare <path> [max seeds, default 20] [strategy, default all] [--civ id] [--turns n]`.
  `<path>` is the baseline ("main") checkout, and this checkout is "this". `LaunchOptions` gains `--compare <path>`
  (or `sim/run.gd` strips it before parsing, like 152's child tokens; choose whichever keeps the game's launch options
  clean).
- **Sides.** A side is `{root, cards, config}`: an absolute project root plus data paths. Games for a side whose root
  isn't this project run in workers started with `--path <root>`, so they run that checkout's code. That needs
  `procs` ≥ 2. With `procs` 1, compare accepts only sides whose root is this project, which is enough for the tests
  (AC2, AC3 vary only the data). The cache key (292) uses each side's own `source_hash(root)`, so `main`'s games are
  usually cached already.
- **Rounds.** Every cell starts at seeds 1–5. After each round, the cells not `cell_done` get the next 5 seeds, on both
  sides, as one batch on 291's queue. Seeds always run in order from 1, so a run is deterministic and its games hit the
  cache next time.
- The pair is by `[seed, strategy, civ]`. Δ = this − main. Percentages are of main's mean over the same played seeds.
- Holds 291's lock for the whole comparison.
- **Balance skill.** Rewrite step 3–4: make the `main` worktree, run `scripts/sim.sh --compare <worktree>` from the
  checkout, show its report (it is the table), then remove the worktree. Keep the plain-run instructions for
  `scripts/sim.sh <seeds> <strategy>` quick checks. The skill's "flag > 10%" rule is now the report's `!`.
- Builds on 291 (queue, lock) and 292 (cache).

## Test plan
| AC | Test |
|---|---|
| AC1 | |

## Manual check
- [ ] On a branch that only touches `ui/`: `scripts/sim.sh --compare <main worktree>` stops every cell at 5 seeds.
  Note the wall time.
- [ ] On a data change that moves one strategy (e.g. a cost tweak): only some cells go past 5 seeds. Note games played
  vs 1,200 for the old two-run comparison.

## Log
- 2026-10-05: specced from the sim-CPU discussion. User chose: adaptive seeds in the comparison only; stop at ±5% of
  main's mean score, 5–20 seeds.
