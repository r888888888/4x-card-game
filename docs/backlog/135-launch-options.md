---
id: 135
title: Command-line options for the civilization, turn limit and seed (game and sim)
type: feature
status: done
branch: feat/135-launch-options
---

## Goal
Playtesting one civilization or the early game means clicking through the title and New Game screens and playing
to turn 100. After this item `godot --path . -- --civ sumer --turns 20` starts a 20-turn game as Sumer straight away,
and `scripts/sim.sh 20 all --civ sumer --turns 15` runs the sim for one civilization over a short game.

## Acceptance criteria
- [x] AC1 (parse): `LaunchOptions.parse(args, civilizations)` reads `--civ <id>`, `--turns <n>` and `--seed <n>` and
  returns `{civ, turns, seed, positional, errors}`: e.g. `["20", "--civ", "sumer", "--turns", "15", "--seed", "5"]` →
  civ "sumer", turns 15, seed 5, positional ["20"], no errors. With no options: civ "", turns 0, seed -1.
- [x] AC2 (bad options): each of these gives one error naming the option and the value, and leaves that option at its
  default: an unlisted civilization (`--civ rome`; the error lists the valid ids), a turn count that isn't a whole
  number ≥ 1 (`--turns 0`, `--turns abc`), a seed that isn't a whole number ≥ 0, an option with no value
  (`--turns` last), and an unknown option (`--speed 2`).
- [x] AC3 (turn limit): `LaunchOptions.apply(engine, options)` with turns 7 makes `engine.turn_limit()` 7, so a game
  started on it ends after turn 7; with turns 0 the config's limit stays.
- [x] AC4 (start straight away): `LaunchOptions.starts_game(options)` is true when a civ or a seed was given, else
  false. The game, launched with such options, starts a game as that civ (the config's starting one when only a seed
  is given) with that seed (random when none), skipping the title and New Game screens; Restart keeps the turn limit.
- [x] AC5 (sim): `SimStats.run_files(cards, config, seeds, strategy, options := {})` plays games with `options.turns`
  as the turn limit, and with `options.civ` plays only that civilization: in "all" mode the report names only it, and
  a single strategy's table is played as it. `scripts/sim.sh [seeds] [strategy] [options]` passes the options on; any
  option error makes it exit 1 with the errors.

## Out of scope
- Other options (data paths, starting resources, a log file); Settings stay in the Settings screen.
- Changing the New Game screen.

## Design notes
- New `autoload/launch_options.gd` (`class_name LaunchOptions`, `RefCounted`, static functions): parse, apply,
  starts_game. No game rules in it; `apply` only overrides `engine.config.turn_limit`.
- `Game._ready` parses `OS.get_cmdline_user_args()` (the args after `--`) against the config's civilizations, prints
  errors with `push_error`, and applies the turn limit; `ui/main.gd` calls `start_game(seed, civ)` instead of the
  title screen when `LaunchOptions.starts_game` is true. The game ignores positional args.
- `sim/run.gd` reads seeds and strategy from `positional` (defaults 20 and all); `scripts/sim.sh` forwards `"$@"`.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_launch_options::test_parse_reads_civ_turns_seed_and_positional_args`, `test_parse_defaults_with_no_options` |
| AC2 | `test_parse_rejects_bad_options`, `test_bad_options_keep_their_defaults` |
| AC3 | `test_apply_sets_the_turn_limit`, `test_apply_without_turns_keeps_the_config_limit` |
| AC4 | `test_starts_game_with_a_civ_or_a_seed` (the UI start itself: Manual check) |
| AC5 | `test_sim_uses_the_turn_limit_option`, `test_sim_plays_only_the_civ_option`, `test_sim_plays_a_single_strategy_as_the_civ_option` |

## Manual check
- [ ] `godot --path . -- --civ sumer --turns 20` opens straight into a game as Sumer; the top bar shows 20 turns;
  Restart keeps 20.
- [ ] `godot --path . -- --seed 42` starts as the default civilization on seed 42; `godot --path .` still opens the
  title screen.
- [ ] `godot --path . -- --civ rome` prints an error listing the civilizations and opens the title screen.
- [ ] `scripts/sim.sh 5 all --civ sumer --turns 15` prints only Sumer; `scripts/sim.sh 5 baseline --turns 0` exits 1.

## Log
- User chose: options for both the game and the sim; `--civ` skips the title screen. `--seed` added as proposed in
  the question; a seed alone also starts a game.
- Green. The game ignores positional args instead of reporting them: scripts/test.sh passes its filter after `--`,
  which the Game autoload also sees, so an error there would print on every test run.
- In the sim an option error prints twice (run.gd's printerr, and the Game autoload's push_error, which also loads in
  --script runs). Cosmetic; left as is.
- Checked headless: `-- --civ sumer --turns 20` starts with no script errors; `--civ rome --turns 0` prints both errors;
  `scripts/sim.sh 3 all --civ sumer --turns 15` reports only Sumer; `--turns 0` exits 1.
