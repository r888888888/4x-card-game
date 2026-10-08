---
id: 400
title: A strength modifier - +N strength to every working unit
type: feature
status: ready
branch: feat/400-strength-modifier
---

## Goal
Military play has no card that makes the whole army stronger: a unit's strength is its printed strength, its training
and its veteran counters (164, 165). Add a standing modifier `strength` (like `housing` or `administers`) that adds to
every working unit's strength while its card works. The Warlords claimants (404) use it for their court passive; any
later building, tech or event can too.

## Acceptance criteria
Fixtures are `tests/lib/raid_case.gd`'s: Levy (unit, strength 2) stationed on the home territory.

- [ ] AC1 (it adds): Given a working building in the tableau with `"modifiers": {"strength": 1}`, `military.strength`
  of the Levy is 3 and the home territory's `defense_parts().units` is 1 higher than without it.
- [ ] AC2 (sources sum, and it works from anywhere a modifier works): Given that building and an active event with
  `"modifiers": {"strength": 1}`, the Levy's strength is 4; with a researched tech carrying `strength: 1` instead of
  the event, also 4. A negative total never brings a unit below 0.
- [ ] AC3 (idle units get nothing): Given the Levy idle (its home's pop used up), its strength is 0 with or without the
  modifier, as today.
- [ ] AC4 (raids see it): Given a raid of strength 3 aimed at the home territory whose defence is 3 with the modifier
  (2 without), when it strikes the raid is repelled with the modifier and not without it.
- [ ] AC5 (loader and text): `strength` is a known modifier key (an integer, like the others); a card with
  `"modifiers": {"strength": 1}` has the generated text "+1 strength to your units." (and "−1 strength to your units."
  for −1).

## Out of scope
- Any card in `data/cards.json` using it (the Warlords claimants, 404).
- Strength for raids (the raid's own strength) or for idle units.

## Design notes
- `Modifiers.STRENGTH := "strength"`, listed in `DataLoader.MODIFIER_KEYS`, with its text entry.
- `Military.strength(uid)`: printed + training + counters + `e.modifier(Modifiers.STRENGTH)`, never below 0, 0 when idle.
- `strength_line` / `strength_tag` read `strength()`, so the unit's face shows the total; check the breakdown line names
  the modifier's part if it lists parts.
- `GenericBot` sees it through defence (raid outcomes in its rollouts).

## Test plan
| AC | Test |
|---|---|
| AC1 | |

## Manual check
- [ ] A unit's face and details show the raised strength.

## Log
