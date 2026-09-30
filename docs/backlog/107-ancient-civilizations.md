---
id: 107
title: Replace the starting civilizations with ancient historical ones
type: feature
status: red-review
branch: feat/107-ancient-civilizations
---

## Goal
You play as a real civilization of antiquity instead of an invented one (Children of the River, Salt Road Traders,
Hearth Clans, Star Watchers). Six civilizations, each with a bonus that fits its history, built from effect ops the
engine already has. Items 108–111 add new mechanics and give some civilizations a second, signature bonus.

## Acceptance criteria
Content item: the tests assert invariants of the real data; the roster and its numbers are under Manual check.

- [ ] AC1 (no orphans): every card of type `civilization` in the real `data/cards.json` is listed in config
  `civilizations`. (The four old civilizations are removed from the data, not left unlisted.)
- [ ] AC2 (roster): the real config lists at least 6 civilizations, each with at least one effect, no two with the
  same card text, and `starting.civilization` is one of them. (Extends
  `test_real_config_lists_at_least_3_different_civilizations`.)
- [ ] AC3 (start gifts): every `create` with trigger `start` on a real civilization puts a card into `discard`, and
  that card is one the player can get in the game otherwise (in `deck`, `supply`, or created by a tech in
  `research_deck`).
- [ ] AC4: the real data loads with no warnings or errors (existing test), and a `new_game` with each listed
  civilization succeeds and leaves that civilization in the `civilization` zone.

## Out of scope
- New mechanics: cost discounts (108), hand size (109), housing (110), home territory (111).
- Leaders, unique units or unique buildings per civilization.
- Balance: numbers are tuned in a later balance item.

## Design notes
- No engine or format change. Uses `gain`, `gain_per_keyword`, `gain_per_tag`, `score` (upkeep) and `gain`, `create`
  (start).
- Proposed roster (ids are the lowercase names):
  - **Egypt** (default, "Gift of the Nile"): ⟳ +1 food per settled territory with fresh water or flood plain.
  - **Sumer** ("the first farmers and scribes"): Start: add an Insight to your discard; ⟳ +1 food per farm.
  - **Phoenicia** ("sea traders"): Start: +3 wealth; ⟳ +1 wealth per coastal territory.
  - **Babylon** ("Code of Hammurabi"): Start: add Kingship to your discard.
  - **Greece** ("philosophy and drama"): Start: add a Storyteller to your discard; ⟳ +1 VP.
  - **Persia** ("the Royal Road"): Start: add a Caravan to your discard; ⟳ +1 wealth.
- Egypt on the starting River Meadow (fresh water) gives ⟳ +1 food, the same as today's default.
- A saved civilization id that no longer exists (e.g. `river_children`) already falls back to the first listed one
  with a warning (064 AC5).
- Update PLAN.md's "Real data (064)" line.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_content::test_every_civilization_card_is_listed` |
| AC2 | `test_content::test_real_config_lists_at_least_6_different_civilizations` (replaces `…_at_least_3_…`) |
| AC3 | `test_content::test_civilization_start_gifts_are_obtainable_cards_in_the_discard` |
| AC4 | `test_content::test_a_new_game_starts_as_each_listed_civilization`, `::test_real_data_loads_without_warnings` |
| (content coupling) | `test_identity_lines::test_side_panel_shows_civilization_then_government`, `::test_pressing_a_line_opens_its_details` now read the civilization's name from the engine |

## Manual check
- [ ] The roster in data matches the design notes: six civilizations, Egypt the default, and each bonus reads right on
  its card and in its details.
- [ ] The new game screen fits six civilization cards without clipping, at the default and a narrow window size.
- [ ] Start a game as each civilization: its start gift appears (resources or a card in the discard) and its upkeep
  bonus shows in the forecast.

## Log
- Balance worries: Babylon's Kingship on turn 1 skips the Code of Laws tech; Sumer's per-farm food may snowball.
  Leave to the balance item.
