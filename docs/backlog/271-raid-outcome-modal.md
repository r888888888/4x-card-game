---
id: 271
title: A raid that strikes opens a modal with its outcome and its own sound
type: feature
status: red-review
branch: feat/271-raid-outcome-modal
---

## Goal
When a barbarian raid strikes at the start of a turn, the player can't tell what happened: the result is a toast and a
log line that are easy to miss. After this, each raid that strikes opens a modal showing the raid's card, whether it
was repelled or pillaged, and what it cost or gained. A repelled raid and a pillaged raid each have their own Level 3
sound.

## Acceptance criteria
- [ ] AC1 (engine): Given a raid that strikes (162), then `raid_outcome_text(outcome)` for its `raid_resolved` outcome
  returns the result line the toast shows today: "<raid> repelled at <territory>[: <what>]." or
  "<raid> pillaged <territory>[: <what>].", where <what> lists gains and losses, "−N pop" and "N unit(s) lost".
  The line is logged as before, but `noticed` is no longer emitted for a raid striking, so no toast appears.
- [ ] AC2: Given main with a raid of strength 3 aimed at a territory with defence 0 and 1 turn left, when the player
  ends the turn, then the raid modal is open with `shown()` = {uid, id, repelled: false, result (AC1's line)}, the
  raid's card in its aside, titled with the raid's name, context "Turn N" (the new turn), and OK focused. With defence
  ≥ 3 instead, `repelled` is true and the line says "repelled".
- [ ] AC3: Given the same turn draws an event, when the turn starts, then the raid modal sits above the event modal
  (raid on top); closing it with OK, Enter, Esc or a click outside leaves the event modal open.
- [ ] AC4: Given a raid strikes, then `Sfx` plays `ui.milestone.pillaged` when it was pillaged and
  `ui.milestone.repelled` when it was repelled. Both tokens are Level 3 (Game bus) and each has its file under
  `assets/sounds/events/`. A raid sound outranks the milestones on the same change except the era
  (era > pillaged > repelled > city > tech).
- [ ] AC5: Given an era begins on the same turn, then the raid modal waits for the era sheet to close, as the event
  modal does (211), then opens.

## Out of scope
- Raid rules, strengths, targeting and timing (162, 257): unchanged.
- The announcement of a raid when it is drawn (the event modal, `raid_line`): unchanged.
- ScriptedBot and the sim: unaffected (UI only, plus a log/notice change).
- No new setting: the Event sounds volume controls the new sounds like every Level 3 sound.

## Design notes
- **Engine API**: `raid_outcome_text(outcome: Dictionary) -> String` in `engine_queries.gd`, delegating to
  `Military`; `_strike` builds its log line with it and calls `_log` instead of `_notice`. Update `noticed`'s doc
  comment (a raid pillaging is no longer an urgent notice).
- **UI**: `RaidModal extends Modal` (`ui/raid_modal.gd`), built like `EventModal`: card in the aside, result line as a
  heading, a "Repelled" / "Pillaged" heading above it, OK in the footer, `shown()` test hook. main keeps the last
  `raid_resolved` outcome like `_drawn` and, in `_refresh`, opens the event modal first and then the raid modal, so
  the raid sits on top. One instance is enough: only one raid is active at a time (257), so at most one strikes a
  turn.
- **Sounds**: new tokens `Sfx.MILESTONE_REPELLED` (`ui.milestone.repelled`) and `Sfx.MILESTONE_PILLAGED`
  (`ui.milestone.pillaged`), Level 3. `EventSounds` hears `raid_resolved` alongside `milestone` and picks the highest
  per change (AC4's order). Files rendered by `docs/design/sound-export.html`, per the guide's Ceremony family:
  - repelled: a heavy latch (a gate barred), then marimba D4–A4–D5 rising, 600–900 ms.
  - pillaged: a relay drop and a low drum hit, then muted piano falling B3–F♯3 (B minor), 700–1000 ms, dignified,
    not alarming like a siren.
  Add both rows to the style guide's §14.1 token table.
- **Tests that change**: `test_raids.gd` tests that check the pillage/repel notice move to AC1's log + no-notice
  check; `test_sfx::test_every_token_has_its_files` covers the two new tokens.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_raids::test_the_strike_line_says_what_it_cost_or_gave_and_is_logged_not_noticed` (replaces `test_the_strike_notice_says_what_it_cost_or_gave`) |
| AC2 | `test_raid_modal::test_a_pillaging_raid_opens_its_modal`, `test_raid_modal::test_a_repelled_raid_opens_its_modal` |
| AC3 | `test_raid_modal::test_the_raid_modal_sits_above_the_turns_event` (OK, Enter, Esc) |
| AC4 | `test_raid_modal::test_the_raid_sounds_are_level_3_with_their_files`, `test_a_pillaging_raid_plays_the_pillaged_sound`, `test_a_repelled_raid_plays_the_repelled_sound`, `test_a_raid_outranks_a_city_but_not_an_era`; `test_sfx::test_every_token_has_its_files` covers the files' format once the tokens exist |
| AC5 | `test_raid_modal::test_the_raid_modal_waits_for_the_era_sheet` |

## Manual check
- [ ] Let a raid pillage an undefended territory: the modal shows the raid card and "pillaged", the sound is a falling
  figure, distinct from the city and tech sounds.
- [ ] Station enough units to repel one: the modal says "repelled" and the rising sound plays.
- [ ] On a turn with a raid and a new event: the raid comes first, then the event after OK.
- [ ] The two sounds sit at the level of the other milestones, not louder.

## Log
- Spec'd 2026-10-04. Decisions from the user: two sounds (repelled / pillaged), one modal per raid, raid modal above
  the turn's event, and the toast dropped (the log line stays).
- Red phase: dropped the two-raids criterion (one modal per raid, the worst sound once). Raid pacing (257) allows one
  active raid at a time, so two can never strike on the same turn; that path would be unreachable. The game can't end
  between a strike and the refresh that shows it (raids strike at a turn's start, the game ends at a turn's end), so
  the game-over clause went too.
