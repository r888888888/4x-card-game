---
id: 294
title: "Balance: make the bot's lookahead and the engine's hot path cheaper without changing results"
type: feature
status: in-progress
branch: feat/294-cheaper-bot-lookahead
---

## Goal
Halve what a sim game costs. Lookahead is about 95% of a game's CPU: seed 1 takes 12.2 s as baseline and 24.5 s as
wide, against 0.7 s and 1.6 s with lookahead off. Every `REVOLT_EVERY` (4) turns the bot copies the game 1 + (#
governments in the deck) times and plays `LOOKAHEAD_TURNS` (12) turns in each copy. It also looks ahead at every
government choice and every event choice (159, 240, 269). The engine itself is slow too, at about 7–15 ms a turn with
lookahead off, and every lookahead turn pays that again.

This is the dedicated balance item for that work. It has two parts:
- speedups that change no game;
- cheaper lookahead settings, chosen by measuring them with 293's comparison against today's bot, so the sim stays
  meaningful.

## Acceptance criteria
- [ ] AC1: The sim reports a per-game metric `lookahead_turns`: the turns played inside lookahead copies. Given a
  fixture game in which the bot weighs one revolution, with 2 governments in the deck and 12+ turns before the end,
  then `lookahead_turns` is 3 × `LOOKAHEAD_TURNS`. Given a fixture game with no government deck and no choice events,
  it is 0.
- [ ] AC2: The behaviour-neutral speedups (engine hot path, bot bookkeeping such as reading `pending()` once per step)
  change no game. `scripts/sim.sh --compare <the AC1 commit's worktree>` stops every cell at 5 seeds with Δ 0 ±0, and
  prints no metric line. The main suite passes with no test changed.
- [ ] AC3: Every bot-rule test that pins the revolution cadence or the lookahead horizon names
  `ScriptedBot.REVOLT_EVERY` / `LOOKAHEAD_TURNS` rather than the numbers 4 and 12, so a settings change can't silently
  break them. Where one hardcodes them now, that's a rename-only change, noted in the Log.
- [ ] AC4: If a pre-filter is adopted, one that skips a revolution's lookaheads when no government in the deck could
  beat the current one, then it gets its own rule criterion and fixture tests before it's built. Add them as
  AC4a, b, … at the red checkpoint, with the user's approval.

