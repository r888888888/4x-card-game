---
id: 310
title: Ask what a card would target from any zone, not only the hand
type: feature
status: ready
branch: feat/310-targets-from-any-zone
---

## Goal
The generic bot (313) values its deck by what each card could do now. A card with nothing to act on (a settler and no
frontier, a building and no free slot) is worth nothing yet, and exploring is worth what it gives such a card. Today
`needs_target` and `valid_targets` answer only for hand cards, so the spike read `CardPlay` and `Territories`
internals. After this, the engine says what any card would target if it were in the hand.

## Acceptance criteria
- [ ] AC1: Given a Farm in the deck and the homeland with a free slot, then `would_need_target(farm)` is true and
  `would_target(farm)` is `[homeland uid]`, what `valid_targets` returns for a Farm in the hand.
- [ ] AC2: Given a Pioneer (settle) in the discard and an empty frontier, then `would_target(pioneer)` is `[]`; after an
  Explorer is played and a territory chosen into the frontier, it is `[that territory's uid]`.
- [ ] AC3: Given a card in the hand, then `would_need_target` and `would_target` equal `needs_target` and
  `valid_targets` for it; for a Forager (no target) anywhere, `would_need_target` is false and `would_target` is `[]`.
- [ ] AC4: Given a uid in no zone, or the game over, then `would_need_target` is false and `would_target` is `[]`. Both
  queries change nothing (the card stays in its zone, nothing is logged or emitted).

## Out of scope
- Whether the card is affordable or allowed now (`play_error` stays the hand's answer).
- Changing `needs_target` or `valid_targets`, which the UI calls for hand cards.

## Design notes
- New queries on `EngineQueries`: `would_need_target(uid) -> bool` and `would_target(uid) -> Array[int]`, sharing
  `CardPlay.targets_of` with `valid_targets` (pass the card, not a hand lookup). Add both to `QUERIES` in
  `tests/test_engine_structure.gd`.
- A card in the reveal or frontier is the target, never the one targeting: the queries look up the card in any zone.
- Spike reference: `GenericBot.has_targets` on `spike/generic-bot`.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_targets::test_…` |

## Log
- 2026-10-05: specced from the generic-bot spike, with 309, 311–315.
