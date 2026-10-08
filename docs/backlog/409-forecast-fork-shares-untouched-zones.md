---
id: 409
title: Forecasts fork only the zones they can change
type: feature
status: ready
branch: feat/409-forecast-fork-shares-untouched-zones
---

## Goal
`fork()` is 20–25% of GenericBot's time in the 2026-10-08 profile (real data, seeds 1–3): about 380 µs a fork, some
2.5 µs per card copied, in every zone, deck to removed (the log isn't a cost: dropping it changed nothing).
`turn_forecast()` and `upkeep_forecast()` fork the whole game but can only change some zones. Have them copy those and
share the rest with the game, so each forecast is cheaper and the sim faster, with every result unchanged.

Expected gain is modest and should be measured first: forecast forks are about 40% of the bot's forks (5.5k of 14k in
ten late-game turns; the rest apply candidate actions and need full forks), so if the shared zones hold half the
cards the gain is roughly 4–5% of bot time. Build 408 first: it is the larger win.

## Acceptance criteria
<!-- No rule changes. "Shared zones": the zones no forecast step (upkeep, feeding and the Famine, era unlocks, Anarchy's
fall and drain, raids) can change: deck, hand, territory_deck, frontier, reveal, offered. -->
- [ ] AC1: Given a game in progress, when a forecast's fork is made, then each shared zone is the game's own Zone
  object and every other zone is a new Zone whose cards are copies, in the same order with the same fields.
- [ ] AC2: Given positions where the forecast takes each path (an era unlock that moves future techs into the research
  deck, a declared revolution falling into Anarchy with a drain, a raid that strikes and sends a unit to the discard, a
  Famine that starves pop), when `turn_forecast()` and `upkeep_forecast()` are called, then they return what they
  return on `main` today: the numbers the existing forecast tests assert, which pass unchanged.
- [ ] AC3: Given each of those positions, when `turn_forecast()`, `upkeep_forecast()` and the 379/380 breakdowns are
  called, then the game is unchanged: every zone holds the same cards in the same order with the same fields
  (`CardInstance.copy`'s), and resources, state, log and `next_uid` are as before; nothing is emitted.
- [ ] AC4: Given a forecast's fork, when anything adds a card to or takes one from a shared zone, then the change is
  refused and reported (the test sees an error naming the zone), so a future forecast step that starts drawing can't
  quietly change the real game.

## Out of scope
- The candidate-action forks in GenericBot's `best_action` (actions draw, explore and take; they need full forks) and
  `sample_fork` (311).
- Copy-on-write zones in general.
- 408's `score()` work; Modifiers.total.

## Design notes
- Measure first: count cards per zone at turns 20, 40 and 60 on seeds 1–3 (a scratch script, a balance run's kind:
  ask before running). If the shared zones hold under a third of the cards, raise it at the red checkpoint before
  building.
- A `forecast_fork()` beside `fork()` (GameEngine), used by `TurnLoop.forecast` and `UpkeepBreakdown.ledger`;
  `GameState.copy` takes the zones to share. Zone gets a way to refuse changes on a fork (AC4): a `shared` flag that
  `add`, `remove` and `take_all` check, reporting through the engine's error path.
- A shared zone's cards are the game's own: nothing in a forecast may change a card's fields there either. Note in
  `Effect.upkeep_ok`'s doc that upkeep ops never touch those zones.
- Check `forecast_zones()` (336) and GenericBot's forecast cache key still read the same zones.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_…` |

## Manual check
- [ ] Sim speed against main, same games: `scripts/sim.sh --level 1 --compare <main checkout>`. Every metric matches
  exactly; the run is faster, by the share the measurement predicted.

## Log
