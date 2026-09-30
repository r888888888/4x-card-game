---
id: 116
title: Toasts for notable events, and an unread marker on the log
type: feature
status: ready
branch: feat/116-notices-and-toasts
---

## Goal
With the log in a closed drawer (115), a few things only the log said go unseen: a famine arriving or ending, a
tech lost for being passed over, a supply pile unlocking, new era techs and events, and the targeting hint. The
engine marks those messages as notices; the UI shows each as a short toast under the top bar, and the Log button
shows when there are lines you haven't seen.

## Acceptance criteria
<!-- AC1–AC2: engine tests with TEST_CARDS. AC3–AC6: UI tests on the real main.tscn. -->
- [ ] AC1: The engine emits `noticed(message)` for notable log lines, with the same text as the log line, after
  `logged`. Notable: a famine arriving ("Famine! …"), ending, and a building saving pop from it; relieving it; a tech
  lost for being passed over; a supply pile that can now be bought; an era's techs or events added; an active event
  ending. Test each with a fixture that triggers it.
- [ ] AC2: Ordinary lines are not notices: given a turn where a card is played, a card bought, a tech learned,
  cards drawn and reshuffled, and upkeep gains and pop eating, then `noticed` is never emitted.
- [ ] AC3: A notice shows a toast. Given the famine arrives at upkeep, then a toast with its text appears centred
  under the top bar, stays `Anim.TOAST_TIME` (3 s) and fades out; at most 3 show at once, newest on top, the oldest
  going first when a fourth arrives. With Reduce motion toasts fade in and out without sliding.
- [ ] AC4: The targeting hint is a toast. Given a card that needs a target is double-clicked, then its hint
  ("… Click one (or ←/→ then Enter); Esc cancels.") shows as a toast that stays until targeting ends (a pick, Esc,
  or a cancel), then fades. Refusals don't toast (they already float over the card) but still go in the log.
- [ ] AC5: Unread marker. Given the drawer is closed, when a new log line arrives, then the Log button reads
  "Log (L) •"; opening the drawer clears the marker, and lines arriving while it is open don't set it. A new game
  clears it.
- [ ] AC6: Toasts never block play: they ignore the mouse, don't take focus, and hide while a modal or the menu is
  open (queued notices show when it closes, if still within their time).

## Out of scope
- An upkeep summary toast (gains, pop eating, VP at upkeep): the counters already change and pulse; note it in the
  Log if play shows it's missed.
- Changing log text or which lines are logged.

## Design notes
- Engine: new `signal noticed(message: String)`, emitted by a `_notice(message)` helper that logs and notices
  (`_log` stays for ordinary lines). The choice of what is notable is a rule and lives in the engine, not in the UI.
- UI: a `Toasts` component on the fx layer (not `main.gd`, 700-line limit); `TopBar` owns the Log button's text.
- Depends on 115 (the drawer and the Log button).

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|

## Manual check
- [ ] Play to a famine: its toast reads clearly under the top bar and is gone in about 3 s.
- [ ] Double-click Settler (or another targeted card): the hint toast stays until you pick or press Esc.
- [ ] Close the drawer, end a turn: the Log button shows the dot; open it: the dot is gone.

## Log
