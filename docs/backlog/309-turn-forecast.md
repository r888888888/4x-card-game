---
id: 309
title: turn_forecast reports what starting the next turn changes, score and raids included
type: feature
status: ready
branch: feat/309-turn-forecast
---

## Goal
A bot that values positions (313) needs to know what the next turn's start will do to the game: not only the resources
`upkeep_forecast` reports, but score (upkeep `score` ops, pop lost to starvation), Anarchy's drain, an arriving era's
unrest and the raids that strike. Today the generic-bot spike (`spike/generic-bot`) gets this by calling `TurnLoop` and
`Population` internals on a fork. After this, `turn_forecast()` answers it from the engine, and announced raids count
without a rule written for them.

## Acceptance criteria
- [ ] AC1: Given a fixture game (`make_engine`) with a Temple (⟳ +1 score) on the tableau, enough food and no raid
  active, when `turn_forecast()` is called, then it returns `score` +1 and, for each resource, the same change as
  `upkeep_forecast()`, plus `pop` 0 and `starve` 0.
- [ ] AC2: Given food that leaves the next feeding 1 short with `vp_per_pop` 1, then `turn_forecast()` has `starve` 1,
  `pop` −1 and `score` −1 (the starved pop no longer scores).
- [ ] AC3: Given an announced raid that strikes at the next turn's start with strength 1 above its target's defence
  and `pop` 1, then the forecast includes the raid's loss: `pop` −1 and `score` −1 more than without the raid, and any
  resources its `pillage` effects take. Given the target's defence ≥ the strength, the raid's `repel` effects count
  instead.
- [ ] AC4: Given the techs that add era 2 learned so that era 2 arrives at the next turn's start, then the forecast's
  `unrest` includes the era's unrest (config `unrest.era_unrest`).
- [ ] AC5: The forecast changes nothing: after the call the game's state, log, zone orders and rng draw the same as
  before (a shuffle after the call gives the same order as one without it), no signal is emitted, and two calls in a
  row return equal results.
- [ ] AC6: On the last turn and after game over it returns `{}` (as `upkeep_forecast` does).

## Out of scope
- The cards the next turn draws and the event it draws (random; 311's sample fork is for that).
- Changing `upkeep_forecast` or what the top bar shows.

## Design notes
- New query on `EngineQueries`: `turn_forecast() -> Dictionary`, `{score, pop, starve, <resource>: change}`. It runs
  on a fork the start-of-turn steps that don't draw: `Sites.start_turn`, `Anarchy.before_upkeep`, `resolve_upkeep`,
  feeding, `Research.check_era_unlocks`, `Anarchy.start_of_turn`, `Anarchy.drain`, `Military.strike_raids`; it skips
  `draw`, `start_renewal` and `Events.draw`. Best done by splitting `TurnLoop.start_turn` so the forecast and the real
  turn share one list of steps.
- Add it to `QUERIES` in `tests/test_engine_structure.gd`.
- Spike reference: `GenericBot.income` on `spike/generic-bot` (upkeep and feeding only).

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_turn_forecast::test_…` |

## Log
- 2026-10-05: specced from the generic-bot spike, with 310–315.
