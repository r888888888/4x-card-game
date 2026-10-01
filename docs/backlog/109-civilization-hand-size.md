---
id: 109
title: Modifiers can change hand size (Greece draws up to 6)
type: feature
status: ready
branch: feat/109-modifier-hand-size
---

## Goal
A civilization (or later a tech, building, government or event) can raise the hand you draw up to each turn. Greece
(philosophers, playwrights, historians) draws up to 6. Builds on 129's `modifiers` field as a second key,
`hand_size`, instead of a civilization-only `hand_size_bonus`.

With the action economy (127) a bigger hand means more choice, not more tempo: you still play only as many cards as
you have actions, and the refill draws back only what you played. So the bonus mostly helps the opening hand and
lets you hold a card for later without clogging the hand.

## Acceptance criteria
Fixtures: TEST config `hand_size` 5, `hand_limit` 7; a test civilization with `modifiers: {"hand_size": 1}`; a test
tech with `modifiers: {"hand_size": 1}`; a test event with `modifiers: {"hand_size": -1}`.

- [ ] AC1 (loader): `hand_size` is a valid key in `DataLoader.MODIFIER_KEYS`. A card whose `hand_size` alone would
  take config `hand_size` above `hand_limit` (here, a value > 2) is a load error naming the card and
  `modifiers.hand_size`.
- [ ] AC2: new query `hand_size() -> int` is config `hand_size` plus `modifier("hand_size")`, kept between 1 and
  `hand_limit`: 6 with the civilization, 7 with the civilization and the tech, 4 with only the event active, 5 with
  none.
- [ ] AC3: with the civilization, the opening hand has 6 cards and the start-of-turn draw refills to 6.
- [ ] AC4 (seed): the same seed deals the same deck order with or without the bonus (only the number drawn differs).
- [ ] AC5 (text): a card with `modifiers: {"hand_size": 1}` has the text "Draw up to 1 more card each turn".

## Out of scope
- Changing `hand_limit`.
- Mid-turn effects: a hand-size change from a card played this turn applies at the next draw (there's no draw
  mid-turn to change).

## Design notes
- Needs 129 (the `modifiers` field and `Modifiers.total`). `TurnLoop` draws up to `e.hand_size()` instead of
  `config.hand_size`.
- Content after this item: Greece gets `modifiers: {"hand_size": 1}` and drops its ⟳ +1 VP, keeping the
  Storyteller.

## Test plan
| AC | Test |
|---|---|

## Manual check
- [ ] As Greece, each turn starts with 6 cards; the hand UI fits them.

## Log
- 2026-09-30: reworked onto 129's shared `modifiers` field (was a civilization-only `hand_size_bonus`), so techs,
  buildings, governments and events can change hand size too; noted how hand size plays with 127's actions.
