---
id: 082
title: trash op (remove a hand card from the game) and Rite of Passage
type: feature
status: ready
branch: feat/082-trash-op
---

## Goal
The player can thin their deck by removing weak starting cards (extra Scouts, surplus Farms) from the game. This
is the classic deckbuilder early-game choice: spend a turn now so later draws are stronger. It is the first
effect that targets a card in hand.

## Acceptance criteria
<!-- Rules criteria use TEST_CARDS plus a test action, e.g. `purge`: cost 1 food, effects [{"op": "trash"}]. -->
- [ ] AC1 (trash): Given `purge` and a Scout in hand and 1 food, when `play_card(purge, scout_uid)`, then food is 0,
  the Scout is in the new zone `trashed`, is in no other zone, and `purge` is in `discard`.
- [ ] AC2 (targets): Given `purge`, a Scout and a Farm in hand, then `valid_targets(purge)` is exactly the Scout and
  Farm uids. `purge` itself is never a target.
- [ ] AC3 (errors): Given `purge` alone in hand, `play_error(purge)` is "There is no other card in hand to trash."
  and play refuses. Given `purge` with two other hand cards and no target, `play_error(purge)` is
  "Choose a card to trash.". A target that isn't in hand, or is `purge` itself, is refused with a non-empty
  `play_error`. In each case nothing changes (food, hand, zones).
- [ ] AC4 (one target auto-picked): Given `purge` and one Scout in hand, when `play_card(purge)` with no target,
  then the Scout is trashed.
- [ ] AC5 (never returns): Given a trashed Scout, when the deck runs out and the discard is shuffled into it, then
  the Scout is still in `trashed`. `GameState.copy()` (and so `fork()`) keeps the `trashed` zone.
- [ ] AC6 (loader and text): `trash` takes no fields besides `op` and `trigger`. `"trigger": "upkeep"` is a load
  error (`upkeep_ok()` is false). A `trash` effect on a tech or an event is a load error (targeting effects are
  already refused there). The short text reads "Remove a card in hand from the game".
- [ ] AC7 (content): the real data has an `action` `rite_of_passage` with a `trash` effect, in an unlocked supply pile.

## Out of scope
- Trashing from the discard pile or deck, or trashing more than one card.
- A trashed-cards viewer in the UI (the count can come later).
- Bot logic for choosing what to trash (the sim bot may simply never buy it).

## Design notes
- New op `trash` (follow the `add-effect` skill): `target_zone()` returns `"hand"`, with `no_target_error` /
  `choose_target_error` overridden with the messages in AC3.
- `CardPlay.targets_of` lists every card in the target zone, so for a hand target it must leave out the card being
  played. Do this in the generic path so that `play_error` and `valid_targets` agree.
- `CardPlay.play` removes the card from hand before resolving, so the target is still in hand when `trash`
  resolves. The target moves hand → `trashed` and goes in the outcome (e.g. `outcome.trashed = uid`) so the UI can
  animate it.
- Add `"trashed"` to `GameEngine.ZONES`. It is not in `CREATE_ZONES`.
- UI: hand cards must light up as targets when a `trash` card is dragged or double-clicked. Right now
  `drag_controller.gd` lights only board views. This is the only UI work, and it goes under Manual check plus a
  smoke test if one is cheap.
- Planned content (Manual check): `rite_of_passage`: action, cost 1 food, trash. Supply price 2, count 2.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_effects::test_…` |

## Manual check
- [ ] Double-click Rite of Passage with 2+ other cards in hand: the other hand cards light up. Clicking one removes
  it (animated off the table). Esc cancels. Keyboard targeting works the same way.
- [ ] Dragging Rite of Passage onto a hand card trashes it.
- [ ] Review the numbers with the `balance` skill.

## Log
