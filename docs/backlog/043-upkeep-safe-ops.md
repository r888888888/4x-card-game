---
id: 043
title: Only forecast-safe ops may trigger on upkeep
type: feature
status: draft
branch: feat/043-upkeep-safe-ops
---

## Goal
`upkeep_forecast()` runs the real upkeep effects and then restores only resources, bonus score and tableau pop.
An upkeep effect that moves cards, makes cards or uses the RNG would change the game every time the UI
refreshes. Nothing in the data does this today, but nothing stops it either. The loader should reject it.

## Acceptance criteria
- [ ] AC1: Given a building with `{"op": "draw", "amount": 1, "trigger": "upkeep"}`, when the cards load, then there
  is an error naming the file, card, effect and field: `cards.json: card 'x': effects[0]: 'draw' only works on
  play (got trigger 'upkeep')`, and the card is not in the result. The same holds for `create`, `explore`,
  `settle`, `add_era` and `research` (research's current message already has this form).
- [ ] AC2: Given a building with each of `gain`, `gain_per_tag`, `score` and `grow` on `upkeep`, when the cards
  load, then there are no errors or warnings.
- [ ] AC3: Given population on, Homeland with pop 2 (so neither building is idle) and housing 7, and a Temple (score +1 at upkeep) and a Granary
  (grow +1 here at upkeep) on it, when `upkeep_forecast()` is called, then `score()`, the Homeland's pop, every
  zone's uids and the log are the same afterwards as before.
- [ ] AC4: Given the shipped data, then it still loads with no errors or warnings.

## Out of scope
- A full `GameState` copy for the forecast (a later refactor; it would let any op run at upkeep).
- New triggers.

## Design notes
- New `Effect` hook, e.g. `func upkeep_ok() -> bool` (default `false`); `gain`, `gain_per_tag`, `score` and `grow`
  return `true`. `EffectRegistry.create` checks it once for every op, and `research_effect.gd`'s own check goes away.
- Update the `add-effect` skill: a new op that may trigger on upkeep must only change what `upkeep_forecast`
  restores (resources, bonus score, pop), and says so with `upkeep_ok()`.
- Update CLAUDE.md and PLAN.md (Forecast, card data format: which ops allow `upkeep`).

## Test plan
| AC | Test |
|---|---|
| AC1 | |
| AC2 | |
| AC3 | |
| AC4 | |

## Log
