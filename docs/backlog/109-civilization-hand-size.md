---
id: 109
title: Civilizations can change hand size
type: feature
status: ready
branch: feat/109-civilization-hand-size
---

## Goal
A civilization can draw more cards each turn. Greece (philosophers, playwrights, historians) draws up to 6.

## Acceptance criteria
Fixtures: TEST config `hand_size` 5, `hand_limit` 7; a test civilization with `hand_size_bonus: 1`.

- [ ] AC1 (loader): civilization field `hand_size_bonus` is an optional int (default 0). A value < 0, or one that
  makes `hand_size` + bonus exceed `hand_limit`, is a load error naming the card and the field.
- [ ] AC2: new query `hand_size() -> int` returns config `hand_size` plus the civilization's bonus (6 here, 5 with no
  civilization).
- [ ] AC3: with the bonus, the opening hand has 6 cards and the end-of-turn draw refills to 6.
- [ ] AC4 (seed): the same seed deals the same deck order with or without the bonus (only the number drawn differs).

## Out of scope
- Changing `hand_limit`. Hand size from governments or techs.

## Design notes
- `TurnLoop` draws up to `e.hand_size()` instead of `config.hand_size`. Card text: "Draw 1 more card each turn."
- Content after this item: Greece gets `hand_size_bonus: 1` and drops its ⟳ +1 VP, keeping the Storyteller.

## Test plan
| AC | Test |
|---|---|

## Manual check
- [ ] As Greece, each turn starts with 6 cards; the hand UI fits them.

## Log
