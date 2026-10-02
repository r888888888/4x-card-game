---
id: 190
title: Notices carry a priority, heard as a pattern and seen as a hue bar
type: feature
status: review
branch: feat/190-notice-priorities
---

## Goal
A famine or a revolution shouldn't sound like "Pottery can now be bought". The engine says how serious each notice
is, and the toast shows and sounds it ([docs/design/mcm-style-guide.md](../design/mcm-style-guide.md) §10.7, §15.9,
§12 rules 1, 10, 14): information rings once (●), a caution twice (●●), an urgent notice a falling pair (●↘●), always
at the same volume, and the toast carries a hue bar in the matching colour, so the priority is never in the sound
alone.

## Acceptance criteria
- [x] AC1: `noticed` carries a priority: `noticed(message, priority)` with `priority` one of `GameEngine.NOTICE_INFO`,
  `NOTICE_CAUTION`, `NOTICE_URGENT`. Every existing notice keeps its message unchanged.
- [x] AC2: Urgent: a famine striking ("Famine! Pop went hungry."), a revolution being declared ("Revolution! Anarchy
  begins next turn.") and anarchy beginning ("Anarchy! …"). Given a hungry upkeep that starts a famine (`TEST_CARDS`),
  the notice's priority is `NOTICE_URGENT`.
- [x] AC3: Caution: a famine saving pop ("<card>: 1 pop saved from famine.") and a new era stirring the people
  ("A new era stirs the people: +N unrest.").
- [x] AC4: Info: every other notice (the famine relieved or ending, an era's techs or events added, an event ending, a
  pile unlocked, anarchy burning out, order restored, a government ruling). A test drives each notice the engine can
  raise and checks its priority against AC2–AC4.
- [x] AC5: `Toasts.notice(message, priority)` plays `Sfx.NOTIFICATION_INFO`, `_CAUTION` or `_URGENT` (replacing 189's
  single bell) and gives the toast a 4 px bar on its left edge in `Palette.INSIGHT` (info), `Palette.WEALTH`
  (caution) or `Palette.WARN` (urgent); `Toasts.priorities()` lists the shown toasts' priorities in order.
- [x] AC6: An urgent toast stays twice as long (`Anim.TOAST_TIME` × 2) before it fades; info and caution keep
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
| AC1 | `test_notice_priorities::test_there_are_three_priorities` (passed at red: the constants were added so the files parse), and every `check_noticed(..., priority)` below |
| AC2 | `test_famine::test_a_famine_arriving_and_ending_are_notices` (Famine!, TEST_CARDS), `test_revolution::test_revolting_needs_no_event_and_changes_nothing_this_turn`, `test_anarchy::test_a_turn_starting_at_the_limit_falls_into_anarchy` |
| AC3 | `test_famine::test_a_guard_saving_pop_is_a_notice`, `test_anarchy::test_a_new_era_adds_era_unrest_up_to_the_limit`, `test_prices::test_a_new_era_at_unrest_4_of_5_adds_1` |
| AC4 | `test_famine` (Famine ends), `test_famine_relief`, `test_tech_eras`, `test_event_eras`, `test_events` (an event ending), `test_supply` (a pile unlocked), `test_anarchy::test_when_anarchy_burns_out_the_government_choice_is_owed` (burns out, "Chiefs rules."), `test_leaving_anarchy` (order restored): together every `_notice` call in `engine/` |
| AC5 | `test_notice_priorities::test_each_priority_rings_its_own_pattern`, `test_each_toast_carries_its_priority_as_a_hue_bar`, `test_the_engines_notice_reaches_the_toast_with_its_priority` |
| AC6 | `test_an_urgent_toast_stays_twice_as_long` |

## Manual check
- [ ] A turn that brings a famine: the famine's toast has a red bar, falls in pitch and stays longer; an era's
  "techs added" toast has a blue bar and one bell.

## Log
- 2026-10-02: Specced from the style guide's sound system. Assumption: the urgent / caution / info mapping in AC2–AC4
  (urgent for famine, revolution and anarchy; caution for losses averted or unrest added by an era).
- 2026-10-02: Built. `noticed(message, priority)`, `GameEngine.NOTICE_INFO / CAUTION / URGENT`, `EngineCore._notice(message, priority := NOTICE_INFO)`; famine.gd and anarchy.gd pass urgent and caution. `Toasts.notice(message, priority)` (`PRIORITY_LOOKS`: bell and bar role), `BAR_WIDTH`, `priorities()`, `bar_role(toast)`; the bar is drawn on the toast's panel. `record_messages` records each notice's priority (`noticed_priorities`); `check_noticed` takes an optional priority; `test_toasts` and `test_modal_stack` emit `noticed` with `NOTICE_INFO`.
