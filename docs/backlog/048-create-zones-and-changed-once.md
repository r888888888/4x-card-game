---
id: 048
title: create can target any zone; discarding down to the hand limit emits changed twice
type: bug
status: draft
branch: fix/048-create-zones-and-changed-once
---

## Reproduction
- Seed: 1
- Steps:
  1. Load a card with `{"op": "create", "card": "farm", "zone": "research_reveal"}`: it loads with no error.
     Playing it puts a Farm in `research_reveal`, which opens a "research" choice with a Farm as the option.
  2. `make_engine({"scout": 10}, {"hand_limit": 5})`, play a Scout (hand 6), `end_turn()` (discard 1 owed), then
     `discard_card` one card: `changed` is emitted twice (once by `_finish_turn`, once by `discard_card`).
- Expected: `create` only targets zones where a new card makes sense; each action emits `changed` once.

## Acceptance criteria
- [ ] AC1: Given a card with a `create` effect whose `zone` is `research_reveal` (also `reveal`, `frontier`,
  `territory_deck`, `research_deck`, `researched`, `lost_techs`, `future_techs`), when it loads, then the error is
  `card 'x': effects[0]: 'zone' must be one of: tableau, hand, discard, deck (got 'research_reveal')`.
- [ ] AC2: `create` into `tableau`, `hand`, `discard` and `deck` still loads and works; the real data still loads.
- [ ] AC3: Given the step 2 setup, when the last owed card is discarded, then `changed` is emitted exactly once.
- [ ] AC4: Each successful action (`play_card`, `choose`, `grow`, `buy`, `buy_tech`, `decline_research`,
  `discard_card`, `end_turn`) emits `changed` exactly once, and a refused one emits none.

## Root cause
<!-- Filled in after the fix. -->

## Log
