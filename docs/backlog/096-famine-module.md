---
id: 096
title: Famine rules in one module
type: feature
status: done
branch: feat/096-famine-module
---

## Goal
The Famine (083) is spread over four places:
- `Population` (`famine()`, and `feed` creating and escalating it);
- a special case in `Events.resolve_upkeep`;
- a transient `_famine_guards` field on `GameEngine`, which the generic `lose_pop` op checks;
- `GameEngine.event_counters` / `famine_counters`.

084 (relieve a Famine with wealth) and later famine content would add to all of them. Give the Famine one module,
`engine/famine.gd`, before 084, and keep the public API and every behavior as they are.

## Acceptance criteria
- [x] AC1: `engine/famine.gd` (`class_name Famine`, static functions like the other modules) owns:
  - finding the active Famine;
  - bringing one or adding a counter (up to `max_counters`) on a hungry upkeep;
  - resolving its upkeep once per counter, with guard saves;
  - ending it when pop is fed;
  - the growth block used by `grow_error` and `add_pop`.

  `Population.feed` keeps eating food and hands the result (fed or short) to `Famine`.
- [x] AC2: `GameEngine` has no Famine-specific field (`_famine_guards` is gone), and `Population.lose_pop` has no
  famine-guard branch. A guard's save still logs "`<territory>`: 1 pop saved from famine." and saves the same
  deaths, which `test_famine_guard` checks.
- [x] AC3: `Events.resolve_upkeep` asks `Famine` whether an active event is the Famine, and `event_counters` /
  `famine_counters` delegate to `Famine`. `population.gd` holds no Famine rules beyond the call in `feed`.
- [x] AC4: Every existing test passes unedited: `test_famine`, `test_famine_guard`, `test_food_upkeep`,
  `test_forecast`, `test_harmful_ops`, `test_event_panel`.
- [x] AC5: `scripts/sim.sh 20` output is identical before and after, and so is a per-seed dump of `log_lines` and
  `upkeep_forecast()` for seeds 1–5 (scratch script, as in 051).

## Out of scope
- Relief (084), and any change to how the Famine plays.
- Renaming or removing `famine_counters()`: 084's criteria use it.

## Design notes
- The guard budget has to live somewhere while the Famine's counters resolve. The options:
  - `Famine` resolves each death itself: it picks the territory with `Population.most_pop`, checks and spends the
    guard, and otherwise calls `lose_pop` for 1. This needs the Famine card's upkeep effects to stay "lose_pop
    amount 1", which the loader could check.
  - It keeps the budget on the Famine's `CardInstance` during resolution, with `lose_pop` asking
    `Famine.save(e, territory, source)` only when `source` is the Famine.

  Pick one at the red checkpoint. The first keeps `lose_pop` fully generic.
- After this lands, 084's design note ("rules in `Population` next to `feed`") should read "in `Famine`". Update it
  when 084 is picked up; this item doesn't edit 084.

## Test plan
| AC | Test |
|---|---|
| AC1–3 | checked by grep (`_famine_guards`, `famine` in `population.gd`, `events.gd`, `game_engine.gd`) |
| AC4 | the existing suite, unedited |
| AC5 | `scripts/sim.sh 20` and the scratch dump diffed against `main` |

## Log
- 2026-09-30: Specced from the project review (Famine scattered across four places). Before 084 (review decision:
  refactors first).
- 2026-09-30: Guard design (chosen with the user): `Famine.after_feeding` keeps the guard budget local. For each
  counter it looks at `Population.most_pop`; a guard there saves that death (same log line) and the counter's upkeep
  effects are skipped, otherwise the Famine card's upkeep effects resolve. `lose_pop` is fully generic again. Same
  behavior with today's cards (one `lose_pop` amount 1); an amount-2 effect would get one save per counter.
- 2026-09-30: Done. 626 tests pass unedited. `scripts/sim.sh 20` and a scratch dump (log lines and every
  `upkeep_forecast()` for seeds 1–5 on the real data, and again with `food_upkeep` 2 to force Famines) are identical
  before and after. `population.gd` 164 → 123 lines, `famine.gd` 70, `game_engine.gd` 649 → 646.
