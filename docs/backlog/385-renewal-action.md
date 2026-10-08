---
id: 385
title: Renewal is a free action during Anarchy
type: feature
status: ready
branch: feat/385-renewal-action
---

## Goal
Today renewal (147, 255) is a decision Anarchy forces on you at each turn's start: trash `renewal` + (its turn − 1) +
the renewal modifier cards before anything else. Make it a choice instead: during Anarchy you may renew at any time,
trashing cards from your hand, deck or discard (not a government) for −1 unrest each, up to that same count per turn,
and it costs no action. With [384](384-simpler-anarchy.md) (Anarchy lasts until unrest reaches 0), renewing is how you
shorten Anarchy, paid for with cards.

Builds on 384.

## Acceptance criteria
Fixtures are `tests/lib/anarchy_case.gd`'s, with `unrest.renewal: 1`.

- [ ] AC1 (an action, not a decision): Given Anarchy on its first turn with 3 unrest, when the turn starts no decision
  is owed (`pending()` is `{}`) and `renewals_left()` is 1. When `renew([uid of a hand card])` is called, it returns
  true, the card is in `trashed`, unrest is 2, `renewals_left()` is 0 and `actions_left()` is unchanged.
- [ ] AC2 (the count per turn): Given Anarchy on its second turn, `renewals_left()` is 2; two `renew` calls of one card
  each both succeed (a hand card, then a discard card); a third is refused and changes nothing. On its third turn
  `renewals_left()` is 3: unused renewals don't carry over, and a turn can end with renewals unused.
- [ ] AC3 (the modifier raises the cap): Given a card in play with `"modifiers": {"renewal": 1}`, on Anarchy's first turn
  `renewals_left()` is 2. With no `renewal` in the unrest block, `renewals_left()` is 0 and `renew` is refused.
- [ ] AC4 (rejections): `renew_error(uids)` is non-empty and `renew` changes nothing when: Anarchy doesn't rule; `uids`
  is empty; a uid is a government, a tableau card or unknown; a uid appears twice; `uids` holds more cards than
  `renewals_left()`; the game is over or another decision is owed (`_blocked_error`).
- [ ] AC5 (no more waiting): Given Anarchy ruling and a choice event drawn at a turn's start, its choice is owed at once
  (renewal no longer goes first). `PENDING_RENEWAL` is no longer a decision kind.
- [ ] AC6 (legal actions): While `renewals_left()` > 0 and there are options, `legal_actions()` has one entry
  `["renew", renewal_options(), renewals_left()]` whose first card passes `renew_error`; with no renewals left, or
  without Anarchy, it has none.
- [ ] AC7 (the bot uses it): Given a fixture game under Anarchy with 3 unrest, `renewal: 1` and a card of no worth to
  the bot (no effects, no VP) in hand, when `GenericBot` plays the turn, it renews that card.

## Out of scope
- Anarchy's length (384); losing to a long Anarchy (386).
- Which zones renewal may trash from (hand, deck, discard; 255) and the renewal numbers (balance).

## Design notes
- New state: `GameState.renewed` (cards renewed this turn, 0 at each turn's start), copied by `copy()`.
- New query `renewals_left()`: `renewal` + its turn − 1 + the renewal modifier − `renewed`, never below 0; 0 without
  Anarchy or with no `renewal` in the config. `renewal_options()` stays (hand, deck and discard, governments aside).
- `renew(uids)` / `renew_error(uids)` keep their names; `renew_error` starts with `_blocked_error("renew")` instead of
  `_owed_error`, and checks 1 ≤ `uids.size()` ≤ `renewals_left()`.
- Removed: `PENDING_RENEWAL`, `Anarchy.start_renewal`, the renewal case in the decision tables (`_owed_error`,
  `pending` guards, focus keys), `EventChoices.next` after a renewal, the sim bot's owed-renewal path. Follow the
  `add-decision` skill's list backwards for the places a decision kind touches.
- Renewal modifier wording on cards (Calls for Reform, Radical Thinkers, Mysticism) changes from "trash N more" to
  "renew up to N more each Anarchy turn"; the text is generated from `Modifiers.RENEWAL`'s entry.
- `revolt_summary()`'s renewal line becomes "Each turn: renew up to 1 card, +1 per turn so far, from your hand, deck or
  discard (−1 unrest each)."
- UI: the Renewal modal opens from a "Renew" action button (beside Relieve famine) shown while `renewals_left()` > 0, picks
  1 to `renewals_left()` cards, and can be closed without trashing. The button's label asks the engine for the count.
- Bot (AC7): if `GenericBot`'s value doesn't see lower unrest under Anarchy (its unrest risk reads the limit, and no
  government means none), add a term under TDD so renewing shows; the sim must still end Anarchies.

## Test plan
| AC | Test |
|---|---|
| AC1 | |

## Manual check
- [ ] During Anarchy the Renew button shows with the count left; the Renewal sheet opens, can be closed, and trashes
  1 to N cards; the button hides when none are left.
- [ ] The cards with the renewal modifier read correctly.
- [ ] Balance worry (for the user to run): renewing is now optional, so players may keep their cards and sit longer in
  Anarchy, or clear it faster with the modifier events. `scripts/sim.sh --level 2 --compare <main checkout>`
  (anarchy_turns, trashed).

## Log
