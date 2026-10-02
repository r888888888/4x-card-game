---
id: 191
title: Event sounds for techs, cities, eras and the end of the game
type: feature
status: review
branch: feat/191-event-sounds
---

## Goal
The game's rare, important moments get the guide's Level 3 sounds ([docs/design/mcm-style-guide.md](../design/mcm-style-guide.md)
§11.3, §11.6, §11.12, §16.4, §16.7): a short vibraphone figure when a tech is learned, a stamped plan and two marimba
notes when a city is founded, a fuller sequence when an era begins, and the closing ceremony when the game ends. They
play on the Game bus, so a player who turns interface sounds off still hears them, and routine sounds never talk over
them.

## Acceptance criteria
- [x] AC1: The engine emits `milestone(kind)` with `kind` one of `GameEngine.MILESTONE_TECH`, `MILESTONE_CITY`,
  `MILESTONE_ERA`, before `changed`: once when `buy_tech` learns a tech, once when a territory is settled into a city,
  and once for each era actually added (an era already added emits nothing). A failed `buy_tech` emits nothing.
- [x] AC2: Starting or restarting a game emits no milestone, whatever eras or cities the setup adds.
- [x] AC3: The board plays `Sfx.MILESTONE_BREAKTHROUGH`, `MILESTONE_CITY` or `MILESTONE_ERA` for them. When one
  action brings several (a tech whose learning adds an era), only the highest plays: era over city over tech.
- [x] AC4: When the game-over sheet appears, `Sfx.MILESTONE_VICTORY` plays once; restarting from it, or the sheet
  refreshing while shown, plays nothing more.
- [x] AC5: While one of these plays, the counters, notices and other system sounds of the same action stay silent
  (186's Level 3 rule): given a tech learned that adds an era and two notices, `Sfx.played()` holds the era sound
  and no notification. A button press during it still clicks.
- [x] AC6: With interface sounds off (185), the event sounds still play; with the Game volume at 0 they don't.

## Out of scope
- Wonders, diplomatic accords and a separate defeat (the game has no wonders or diplomacy yet, and its end is a score,
  not a win or a loss): their tokens exist (186) for later. The ceremonial sheet's motion and the score's rolling
  total (§11.12). Music and its ducking.

## Design notes
- New engine signal `milestone(kind: StringName)` with the three kind constants; emitted from `Research.buy`,
  `Territories.settle` and `Research.add_era` once the game has started (the engine already knows setup from play).
  The UI maps kinds to tokens; which moments count as milestones is the engine's call (CLAUDE.md).
- "Only the highest" is gathered over one engine action: the board collects milestone kinds until `changed` and plays
  the highest then.
- If playtests show techs learned most turns, breakthrough steps down to Level 2 (`ui.confirm`, two-note form), as the
  guide's §11.3 allows; note it in the Log rather than in this item's criteria.
- Builds on 186; independent of 187–190.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_milestones::test_the_milestone_kinds` (passed at red: the constants were added so the files parse), `test_learning_a_tech_is_a_milestone_before_changed`, `test_a_failed_buy_is_no_milestone`, `test_settling_a_territory_is_a_city_milestone`, `test_each_era_added_is_a_milestone_once` |
| AC2 | `test_starting_and_restarting_a_game_emits_no_milestone` |
| AC3 | `test_event_sounds::test_learning_a_tech_plays_the_breakthrough`, `test_settling_plays_the_city`, `test_a_tech_that_adds_an_era_plays_only_the_era` |
| AC4 | `test_the_game_over_sheet_plays_the_victory_once` |
| AC5 | `test_while_an_event_plays_its_actions_routine_sounds_stay_silent` |
| AC6 | `test_event_sounds_ignore_the_interface_key_but_not_the_game_volume` |

## Manual check
- [ ] Seed 5, Egypt: learning a tech plays a short rising vibraphone figure; settling a city a stamp and two marimba
  notes; reaching era 2 a fuller sequence; the game-over sheet the closing chord. None feels like a casino win.
- [ ] Turn interface sounds off: clicks go quiet, the events still play.

## Log
- 2026-10-02: Specced from the style guide's sound system. Decided 2026-10-02: tech learned, city founded, new era
  and game over get Level 3 sounds in this item.
- 2026-10-02: Built. `GameEngine.milestone(kind)`, `MILESTONE_TECH / CITY / ERA`, `EngineCore._milestone` (silent while `_setting_up`, set by `TurnLoop.new_game`); `Research.buy` emits the tech as it is learned (before its effects, so a tech that adds an era emits tech then era), `Research.add_era` and `Territories.settle` theirs. `EventSounds` (`ui/event_sounds.gd`, a Node under main, added before main listens to `changed`) gathers an action's milestones and plays the highest on `changed`; `GameOverOverlay.refresh` plays the victory as the sheet appears.
- `Sfx` (186) gains a rule: when a Level 3 is played, the system's Level 1–2 sounds scheduled under it in the same frame give way (stopped and dropped from `played()`), because an action's notices are rung before its `changed`. `test_sfx::test_play_records_the_token_its_bus_and_when` now plays its city after its press.
- Only one notice comes with Philosophy in the fixture (the era's techs added), so AC5's test checks the notices of that action, not two.
