---
id: 109
title: Modifiers can change hand size (Greece draws up to 6)
type: feature
status: review
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

- [x] AC1 (loader): `hand_size` is a valid key in `DataLoader.MODIFIER_KEYS`. A card whose `hand_size` alone would
  take config `hand_size` above `hand_limit` (here, a value > 2) is a load error naming the card and
  `modifiers.hand_size`.
- [x] AC2: new query `hand_size() -> int` is config `hand_size` plus `modifier("hand_size")`, kept between 1 and
  `hand_limit`: 6 with the civilization, 7 with the civilization and the tech, 4 with only the event active, 5 with
  none.
- [x] AC3: with the civilization, the opening hand has 6 cards and the start-of-turn draw refills to 6.
- [x] AC4 (seed): the same seed deals the same deck order with or without the bonus (only the number drawn differs).
- [x] AC5 (text): a card with `modifiers: {"hand_size": 1}` has the text "Draw up to 1 more card each turn".

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
| AC1 | `test_hand_size::test_hand_size_is_a_modifier_key`, `test_a_hand_size_past_the_hand_limit_is_a_config_error` |
| AC2 | `test_hand_size::test_hand_size_adds_the_modifier_within_1_and_the_hand_limit` |
| AC3 | `test_hand_size::test_the_opening_hand_and_each_refill_draw_up_to_hand_size` |
| AC4 | `test_hand_size::test_the_same_seed_deals_the_same_order_with_or_without_the_bonus` |
| AC5 | `test_hand_size::test_hand_size_modifier_text` |

## Manual check
- [ ] As Greece (seed 1), the opening hand has 6 cards and each turn refills to 6; the hand row shows all 6 without
  overlapping (it scrolls past its width). Greece's card reads "Start: …Storyteller…" and "Draw up to 1 more card each
  turn", with no ⟳ +1 VP.

## Log
- The hand_limit check lives in `ConfigLoader` (card parsing can't see the config) and checks every card's own
  `hand_size`, so the error is "config.json: card 'x': modifiers.hand_size …".
- Card text now comes from `CardDef.MODIFIER_TEXT` (one gain and one loss phrase per key) instead of 129's nouns.
- AC4's first test draft compared hand + deck as listed; the deck's top is its last element, so the test now compares
  the draw order (my test bug, not the engine's).
- 2026-09-30: reworked onto 129's shared `modifiers` field (was a civilization-only `hand_size_bonus`), so techs,
  buildings, governments and events can change hand size too; noted how hand size plays with 127's actions.
