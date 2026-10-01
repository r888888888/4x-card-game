---
id: 062
title: Civilization cards (permanent bonuses)
type: feature
status: done
branch: feat/062-civilization-cards
---

## Goal
A game is played as a civilization (TODO 14): one permanent card with a starting gift and ongoing bonuses. This item
adds the card type, the `start` trigger and one civilization from config. Picking one comes in 063 and 064.

## Acceptance criteria
Fixtures added to TEST_CARDS:
- `tribe`, "Tribe", civilization: `start` +3 food, `upkeep` +1 wealth
- `nomads`, "Nomads", civilization, vp 1: `upkeep` score 1

- [x] AC1 (loader): type `civilization` is valid. A civilization in `deck`, `supply`, `territory_deck` or
  `research_deck` is a load error naming that field. Config `starting.civilization` is optional. An unknown id, or a
  card that isn't a civilization, is a load error naming config.json and `starting.civilization`.
- [x] AC2 (start trigger): the trigger `start` is valid only on civilization cards. Elsewhere it is a load error naming
  the card and the effect index. A `start` effect whose op needs a target or opens a choice (`settle`, `explore`,
  `research`) is a load error.
- [x] AC3 (setup): With `starting.civilization: "tribe"` and starting food 2, after `new_game` the `civilization` zone
  holds Tribe, `civilization()` returns its uid, and food is 2 + 3 (start) + 2 (Capital, turn 1 upkeep) = 7, wealth 1.
  The start effects resolve once, before turn 1's upkeep.
- [x] AC4 (upkeep and score): Tribe gives +1 wealth every upkeep, and `upkeep_forecast` includes it. With Nomads, the
  score includes its 1 VP plus 1 per upkeep so far.
- [x] AC5 (none): With no `starting.civilization`, the zone is empty, `civilization()` is -1, and play is as before.
- [x] AC6 (fork): `fork()` copies the civilization zone.

## Out of scope
- Rule modifiers ("buildings cost 1 less"); only existing ops and the new trigger.
- Choosing a civilization (064) and real civilization content beyond one default.

## Design notes
- `CardDef.CIVILIZATION`, in `SEPARATE_DECK_TYPES`. New zone `civilization`. `Effect.TRIGGERS` gains `start`.
  Card text prefix "Start:" (face) and "When the game starts:" (tooltip).
- Upkeep: `resolve_upkeep` covers tableau, researched and civilization. Keep a single list of "always-on
  non-territory permanents", which the governments in 065 join.
- Real data: one default civilization (for example "Tribe of the River": ⟳ +1 food), so the game keeps working before 064.
- UI: the civilization card sits in its own small section (next to Known). Its details open via 056.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_civilization::test_civilization_cards_load`, `::test_civilization_outside_its_place_is_a_load_error`, `::test_starting_civilization_validation`, `::test_starting_civilization_is_optional` |
| AC2 | `test_civilization::test_start_trigger_only_on_civilizations`, `::test_start_effect_needing_a_target_or_choice_is_a_load_error` |
| AC3 | `test_civilization::test_starting_civilization_is_in_the_civilization_zone`, `::test_start_effects_resolve_once_before_the_first_upkeep`, `::test_civilization_is_not_in_the_deck_or_tableau` |
| AC4 | `test_civilization::test_civilization_upkeep_every_turn`, `::test_forecast_includes_the_civilization`, `::test_score_includes_civilization_vp_and_upkeep_score` |
| AC5 | `test_civilization::test_without_a_civilization_play_is_as_before` |
| AC6 | `test_civilization::test_fork_copies_the_civilization` |
| Design note (card text) | `test_civilization::test_start_effects_are_marked_on_the_card_text` |

## Manual check
Run `godot --path .` and start any seed.
- [ ] A "Civilization" row below Known shows Tribe of the River as a compact card; its heading tooltip explains it.
- [ ] Its face reads "⟳ +1 food"; hovering shows "Each upkeep: +1 food", and its details open the same way a Known
  tech's do.
- [ ] The food forecast is 1 higher than the realm alone makes (for example +1 more than the Capital and Farms).

## Log
- 2026-09-29: Built in a worktree off `main`. Red at 6e330ea, 477 tests (was 463).
- Fixtures went in `TEST_CIVS` (with `civ_db` / `civ_engine`), not `TEST_CARDS`, so the red phase didn't fail every
  `make_engine` test. Approved at red.
- Added after approval, test first: `test_start_effects_are_marked_on_the_card_text` for the design note's prefixes.
- `Effect.opens_choice()` (explore, research) joins `target_zone()` for the start check.
- UI: `ui/main.gd` stays at 499 lines by keying the Frontier, Known and Civilization rows in one `_row_sections` map.
- Follow-up: a civilization isn't in `NO_TERRITORY_TYPES`, so a `keyword` or `here` effect on one loads but does
  nothing. Add it when real civilizations arrive (064).
- Sim (20 seeds), main → this: score 64.30 (47–87) → 60.30 (45–82); cities 11.00 → 11.00; pop 13.00 → 13.00;
  techs 9.15 (2–13) → 7.70 (1–13), −16%; bought 0 → 0; era 2 → 2. The +1 food a turn lowers the bot's techs; worth a
  look in 066's balance pass.
