---
id: 064
title: Choose your civilization when starting a game
type: feature
status: done
branch: feat/064-choose-civilization
---

## Goal
Starting a game means picking a civilization (TODO 18). The start screen (063) shows the civilizations from config;
the chosen one replaces `starting.civilization` (062). Ships with at least 3 civilizations that play differently.

## Acceptance criteria
Fixtures: TEST config `civilizations: ["tribe", "nomads"]` (062 fixtures).

- [x] AC1 (loader): config `civilizations` is optional: a list of civilization ids, with no duplicates. An unknown id,
  a card that isn't a civilization, or a duplicate is a load error naming config.json and `civilizations`. If
  `starting.civilization` is set, it must be in the list when the list is present.
- [x] AC2 (API): `civilizations() -> Array[String]` returns the list in config order. `new_game(seed, civ_id := "")`
  with "nomads" puts Nomads in the civilization zone. With "" it uses `starting.civilization`, as in 062.
- [x] AC3 (errors): `new_game_error(civ_id)` is "" for a listed civilization or "". For an unlisted one it is
  "Unknown civilization 'x'.", and `new_game` then refuses and changes nothing.
- [x] AC4 (seed): The same seed with the same civilization gives the same deck order and the same territory rolls as
  with any other civilization. The civilization's start effects use no rng.
- [x] AC5 (settings): `Settings` remembers the last chosen civilization (saved like reduce motion). A saved id that is
  no longer in the list falls back to the first one, with a warning.
- [x] AC6 (content): the real config lists at least 3 civilizations. Each has at least one effect, no two have
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
| AC1 | `test_choose_civilization::test_civilizations_list_loads`, `::test_civilizations_list_is_optional`, `::test_civilizations_list_validation` |
| AC2 | `test_choose_civilization::test_civilizations_returns_the_list_in_order`, `::test_civilizations_is_empty_without_a_list`, `::test_new_game_with_a_civilization_uses_it`, `::test_new_game_without_a_civilization_uses_starting`, `::test_new_game_without_any_civilization_has_none` |
| AC3 | `test_choose_civilization::test_new_game_error_accepts_a_listed_civilization_or_none`, `::test_new_game_error_names_an_unlisted_civilization`, `::test_new_game_with_an_unlisted_civilization_changes_nothing` |
| AC4 | `test_choose_civilization::test_same_seed_same_decks_whatever_the_civilization` |
| AC5 | `test_settings::test_missing_file_means_no_civilization`, `::test_civilization_survives_save_and_load`, `::test_non_string_civilization_falls_back_to_none_with_warning`, `::test_civilization_in_keeps_a_listed_choice`, `::test_civilization_in_falls_back_to_the_first_with_warning`, `::test_civilization_in_with_nothing_saved_picks_the_first_quietly`, `::test_settings_set_civilization_saves_it` |
| AC6 | `test_content::test_real_config_lists_at_least_3_different_civilizations` (plus the existing `test_real_data_loads_without_warnings`) |
| UI (design notes) | `test_start_screen::test_start_screen_shows_the_listed_civilizations`, `::test_the_saved_civilization_is_preselected`, `::test_selecting_a_civilization_saves_it_and_new_game_uses_it`, `::test_restart_keeps_the_civilization`, `::test_menu_and_game_over_name_the_civilization` |

## Manual check
- [ ] The start screen shows the civilization cards, the last choice is pre-selected, and each plays noticeably
  differently.
- [x] Sim per civilization in the Log (mean score spread).
- [ ] Run `godot --path .`: four civilization cards sit above New game, the saved one highlighted. Click another:
  it highlights; relaunch and it is still selected. Hover shows its text; its details open like a supply card's.
- [ ] Start a game: the Civilization row shows it, the menu reads "Playing as …", Restart keeps it, and the game-over
  overlay ends "Played as …".
- [ ] The cards fit the start screen at the default window size (four cards plus the hover lift).

## Log
- 2026-09-29: Built in a worktree off `main`. Red at 6a99162, 519 tests (was 494).
- The choice is saved when a card is selected, not on New game, so the 063 tests that press New game never write
  the player's settings file.
- The "no longer offered" fallback is `SettingsStore.civilization_in(listed, warnings)`; main pushes its warning.
- Names changed mid-build at the user's request (more thematic): River Folk → Children of the River
  (`river_children`, replaces 062's Tribe of the River as the default), Merchants → Salt Road Traders
  (`salt_traders`), Builders → Hearth Clans (`hearth_clans`), Mystics → Star Watchers (`star_watchers`).
- Salt Road Traders get ⟳ +1 wealth: there is no "+1 per 2 cities" op.
- Start screen z_index 15 (not 30): the details modal (20) must show over it.
- Sim, 20 seeds, per civilization (mean score (min–max), mean techs):

  | civilization | score | techs |
  |---|---|---|
  | Star Watchers | 85.30 (68–108) | 9.15 |
  | Salt Road Traders | 77.15 (55–98) | 12.50 |
  | Children of the River | 60.30 (45–82) | 7.70 |
  | Hearth Clans | 56.75 (43–74) | 5.85 |

  Spread 28.6 points (about 50% of the weakest). Star Watchers' ⟳ +1 VP is worth ~20 VP a game; Hearth Clans' one-off
  +4 food barely shows. Not tuned here; see the report.
- Follow-up: the civilization cards aren't reachable by keyboard (Tab reaches the seed field, New game and the
  toggle only).
