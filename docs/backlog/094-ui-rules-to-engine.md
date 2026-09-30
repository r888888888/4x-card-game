---
id: 094
title: Engine queries for the rules still in the UI (targeting choice, tech eras, open supply piles)
type: feature
status: in-progress
branch: feat/094-ui-rules-to-engine
---

## Goal
A few small rules are still decided in `ui/`, which CLAUDE.md forbids:
- `main.on_double_clicked` decides whether a play needs a target choice ([main.gd:225](../../ui/main.gd)).
- The tech tree modal groups techs by era, works out whether each era is reached or what unlocks it, and reads
  `config.research_deck` directly.
- The supply screen filters out locked piles itself.

Move each into an engine query under TDD, so the sim, future UIs and tests use the same answer.

## Acceptance criteria
- [ ] AC1: `needs_target_choice(uid)` is true only when hand card uid is playable (`playable_error` is ""), needs a
  target, and has more than one valid target. With Settled Homeland and Grassland, each with a free slot, and
  food to pay, a Farm in hand gives true; with only Homeland, false; with 0 food, false; a Scout (no target),
  false. `main.on_double_clicked` uses it in place of its own condition.
- [ ] AC2: `tech_eras()` returns one entry per era with techs in `research_deck`, in era order:
  `{era, name, reached, unlocks, techs}`. `name` is `era_name(era)` and `reached` is `era <= era()`. `unlocks` is
  that era's `upcoming_era_unlocks()` entry ({} when reached or when only a tech adds it). `techs` are that era's
  `tech_tree()` entries in the same order. With the `tech_case` fixture at era 1 and `era_unlocks {"2": {"pop": 8}}`,
  era 1 is reached with `unlocks` {}, and era 2 is not reached with `unlocks` {pop: 8}.
- [ ] AC3: The tech tree modal builds its columns from `tech_eras()`, formats the status text from `reached` and
  `unlocks`, and opens only when `tech_eras()` isn't empty. `ui/tech_tree_modal.gd` no longer reads
  `config` or groups techs. `test_tech_tree_modal` passes unedited.
- [ ] AC4: `open_supply_piles()` returns the supply's card ids whose piles aren't locked, in config order
  (a pile with 0 left still counts: it shows as sold out). The supply screen shows exactly these, and
  `SupplyScreen.can_open` needs at least one. With every pile locked, the screen doesn't open, where it used to
  open empty.
- [ ] AC5: All existing tests pass unedited, including `test_ui_smoke`, `test_tech_tree_modal` and the supply tests.
  The 20-seed sim output is identical before and after.

## Out of scope
- The drag gate in `main._on_drag_requested` (`not is_over`, no explore choice): it's about what the player can
  touch, not a rule, and the play is still refused by `play_error`.
- The "used slots" subtraction in `tableau_view.gd` (display arithmetic on two engine queries).
- Splitting `ui/main.gd` or moving its test hooks.

## Design notes
- New `GameEngine` API: `needs_target_choice(uid: int) -> bool`, `tech_eras() -> Array[Dictionary]`,
  `open_supply_piles() -> Array[String]`. Bodies in `CardPlay`, `Research` and `Supply`.
- `tech_eras` reuses `Research.tree`; `tech_tree()` stays for the details and existing tests.
- Watch `game_engine.gd`'s size (609 lines): three delegators with doc comments add about 15 lines.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_ui_queries::test_needs_target_choice_with_two_territories_to_pick_from`, `test_needs_target_choice_is_false_with_one_target_no_food_or_no_target`; `test_ui_structure::test_ui_asks_the_engine_for_targeting_tech_eras_and_open_piles` (main.gd) |
| AC2 | `test_ui_queries::test_tech_eras_list_each_era_with_its_status_and_techs`, `test_tech_eras_unlocks_are_empty_when_reached_or_only_a_tech_adds_the_era`, `test_tech_eras_is_empty_without_a_research_deck` |
| AC3 | `test_ui_structure::test_ui_asks_the_engine_for_targeting_tech_eras_and_open_piles` (tech_tree_modal.gd); `test_tech_tree_modal` unedited |
| AC4 | `test_ui_queries::test_open_supply_piles_are_the_unlocked_ones_in_config_order`, `test_supply_screen_does_not_open_when_every_pile_is_locked`; the structure test (supply_screen.gd) |
| AC5 | the existing suite unedited; `scripts/sim.sh` output diffed against the baseline taken before any change |

## Manual check
- [ ] Double-click a Farm with two settled territories: targeting starts. With one, it plays straight away.
- [ ] T opens the tech tree with the same columns and status lines as before.
- [ ] Buy Cards shows the same piles as before; a tech that unlocks a pile adds it.

## Log
- 2026-09-30: Specced from the project review (UI decides targeting, groups techs and filters the supply).
- 2026-09-30: Red. The spec's "Homeland and Grassland" setup is `grassland_engine(true)` (Grassland start + Hills
  settled), the existing fixture with two free territories. The era-2 fixture tech (Optics) is local to the test.
