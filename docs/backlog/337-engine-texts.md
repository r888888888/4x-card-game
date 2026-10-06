---
id: 337
title: The engine writes the era's "Opens at…" line and one "needs … (you have …)" format
type: feature
status: in-progress
branch: feat/337-engine-texts
---

## Goal
Two small leaks found by the project review. The Knowledge screen builds "Opens at 8 pop or 15 wealth" itself from
the raw unlock thresholds (`ui/knowledge_screen.gd:270`), which is text the engine owns. And playing a card short of
resources hand-rolls its own message in `CardPlay.place_error` (`engine/card_play.gd:27`), naming only the first
resource short, while every other price uses `EngineCore.price_error` ("… needs 2 food, 5 wealth (you have 0 food, 1
wealth).").

## Acceptance criteria
- [ ] AC1: Given an era not reached whose unlock needs 8 pop or 15 wealth, when `tech_eras()` is read, then its entry
  has `opens` = "Opens at 8 pop or 15 wealth"; one needing only pop says "Opens at 8 pop"; an era with no unlock says
  "Opens through a tech"; a reached era's `opens` is "".
- [ ] AC2: The Knowledge screen's vellum shows `opens` from `tech_eras()`; `ui/knowledge_screen.gd` no longer contains
  "Opens at" (the `test_ui_structure` check).
- [ ] AC3: Given a hand card costing 1 food and 2 wealth with 0 food and 0 wealth on hand, when `play_error` is asked,
  then it returns "<Name> needs 1 food, 2 wealth (you have 0 food, 0 wealth)."; `build_error` for the same entry
  returns the same.
- [ ] AC4: Short of a single resource the message is unchanged ("Farm needs 2 food (you have 1).",
  "Colonist needs 8 food (you have 7)."): existing tests pass unedited.

## Out of scope
- Rewording any other message.

## Design notes
- `CardPlay.place_error` calls `e.price_error(card.def.name, cost)`.
- `Research.eras` adds `opens`; the vellum's `_opens` goes.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_ui_queries::test_tech_eras_say_how_an_era_not_reached_opens`; `test_tech_eras_list_each_era_with_its_status_and_techs` (now expects `opens`) |
| AC2 | `test_ui_structure::test_ui_asks_the_engine_for_targeting_tech_eras_and_open_piles` (no "Opens at" in knowledge_screen.gd) |
| AC3 | `test_build_menu::test_short_of_two_resources_play_and_build_name_both` |
| AC4 | existing, unedited: `test_build_menu::test_build_refuses_with_a_reason_and_changes_nothing`, `test_cost_per_territory` (Colonist), `test_ui_queries` / `test_wealth` (Farm, Guildhall) |

## Manual check
- [ ] The Knowledge screen's locked eras read as before.

## Log
- 2026-10-06: specced from the project review.
- 2026-10-06: picked up from `draft`; no open question found in the criteria. Red: 4 failing tests.
