---
id: 191
title: Event sounds for techs, cities, eras and the end of the game
type: feature
status: ready
branch: feat/191-event-sounds
---

## Goal
The game's rare, important moments get the guide's Level 3 sounds ([docs/design/mcm-style-guide.md](../design/mcm-style-guide.md)
§11.3, §11.6, §11.12, §16.4, §16.7): a short vibraphone figure when a tech is learned, a stamped plan and two marimba
notes when a city is founded, a fuller sequence when an era begins, and the closing ceremony when the game ends. They
play on the Game bus, so a player who turns interface sounds off still hears them, and routine sounds never talk over
them.

## Acceptance criteria
- [ ] AC1: The engine emits `milestone(kind)` with `kind` one of `GameEngine.MILESTONE_TECH`, `MILESTONE_CITY`,
  `MILESTONE_ERA`, before `changed`: once when `buy_tech` learns a tech, once when a territory is settled into a city,
  and once for each era actually added (an era already added emits nothing). A failed `buy_tech` emits nothing.
- [ ] AC2: Starting or restarting a game emits no milestone, whatever eras or cities the setup adds.
- [ ] AC3: The board plays `Sfx.MILESTONE_BREAKTHROUGH`, `MILESTONE_CITY` or `MILESTONE_ERA` for them. When one
  action brings several (a tech whose learning adds an era), only the highest plays: era over city over tech.
- [ ] AC4: When the game-over sheet appears, `Sfx.MILESTONE_VICTORY` plays once; restarting from it, or the sheet
  refreshing while shown, plays nothing more.
- [ ] AC5: While one of these plays, the counters, notices and other system sounds of the same action stay silent
  (186's Level 3 rule): given a tech learned that adds an era and two notices, `Sfx.played()` holds the era sound
  and no notification. A button press during it still clicks.
- [ ] AC6: With interface sounds off (185), the event sounds still play; with the Game volume at 0 they don't.

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

## Manual check
- [ ] Seed 5, Egypt: learning a tech plays a short rising vibraphone figure; settling a city a stamp and two marimba
  notes; reaching era 2 a fuller sequence; the game-over sheet the closing chord. None feels like a casino win.
- [ ] Turn interface sounds off: clicks go quiet, the events still play.

## Log
- 2026-10-02: Specced from the style guide's sound system. Decided 2026-10-02: tech learned, city founded, new era
  and game over get Level 3 sounds in this item.
