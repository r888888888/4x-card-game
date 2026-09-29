---
id: 064
title: Choose your civilization when starting a game
type: feature
status: ready
branch: feat/064-choose-civilization
---

## Goal
Starting a game means picking a civilization (TODO 18). The start screen (063) shows the civilizations from config;
the chosen one replaces `starting.civilization` (062). Ships with at least 3 civilizations that play differently.

## Acceptance criteria
Fixtures: TEST config `civilizations: ["tribe", "nomads"]` (062 fixtures).

- [ ] AC1 (loader): config `civilizations` is optional: a list of civilization ids, with no duplicates. An unknown id,
  a card that isn't a civilization, or a duplicate is a load error naming config.json and `civilizations`. If
  `starting.civilization` is set, it must be in the list when the list is present.
- [ ] AC2 (API): `civilizations() -> Array[String]` returns the list in config order. `new_game(seed, civ_id := "")`
  with "nomads" puts Nomads in the civilization zone. With "" it uses `starting.civilization`, as in 062.
- [ ] AC3 (errors): `new_game_error(civ_id)` is "" for a listed civilization or "". For an unlisted one it is
  "Unknown civilization 'x'.", and `new_game` then refuses and changes nothing.
- [ ] AC4 (seed): The same seed with the same civilization gives the same deck order and the same territory rolls as
  with any other civilization. The civilization's start effects use no rng.
- [ ] AC5 (settings): `Settings` remembers the last chosen civilization (saved like reduce motion). A saved id that is
  no longer in the list falls back to the first one, with a warning.
- [ ] AC6 (content): the real config lists at least 3 civilizations. Each has at least one effect, no two have
  identical effect lists, and the real data loads with no warnings.

## Out of scope
- Civilization-specific starting decks or unique cards (a later item if wanted).
- Rule-modifier bonuses (see 062).

## Design notes
- Proposed content (for review): **River Folk** (⟳ +1 food), **Merchants** (Start: +3 wealth; ⟳ +1 wealth per
  2 cities, if an op for that exists; otherwise ⟳ +1 wealth), **Builders** (Start: +4 food), **Mystics** (1 VP;
  ⟳ +1 VP every upkeep, to be balanced by the sim).
- UI: the start screen shows the civilizations as cards (click to select, details via 056). New game uses the
  selected one.
- The game-over overlay and the menu show the civilization next to the seed. Restart keeps it.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_civilization::test_…` |

## Manual check
- [ ] The start screen shows the civilization cards, the last choice is pre-selected, and each plays noticeably
  differently.
- [ ] Sim per civilization in the Log (mean score spread).

## Log
