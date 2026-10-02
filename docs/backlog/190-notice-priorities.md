---
id: 190
title: Notices carry a priority, heard as a pattern and seen as a hue bar
type: feature
status: ready
branch: feat/190-notice-priorities
---

## Goal
A famine or a revolution shouldn't sound like "Pottery can now be bought". The engine says how serious each notice
is, and the toast shows and sounds it ([docs/design/mcm-style-guide.md](../design/mcm-style-guide.md) §10.7, §15.9,
§12 rules 1, 10, 14): information rings once (●), a caution twice (●●), an urgent notice a falling pair (●↘●), always
at the same volume, and the toast carries a hue bar in the matching colour, so the priority is never in the sound
alone.

## Acceptance criteria
- [ ] AC1: `noticed` carries a priority: `noticed(message, priority)` with `priority` one of `GameEngine.NOTICE_INFO`,
  `NOTICE_CAUTION`, `NOTICE_URGENT`. Every existing notice keeps its message unchanged.
- [ ] AC2: Urgent: a famine striking ("Famine! Pop went hungry."), a revolution being declared ("Revolution! Anarchy
  begins next turn.") and anarchy beginning ("Anarchy! …"). Given a hungry upkeep that starts a famine (`TEST_CARDS`),
  the notice's priority is `NOTICE_URGENT`.
- [ ] AC3: Caution: a famine saving pop ("<card>: 1 pop saved from famine.") and a new era stirring the people
  ("A new era stirs the people: +N unrest.").
- [ ] AC4: Info: every other notice (the famine relieved or ending, an era's techs or events added, an event ending, a
  pile unlocked, anarchy burning out, order restored, a government ruling). A test drives each notice the engine can
  raise and checks its priority against AC2–AC4.
- [ ] AC5: `Toasts.notice(message, priority)` plays `Sfx.NOTIFICATION_INFO`, `_CAUTION` or `_URGENT` (replacing 189's
  single bell) and gives the toast a 4 px bar on its left edge in `Palette.INSIGHT` (info), `Palette.WEALTH`
  (caution) or `Palette.WARN` (urgent); `Toasts.priorities()` lists the shown toasts' priorities in order.
- [ ] AC6: An urgent toast stays twice as long (`Anim.TOAST_TIME` × 2) before it fades; info and caution keep
  `TOAST_TIME`.

## Out of scope
- Flags on a left rail, rail lamps and toasts that stay until the cause is resolved (§10.7): they wait for the left
  rail layout. Reprioritising notices beyond this mapping (a balance-of-attention question for playtests).

## Design notes
- `EngineCore._notice(message, priority := NOTICE_INFO)`; the urgent and caution call sites (famine.gd, anarchy.gd)
  pass theirs. Priorities are engine knowledge, so the UI never guesses from the message text (CLAUDE.md).
- `test_toasts` and `test_modal_stack` emit `noticed` by hand with one argument; their helpers pass a priority now
  (the same assertions otherwise). `check_noticed` in `test_case.gd` can gain an optional expected priority.
- The words already say it too ("Famine!", "Revolution!", "Anarchy!"), so the hue bar isn't colour alone.
- Builds on 189.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|

## Manual check
- [ ] A turn that brings a famine: the famine's toast has a red bar, falls in pitch and stays longer; an era's
  "techs added" toast has a blue bar and one bell.

## Log
- 2026-10-02: Specced from the style guide's sound system. Assumption: the urgent / caution / info mapping in AC2–AC4
  (urgent for famine, revolution and anarchy; caution for losses averted or unrest added by an era).
