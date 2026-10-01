---
id: 148
title: Revolution events: choose to start Anarchy
type: feature
status: review
branch: feat/148-revolution-events
---

## Goal
Anarchy can be a choice. Some events open a window in which the player may revolt, starting Anarchy at once on
their own terms: to renew a cluttered deck, or to change government at a moment that suits them rather than waiting
for unrest to boil over. Follows 145–147. From `spike/unrest`.

## Acceptance criteria
- [x] AC1: An event may set `"revolt": true` (events only; on other types the field is ignored with the warning
  `'revolt' only applies to events (ignored)`; a non-boolean is a load error). Its card text and tooltip add
  `"While active, you may revolt."`.
- [x] AC2: Given an active event with `revolt` and no Anarchy, then `revolt_error()` is "". When `revolt()` is
  called, then Anarchy rules as when unrest reaches the limit (145 AC2: the government shuffled into the deck, a
  notice), with 0 counters, and renewal is pending at once (count 1 + the `renewal` modifier, 147).
- [x] AC3: `revolt_error()` is `"Only a revolutionary event lets you revolt."` with no such event active,
  `"Anarchy already rules."` during Anarchy, the pending-decision message while one is owed and `"The game is
  over."` after the end; `revolt()` then returns false and changes nothing. Revolting uses no action.
- [x] AC4: A Revolt button below the Realm shows while `revolt_error()` is ""; its tooltip says what revolting does.
- [x] AC5 (bot): at the start of its turn, before playing a card, `ScriptedBot` revolts when it may, has an action
  left, the discard isn't empty, and holds a government whose limit / 2 is at least the current unrest (so it can end
  the Anarchy at once). Without such a government it doesn't revolt.

## Out of scope
- Revolting without an event (a standing Revolt action), or revolution as the only way to change government:
  discussed in the spike as bolder options, not taken up.

## Design notes
- `CardDef.revolt` (events, `DataLoader.TYPE_FIELDS`); the spike used a config tag instead, but a field gives
  generated card text.
- API: `revolt()`, `revolt_error()`; `Anarchy.revolt` reuses 145's fall into Anarchy and 147's renewal start.
- Content (spike, for review): Calls for Reform (lasts 2 turns, `revolt`, `modifiers: {renewal: 1}`), Peasant
  Uprising (+1 unrest, `revolt`, 1 turn), Radical Thinkers (era 2, lasts 3 turns, `revolt`, `modifiers: {renewal:
  2}`); one copy each in the event deck.
- Revolt plus a government in hand ends Anarchy in the same turn for a free renewal; it needs the event and the
  government at once, which kept it rare in the spike (0.1–0.6 revolts per game). Watch it once governments are
  more common.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_revolution::test_an_event_with_revolt_loads_and_says_so`, `test_revolt_validation` |
| AC2 | `test_revolution::test_revolting_starts_anarchy_with_renewal_owed_at_once` |
| AC3 | `test_revolution::test_revolt_error_names_each_reason_and_a_refusal_changes_nothing`, `test_revolt_waits_for_a_pending_discard` |
| AC4 | `test_revolution::test_the_revolt_button_shows_while_you_may_revolt` |
| AC5 | `test_revolution::test_the_bot_revolts_when_a_government_in_hand_ends_it_at_once`, `test_the_bot_doesnt_revolt_without_such_a_government` |

## Manual check
- [ ] When Calls for Reform is drawn, the Revolt button appears below the Realm; clicking it starts Anarchy and opens
  the Renewal overlay.
- [ ] Shipped events and numbers as listed in Design notes.

## Log

- 2026-10-01: Built. Red checkpoint (agreed): the bot's "limit / 2 at least the unrest" uses 146's acceptance rule
  (`Anarchy.accept_error`, now shared with `play_error`: modifier included, a government with no limit accepted).
- Green: `test_revolting_starts_anarchy_with_renewal_owed_at_once` compared `actions_left()` before (Chiefs:
  unlimited, -1) and after (Anarchy: 1), which can never hold; with the user's OK it now checks 1 of 1 left.
- Content as the Design notes list (one copy each). Peasant Uprising lasts 1 turn (no discard). The spike's
  `revolution` tag isn't used: the field replaces it.
- `ui/main.gd` is at 691 of 700 lines: the next UI addition there needs a split item first.
- Balance: not simmed.