## Out of scope
- Changing what the bot values (the lookahead's score + insight value, 240) or its strategies.
- Tuning card or config numbers.

## Design notes
- **Measure first.** Profile one seed-1 `wide` game with timers around `take_turn`, `fork()`, `pending()`,
  `upkeep_forecast()`, `play_error` and the effect resolution. Record the top costs in the Log before changing
  anything. Candidates spotted while speccing:
  - `take_turn` calls `engine.pending()` up to 4 times a step;
  - `_play_first_playable` checks `play_error` for every card in hand on every step;
  - `fork()` copies the whole state, including zones a 12-turn copy never reads.
- **Settings to try** (Part 2), each compared against the AC2 commit with `scripts/sim.sh --compare`:
  - `REVOLT_EVERY` 4 → 8;
  - `LOOKAHEAD_TURNS` 12 → 8;
  - both;
  - the AC4 pre-filter.

  Adopt the cheapest that meets the Manual check bar. `lookahead_turns` and the CPU time show the saving.
- `lookahead_turns` is a counter on `ScriptedBot` that `SimStats._play_one` resets before each game and reads after it,
  like `_depth`. It's sim state, not game state.
- Depends on 293 (comparison) and 292 (cache).

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_bot_lookahead::test_weighing_a_revolution_plays_a_lookahead_for_staying_and_for_each_government`, `test_bot_lookahead::test_a_game_with_no_government_deck_and_no_choice_events_plays_no_lookahead_turns`, `test_sim::test_a_game_with_nothing_to_weigh_reports_no_lookahead_turns`, `test_sim_anarchy::test_lookahead_turns_counts_each_game_on_its_own`; `test_sim::test_sim_stats_reports_mean_min_max_per_metric` (its `METRICS` list gains `lookahead_turns`) |
| AC2 | the whole main suite, unchanged after the red commit; `scripts/sim.sh --compare` against the AC1 commit (manual) |
| AC3 | rename-only: `test_bot_lookahead::test_the_bot_revolts_every_revolt_every_turns_when_a_revolution_scores_more` (was `…_every_4_turns_…`), `…::test_the_bot_doesnt_weigh_a_revolt_in_the_last_half_lookahead`, `…::test_inside_a_lookahead_the_bot_never_revolts`, `…::test_a_lookahead_values_insight_at_1_point_per_4`, `test_sim_anarchy::test_a_revolution_counts_as_a_revolt_and_an_anarchy` |
| AC4 | deferred: only if Part 2's measurements favour the pre-filter (a second red checkpoint) |

## Manual check
- [ ] CPU per game, seed 1, real data, one process: baseline ≤ 6 s and wide ≤ 12 s (from 12.2 s and 24.5 s). Record
  before/after for each part.
- [ ] The adopted settings: in `--compare` against the AC2 commit, no strategy × civ cell has a `!` (|Δ score| > 10%).
  Every cell's Δ is within ±5% of main's mean score, or its CI includes 0. `gov_changes`, `anarchies` and `revolts` may
  move: note by how much.
- [ ] Record the shipped `REVOLT_EVERY` / `LOOKAHEAD_TURNS` and the full comparison report in the Log.

## Log
- 2026-10-05: specced from the sim-CPU discussion as the separate balance item. Measured on `main` (8b12303):
  seed 1 baseline 12.2 s / wide 24.5 s with lookahead, 0.67 s / 1.56 s with it off (`ScriptedBot._depth = 1`).
- 2026-10-05: red. AC3's renames (values unchanged with REVOLT_EVERY 4, LOOKAHEAD_TURNS 12): the cadence test takes
  turn REVOLT_EVERY (and REVOLT_EVERY − 1 for "not weighed"); the last-half test's turn limit is REVOLT_EVERY +
  LOOKAHEAD_TURNS ÷ 2 − 2 (8); the insight test expects 2 × LOOKAHEAD_TURNS ÷ INSIGHT_PER_POINT (6); 158's revolution
  game runs REVOLT_EVERY + LOOKAHEAD_TURNS turns (16) and expects Chiefs for REVOLT_EVERY turns and Glory for
  LOOKAHEAD_TURNS − 1; messages that said 12 or 36 now name the constants. `sim_game` in test_sim_anarchy now wraps a
  `sim_stats` helper taking seeds.

- 2026-10-05: spike `spike/fast-lookahead` (worktree `.claude/worktrees/prof-294`, `prof.gd` times one game and
  fingerprints it by score, turn and a hash of the log). Profiled seed 1 wide: a lookahead turn costs what a real
  turn costs (~30 ms), and 88% of the turns played are inside lookaheads. Fork itself is cheap (0.45 ms; copying the
  log is free, the ~400 card instances are the cost). The time went to O(tableau²) queries:
  - `Modifiers.working_cards` ran 58k times (163 µs): `total()` rebuilds it for every modifier query, and
    `smallest_with_room` asked `housing()` (so `total(housing)`) once per territory (~45 in wide).
  - `Territories.building_targets` scanned the tableau 4 times per territory (2.3 ms a call, 3 calls per building tried).
  - `_resolve` looked up the card's territory before checking it had effects for the trigger (274k calls).
  - Bot: `anarchy_ahead()` forecast before the cheap spend coin; one forecast per candidate card; `_buy_cheapest`
    priced each pile 3 times.
  Fixed each without changing a game (all 15 fingerprints, 5 strategies × seeds 1–3, identical; suite green): seed 1
  baseline 12.6 → 5.9 s, wide 24.8 → 7.2 s, one process. That alone meets the Manual check's CPU bar.
  Not worth it: deduping governments by id (the real deck never holds two of one); a lighter fork (10% left).
  Tried, behaviour-changing: back off a revolt weigh when the ruling government and deck are unchanged since a weigh
  that stayed (re-check every 3rd) — a further −29% CPU, but scores moved up to −21% (wide seed 3: 247 → 194).
  Recommendation: build the neutral speedups as AC2 and keep REVOLT_EVERY 4 / LOOKAHEAD_TURNS 12 unless the user
  wants more; settings and back-off then become optional, judged by `--compare`.
