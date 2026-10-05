---
id: 276
title: A growth card plays and is wasted when no territory has room to grow
type: bug
status: red-review
branch: fix/276-grow-card-with-no-room
---

## Reproduction
- Seed: any (no randomness involved)
- Steps:
  1. Grow every settled territory to its housing (e.g. the Homeland alone, at pop = housing).
  2. Play a card whose only play effect is `grow` with `where` `"best"` or `"each"` (Bread and Beer, Land Grants).
- Expected: the card can't be played; `play_error` says why, and the card stays in hand.
- Actual: the card is played (cost paid, action spent, card discarded) and adds no pop (`Population.add_pop` caps at
  housing, and `best_to_grow` returns null).

## Acceptance criteria
- [ ] AC1: Given population on, every settled territory at its housing, 50 food, and a card in hand whose only effect
  is `{"op": "grow", "amount": 1, "where": "best"}`, when I ask `play_error` for it, then it is non-empty (it says no
  territory has room to grow), and `play_card` returns false with the card still in hand, food 50 and actions unspent.
- [ ] AC2: Same as AC1 with `{"op": "grow", "amount": 1, "where": "each"}` (with and without `"count"`): blocked the
  same way.
- [ ] AC3: Given the same card and an active Famine while a territory still has room, then `play_error` is the
  Famine's growth error (`Famine.growth_error`) and the card can't be played.
- [ ] AC4: Given one settled territory below its housing (the others at housing), then `play_error` is "" and playing
  the card adds 1 pop to that territory (existing behaviour unchanged).
- [ ] AC5: Given a card whose play effects are a `grow` plus another op (e.g. `gain` 1 wealth) and no room to grow,
  then the card is still playable (the other effect isn't wasted): the block applies only when every play effect is
  a `grow` that would add nothing.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_growth_cards::test_bug_276_best_is_blocked_when_every_territory_is_full` |
| AC2 | `test_growth_cards::test_bug_276_each_is_blocked_when_every_territory_is_full` |
| AC3 | `test_growth_cards::test_bug_276_growth_is_blocked_during_a_famine` |
| AC4 | `test_growth_cards::test_bug_276_growth_plays_when_one_territory_has_room` |
| AC5 | `test_growth_cards::test_bug_276_a_card_with_another_effect_still_plays_with_no_room` |

## Design notes
- Hook: `GrowEffect.play_block_error` (the per-effect hook `CardPlay.error` already calls; `TradeEffect` uses it).
  "Nothing can grow" for "best"/"each" is `Population.smallest_with_room(e).is_empty()`; the famine case is checked
  first so its reason is shown.
- Out of scope (unchanged, existing tests cover them): population rules off (`grow` does nothing, card still
  playable: `test_grow_does_nothing_without_population`), and `"where": "here"` on a card with no territory
  (`test_grow_here_without_a_territory_does_nothing`); upkeep-triggered `grow` (Granary) isn't a play.
- The UI already greys out a card with a `play_error` and shows the reason; no UI change.
- `ScriptedBot` already skips growth cards that add no pop (`_growth_ok`); no bot change.

## Root cause

## Manual check
- With the Capital at its housing and no other territory with room, Bread and Beer in hand shows as unplayable with
  the reason in its tooltip.

## Log
- 2026-10-04: reported by the user ("a pop growth event when a city is maxed out just disappears and does nothing").
- Red: `test_best_does_nothing_when_it_cannot_grow` (261) played Bread when full and during a Famine and expected no
  pop; those cases now are blocked, so it keeps only its population-off case (renamed
  `test_best_does_nothing_without_population`). AC4 and AC5 pass already: they guard what must not change.
