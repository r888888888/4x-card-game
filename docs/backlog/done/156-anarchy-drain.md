---
id: 156
title: Anarchy eats into stored food and wealth
type: feature
status: done
branch: feat/156-anarchy-drain
---

## Goal
Anarchy costs the economy something you can see: each turn it rules, a share of your stored food and wealth is lost
to disorder. Stockpiles become insurance against revolution. Replaces the Anarchy card's ⟳ −1 pop. Follows 155.
From `spike/revolution`.

## Acceptance criteria
- [x] AC1: Config `unrest.drain_pct` is optional (absent = 0, no drain); an integer from 0 to 100, otherwise the load
  error `unrest.drain_pct: must be an integer from 0 to 100`.
- [x] AC2: Given drain 20 and a turn that starts under Anarchy (after any fall that turn, before the draw) with
  10 food and 7 wealth after upkeep and feeding, then 2 food and 2 wealth are lost (20%, rounded up), with a log line
  naming Anarchy. With 0 food nothing is lost. Insight and other resources are untouched.
- [x] AC3: Given no Anarchy at the turn's start, nothing is drained, also with drain 20.
- [x] AC4: `upkeep_forecast()` includes the drain (on the forecast's stores after upkeep and feeding) when Anarchy will
  rule next turn: a revolution is pending, or Anarchy rules with 2+ counters left.

## Out of scope
- Shutting off income under Anarchy: the spike measured it as about as costly as the drain alone, and stacking both
  added little; not taken up.

## Design notes
- `Anarchy.drain(e)`, called by `TurnLoop.start_turn` after `Anarchy.start_of_turn`. Uses `lose`, so it never goes
  below 0.
- Content: config `unrest.drain_pct` 20; the Anarchy card loses its `lose_pop` upkeep effect, and its hand-written
  text says "Each turn it eats 20% of stored food and wealth." (Manual check).

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_drain_pct_loads_and_is_optional`, `test_drain_pct_validation` |
| AC2 | `test_a_turn_under_anarchy_loses_a_share_of_food_and_wealth`, `test_nothing_is_lost_from_empty_stores` |
| AC3 | `test_no_drain_without_anarchy`, `test_no_drain_with_drain_0` |
| AC4 | `test_the_forecast_includes_the_drain_when_a_revolution_is_pending`, `test_the_forecast_includes_the_drain_while_anarchy_has_2_counters_left`, `test_the_forecast_has_no_drain_without_anarchy_ahead` |

## Manual check
- [ ] Real data: drain 20; Anarchy no longer costs pop each upkeep; the top bar's food and wealth forecasts show the
  drain during a multi-turn Anarchy.

## Log
- 2026-10-01: Built on 155's branch (`Anarchy.drain`, `drain_of`, `rules_next_turn`). At green, the AC4 tests' expected
  value was computed from the no-drain twin's stores, but the drain game had already lost 20% on the fallen turn; the
  helper now uses each game's own stores (same assertion). Real data: drain 20, Anarchy's ⟳ −1 pop gone.
- 2026-10-01: Specced from `spike/revolution`. Spike: drain 20% alone scored within ~4% of income shut off alone; famine
  turns barely moved, since Anarchy averages ~2 turns.
