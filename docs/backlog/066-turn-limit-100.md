---
id: 066
title: 100-turn games, with a balance pass
type: feature
status: review
branch: feat/066-turn-limit-100
---

## Goal
Play long enough for a civilization to grow (TODO 19). The game lasts 100 turns instead of 20. The content (territories,
techs, supply piles) and the thresholds are tuned so that the late game still has decisions.

## Acceptance criteria
<!-- Content item: rules already support any turn_limit (the loader reads it with min 1). -->
- [x] AC1 (rules, TEST_CARDS): With `turn_limit: 100`, the game ends after turn 100's end_turn, and
  `upkeep_forecast()` is `{}` on turn 100. This is the existing rule, rechecked at 100.
- [x] AC2 (content): the 20-seed scripted sweep plays full games on the real data with no runtime errors, and
  finishes within the suite's time budget. If needed, the sweep plays fewer turns and the sim covers full games.
- [x] AC3 (content): the real territory deck has enough territories for the bot to keep exploring past turn 40 (sim
  metric; the exact size is under Manual check).
- [x] AC4: the UI turn counter shows "Turn 37 / 100" without truncation (smoke test reads the label).

## Out of scope
- Era 3 content and new eras (a later item). If the late game is empty, record it here and spec the follow-up.

## Design notes
- Build last: every earlier item changes balance.
- `data/config.json`: `turn_limit: 100`, more territory copies, supply counts, and `era_unlocks` retuned.
- Use the `balance` skill: turns until the territory deck runs out, techs left unresearched at the end, and wealth or
  food left unspent. Record before and after in the Log.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_rules::test_a_100_turn_game_ends_after_turn_100_with_no_forecast_on_it` (regression guard: passes already) |
| AC2 | `test_content::test_scripted_sweep_over_20_seeds` (existing), on the 100-turn real data |
| AC3 | new sim metric `explored`: `test_sim::test_sim_stats_reports_how_long_the_territory_deck_lasted`; the value on the real data is recorded below from `scripts/sim.sh` |
| AC4 | `test_ui_smoke::test_the_turn_counter_shows_turn_37_of_100_untruncated` (regression guard: passes already) |

## Manual check
- [ ] Review the shipped numbers: `turn_limit` 100; `territory_deck` ×5 (55: plains, river_valley, lakeshore,
  floodplain_delta, bay, highlands, woodland, rainforest, dunes 5 each; hills 10); supply piles ×3 (6 each, Granary
  12; Monument, Forge and Library stay at 1); `era_unlocks` unchanged (era 2 at 8 pop or 15 wealth).
- [ ] Play to turn 60+: there are still meaningful choices each turn.

## Log
- 2026-09-29 (from 080): Barter (2 food → 2 wealth) raised the sim's score 61 → 77 and techs 7.75 → 12.00;
  try +1 wealth or a 3-food cost here. 065's governments aren't counted by the sim yet (a `governments` metric).
- 2026-09-30: Probe before any change (current content with `turn_limit` 100, seeds 1–10): the territory deck is empty by
  turn 10–15, the last city is founded by turn 12–20, the last of the 13 techs is bought by turn 15–21, and
  620–1550 food and 590–1710 wealth are left unspent at turn 100. Pop stays at 13 of 46 housing: the sim bot never
  grows pop and never buys from the supply, so the sim can't measure either. The user chose to ship 100 turns now
  and record the thin late game as a follow-up.
- 2026-09-30: Red. `test_sim`'s METRICS list gains `explored` (an approved test's expectation, changed for the new
  metric).
- 2026-09-30: Green. New sim metric `explored` (turns the territory deck lasted). Balance, 20 seeds:

  | metric | before (20 turns, 11 territories) | after (100 turns, 55 territories, piles ×3) |
  |---|---|---|
  | score | 79.80 (60–99) | 440.00 (370–559) |
  | cities | 11.00 (11–11) | 55.00 (55–55) |
  | pop | 13.00 (13–13) | 57.00 (57–57) |
  | techs | 12.25 (12–13) | 12.30 (12–13) |
  | bought | 0 | 0 |
  | era | 2 | 2 |
  | explored | 12.30 (9–16) | 49.85 (42–54) |

  AC3: the deck lasts past turn 40 in every seed (×4 gave 41.55, min 36; ×5 chosen). Supply counts and
  `era_unlocks` can't be judged by the sim (the bot never buys or grows pop); tripled / unchanged by reasoning.
- 2026-09-30: The suite went 8 s → 51 s: the UI tests play seed 1 through the real main scene. `play_seed_1` now cuts
  the real game to 20 turns (`SEED_1_TURNS`; `close_main` restores the limit), so the suite is back to ~10 s and no
  approved test changed; `test_content`'s 20-seed sweep still plays full 100-turn games (AC2).
- 2026-09-30: The late game is still thin: all 13 techs are bought by turn ~20 and cities by ~turn 50, then
  nothing new happens; food and wealth pile up (the bot can't spend them). Follow-ups to spec: era-3 techs into the
  research deck (they exist in cards.json) or new eras; a sim bot that grows pop and buys from the supply, so balance
  items can see those numbers; the 080 note on Barter still stands. Per the new rule (balance is a separate step),
  these go to a dedicated balance item.
