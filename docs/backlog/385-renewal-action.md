---
id: 385
title: Renewal is a free action during Anarchy
type: feature
status: ready
branch: feat/385-renewal-action
---

## Goal
Today renewal (147, 255) is a decision Anarchy forces on you at each turn's start: trash `renewal` + (its turn − 1) +
the renewal modifier cards, each calming 1 unrest, before anything else. With [384](384-simpler-anarchy.md) Anarchy
lasts a fixed 3 turns and unrest drops to 0 when it ends, so calming during it means nothing. Make renewal a plain
opportunity: during Anarchy you may trash up to `renewal` + the renewal modifier cards each turn, from your hand, deck or
discard (not a government), at any time, for no action and no change to unrest. The ramp (+1 per turn so far) goes: it
pushed you out of a long Anarchy, and a fixed one needs no push.

Builds on 384.

## Acceptance criteria
Fixtures are `tests/lib/anarchy_case.gd`'s, with `unrest.renewal: 1`.

- [ ] AC1 (an action, not a decision): Given Anarchy on its first turn with 3 unrest, when the turn starts no decision
  is owed (`pending()` is `{}`) and `renewals_left()` is 1. When `renew([uid of a hand card])` is called, it returns
  true, the card is in `trashed`, unrest is still 3, `renewals_left()` is 0 and `actions_left()` is unchanged.
- [ ] AC2 (a flat count per turn): Given Anarchy on its second turn, `renewals_left()` is 1 (no ramp); one `renew` of a
  discard card succeeds and a second is refused and changes nothing. On its third turn `renewals_left()` is 1 again:
  unused renewals don't carry over, and a turn can end with renewals unused.
- [ ] AC3 (the modifier raises the cap): Given a card in play with `"modifiers": {"renewal": 1}`, `renewals_left()` is 2
  on each Anarchy turn, and one `renew` of two cards succeeds. With no `renewal` in the unrest block, `renewals_left()`
  is 0 and `renew` is refused.
- [ ] AC4 (rejections): `renew_error(uids)` is non-empty and `renew` changes nothing when: Anarchy doesn't rule; `uids`
  is empty; a uid is a government, a tableau card or unknown; a uid appears twice; `uids` holds more cards than
  `renewals_left()`; the game is over or another decision is owed (`_blocked_error`).
- [ ] AC5 (no more waiting): Given Anarchy ruling and a choice event drawn at a turn's start, its choice is owed at once
  (renewal no longer goes first). `PENDING_RENEWAL` is no longer a decision kind.
- [ ] AC6 (legal actions): While `renewals_left()` > 0 and there are options, `legal_actions()` has one entry
  `["renew", renewal_options(), renewals_left()]` whose first card passes `renew_error`; with no renewals left, or
  without Anarchy, it has none.
- [ ] AC7 (the bot uses it): Given a fixture game under Anarchy with `renewal: 1` and a card of no worth to the bot (no
  effects, no VP) in hand, when `GenericBot` plays the turn, it renews that card.

## Out of scope
- Anarchy's length (384); the honeymoon (399); the claimants (401–404).
- Which zones renewal may trash from (hand, deck, discard; 255) and the renewal numbers (balance).

## Design notes
- New state: `GameState.renewed` (cards renewed this turn, 0 at each turn's start), copied by `copy()`.
- New query `renewals_left()`: `renewal` + the renewal modifier − `renewed`, never below 0; 0 without Anarchy or with
  no `renewal` in the config. `renewal_options()` stays (hand, deck and discard, governments aside).
- `renew(uids)` / `renew_error(uids)` keep their names; `renew_error` starts with `_blocked_error("renew")` instead of
  `_owed_error`, and checks 1 ≤ `uids.size()` ≤ `renewals_left()`. `renew` no longer lowers unrest.
- Removed: `PENDING_RENEWAL`, `Anarchy.start_renewal`, the renewal case in the decision tables (`_owed_error`,
  `pending` guards, focus keys), `EventChoices.next` after a renewal, the sim bot's owed-renewal path, and
  `state.anarchy_turn` if nothing else reads it once the ramp goes. Follow the `add-decision` skill's list backwards
  for the places a decision kind touches.
- Renewal modifier wording on cards (Calls for Reform, Radical Thinkers, Mysticism) changes from "trash N more" to
  "renew up to N more each Anarchy turn"; the text is generated from `Modifiers.RENEWAL`'s entry.
- `revolt_summary()`'s renewal line becomes "Each turn: you may trash 1 card from your hand, deck or discard."
  Anarchy's card text line: "Each turn, you may trash 1 card."
- UI: the Renewal modal opens from a "Renew" action button (beside Relieve famine) shown while `renewals_left()` > 0,
  picks 1 to `renewals_left()` cards, and can be closed without trashing. The button's label asks the engine for the
  count.
- Bot (AC7): `GenericBot` must see a thinner deck as worth something (its `deck` weight); if it doesn't renew a
  worthless card, add a term under TDD.

## Test plan
| AC | Test |
|---|---|
| AC1 | |

## Manual check
- [ ] During Anarchy the Renew button shows with the count left; the Renewal sheet opens, can be closed, and trashes
  1 to N cards; the button hides when none are left.
- [ ] The cards with the renewal modifier read correctly.
- [ ] Balance worry (for the user to run): renewal now thins the deck with no unrest attached, so revolting to trash
  cards may pay; the honeymoon (399) blocks back-to-back revolutions. `scripts/sim.sh --level 2 --compare <main
  checkout>` (revolts, trashed).

## Log
- 2026-10-07: reshaped with 384's redesign (the user): renewal no longer calms unrest ("just an opportunity to trash
  cards") and the count is flat per turn (no +1 per turn so far).
