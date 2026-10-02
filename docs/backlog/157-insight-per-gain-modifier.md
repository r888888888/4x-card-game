---
id: 157
title: Theocracy slows research: an insight-per-gain modifier
type: feature
status: review
branch: feat/157-insight-per-gain-modifier
---

## Goal
Theocracy stops being the obvious government. Under it every source of insight yields 1 less, so the stability and
VP it gives cost research. From `spike/revolution`.

## Acceptance criteria
- [x] AC1: Modifier key `insight_per_gain` joins `DataLoader.MODIFIER_KEYS` (non-zero int, like the others). A card
  with `{"insight_per_gain": -1}` loads and its text adds "Each insight gain −1." (+1: "Each insight gain +1.").
- [x] AC2: Given a ruling government with `insight_per_gain` −1, when a card gains 3 insight (play or upkeep), then
  insight rises by 2; a gain of 1 adds 0. The play outcome's `gained` and the log report what was added.
- [x] AC3: Given modifiers −1 and −1 from two cards, a gain of 3 adds 1. `gain_per_tag`, `gain_per_keyword` and
  `trade` count as one gain each (the modifier applies once to their total).
- [x] AC4: `upkeep_forecast()`'s insight reflects the modifier. Gains of other resources and losses of insight are
  unchanged.

## Out of scope
- Percentage modifiers to insight or tech costs (tried in the spike: rounding made −25% act like −50%).

## Design notes
- `Modifiers.INSIGHT_PER_GAIN`; applied in `EngineCore.gain` for insight only, never below 0.
- Content: Theocracy gets `"modifiers": {"insight_per_gain": -1}` (Manual check).

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_insight_per_gain_loads_with_its_text`, `test_insight_per_gain_validation` |
| AC2 | `test_a_gain_of_3_insight_adds_2_and_a_gain_of_1_adds_0`, `test_an_upkeep_gain_of_insight_is_lowered_too`, `test_the_log_reports_what_was_added` |
| AC3 | `test_two_modifiers_add_up`, `test_gain_per_tag_per_keyword_and_trade_are_one_gain_each` |
| AC4 | `test_the_forecast_reflects_the_modifier`, `test_other_resources_and_insight_losses_are_unchanged` |

## Manual check
- [ ] Real data: Theocracy's card text says "Each insight gain −1."; under it a Library's ⟳ +2 insight gives +1.

## Log
- 2026-10-01: Built (`Modifiers.INSIGHT_PER_GAIN`, applied in `EngineCore.gain`). The text has no trailing period
  ("Each insight gain −1"), like the other modifier lines. Real data: Theocracy −1. Red tests renamed two fixtures
  (Lecture, Reap) that clashed with TEST_CARDS' `study` and `harvest`.
- 2026-10-01: Specced from `spike/revolution`. Spike: −50% insight cost 2.5–4 techs a game; the bot still ruled
  Theocracy ~half the game (its 12-turn score lookahead undervalues research). Tuning waits for a balance item.
