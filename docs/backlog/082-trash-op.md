---
id: 082
title: trash op (remove a hand card from the game) and Winnow
type: feature
status: done
branch: feat/082-trash-op
---

## Goal
The player can thin their deck by removing weak starting cards (extra Scouts, surplus Farms) from the game. This
is the classic deckbuilder early-game choice: spend a turn now so later draws are stronger. It is the first
effect that targets a card in hand.

## Acceptance criteria
<!-- Rules criteria use TEST_CARDS plus a test action, e.g. `purge`: cost 1 food, effects [{"op": "trash"}]. -->
- [x] AC1 (trash): Given `purge` and a Scout in hand and 1 food, when `play_card(purge, scout_uid)`, then food is 0,
  the Scout is in the new zone `trashed`, is in no other zone, and `purge` is in `discard`.
- [x] AC2 (targets): Given `purge`, a Scout and a Farm in hand, then `valid_targets(purge)` is exactly the Scout and
  Farm uids. `purge` itself is never a target.
- [x] AC3 (errors): Given `purge` alone in hand, `play_error(purge)` is "There is no other card in hand to trash."
  and play refuses. Given `purge` with two other hand cards and no target, `play_error(purge)` is
  "Choose a card to trash.". A target that isn't in hand, or is `purge` itself, is refused with a non-empty
  `play_error`. In each case nothing changes (food, hand, zones).
- [x] AC4 (one target auto-picked): Given `purge` and one Scout in hand, when `play_card(purge)` with no target,
  then the Scout is trashed.
- [x] AC5 (never returns): Given a trashed Scout, when the deck runs out and the discard is shuffled into it, then
  the Scout is still in `trashed`. `GameState.copy()` (and so `fork()`) keeps the `trashed` zone.
- [x] AC6 (loader and text): `trash` takes no fields besides `op` and `trigger`. `"trigger": "upkeep"` is a load
  error (`upkeep_ok()` is false). A `trash` effect on a tech or an event is a load error (targeting effects are
  already refused there). The short text reads "Remove a card in hand from the game".
- [x] AC7 (content): the real data has an `action` `winnow` with a `trash` effect, in an unlocked supply pile.

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
- Planned content (Manual check): `winnow`: action, cost 1 food, trash. Supply price 2, count 2.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_trash::test_trash_moves_the_target_to_trashed`, `::test_trash_outcome_names_the_trashed_card` |
| AC2 | `test_trash::test_valid_targets_are_the_other_hand_cards` |
| AC3 | `test_trash::test_trash_with_no_other_hand_card_is_refused`, `::test_trash_with_several_choices_needs_a_target`, `::test_trash_refuses_itself_or_a_card_not_in_hand` |
| AC4 | `test_trash::test_the_only_other_hand_card_is_picked` |
| AC5 | `test_trash::test_trashed_card_is_not_reshuffled`, `::test_fork_copies_the_trashed_zone` |
| AC6 | `test_trash::test_trash_loads`, `::test_trash_validation`, `::test_trash_card_text`, `test_forecast::test_ops_that_change_more_than_the_forecast_restores_are_rejected_on_upkeep` (row added to `UPKEEP_UNSAFE`) |
| AC7 | `test_content::test_winnow_trashes_and_is_on_sale`; changed: `test_every_supply_pile_starts_in_the_deck_or_is_unlocked_by_a_tech` → `test_every_locked_supply_pile_is_unlocked_by_a_tech` (an unlocked pile needs no deck copy) |

## Manual check
Run `godot --path .`, start any seed, open Buy Cards and buy a Winnow (2 wealth), then draw it.
- [ ] Double-click Winnow with 2+ other cards in hand: the other hand cards light up. Clicking one removes
  it (animated off the table). Esc cancels. Keyboard targeting works the same way.
- [ ] Dragging Winnow onto a hand card trashes it.
- [ ] The log prompt reads "Choose a card to trash. Click one (or ←/→ then Enter); Esc cancels." and a trashed card
  pops and floats up off the table (it doesn't fly to the discard). With reduce motion it fades in place.
- [x] Review the numbers with the `balance` skill (Log).

## Log
- 2026-09-29: Red at 574 tests (was 561), 15 failing. Fixture Purge is local to `test_trash.gd`, not in `TEST_CARDS`.
- Approved at red. The user renamed Rite of Passage to **Winnow** (id `winnow`) and approved relaxing the supply
  content test: an unlocked pile of any type may have no deck copy.
- Green: `trash_effect.gd`, `GameEngine.trash`, zone `trashed`, and `CardPlay.targets_of` leaves out the card being
  played. Winnow: cost 1 food, supply price 2, count 2, no deck copy.
- UI: targeting already lit any view in `views`, hand cards included. Dragging now drops on a lit hand card; the
  targeting prompt comes from `play_error` instead of "Click a territory…" (so settle and building prompts changed
  wording too); a trashed card pops and floats up. Smoke tests in `tests/test_trash_targeting.gd` (576 tests).
- Sim (20 seeds), main → this: unchanged (score 78.85, techs 12.20). The bot never buys from the supply, so it
  never has Winnow; a bot that trashes is out of scope.
