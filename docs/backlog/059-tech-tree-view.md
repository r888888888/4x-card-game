---
id: 059
title: Tech tree modal (Knowledge)
type: feature
status: review
branch: feat/059-tech-tree-view
---

## Goal
Replace the "Techs: deck N · era N" label with a Knowledge button that opens a tech tree modal (TODO 6). The modal
shows every tech by era, with prereq lines, and each tech's state, cost now and what it gives. It's a view only: the
research rules are unchanged (025–029).

## Acceptance criteria
New engine API: `tech_tree() -> Array[Dictionary]`, one entry per tech in config `research_deck`, sorted by era and
then config order: `{id, era, prereq, state, cost, passes, gives: Array[String]}`. `state` is one of
`GameEngine.TECH_RESEARCHED`, `TECH_AVAILABLE` (in the research deck or revealed), `TECH_FUTURE` (era not added yet)
and `TECH_LOST`. `gives` lists the card ids the tech creates or unlocks, without duplicates. Also
`era_name(n) -> String`, from the optional config `era_names` (`{"1": "Stone Age"}`), default "Era n".

- [x] AC1: In a new game with the TEST research fixtures, every era-1 tech is available with its printed cost and
  0 passes, and every era-2 tech is future.
- [x] AC2: After buying one of 2 revealed techs, it is researched, and the other is available with 1 pass and a cost
  of printed − 1 (at least 1).
- [x] AC3: A tech that took its third pass is lost. A tech whose prereq is researched has cost printed − discount.
- [x] AC4: After `add_era(2)` (op or threshold), the era-2 techs are available.
- [x] AC5: `gives` for the Guilds fixture (057) is ["guildhall"] (create and unlock merged).
- [x] AC6: `era_name(1)` is "Stone Age" when config `era_names` has "1", and "Era 3" when it has no "3". A non-string
  name, or a key that isn't a positive integer, is a load error naming config.json and `era_names`.

## Out of scope
- Researching from the tree (research stays reveal-2).
- Hard prerequisites.

## Design notes
- `tech_tree` reads the research zones (`research_deck`, `research_reveal`, `researched`, `future_techs`,
  `lost_techs`) and existing `tech_cost` and `tech_passes` for uids. `TECH_*` constants live in `GameEngine`.
- UI: the research info label becomes a "Knowledge (T)" button. The modal has one column per era, titled with
  `era_name` and, for eras not yet added, the unlock thresholds from `upcoming_era_unlocks` (the tooltip moves here).
  Prereq lines connect techs. Researched, available, future and lost each have a style, and the header shows the
  research deck count. Clicking a tech opens its details (056). T or Esc closes it.
- Real data: add `era_names` {"1": "Stone Age", "2": "Bronze Age", "3": "Iron Age"}.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_tech_tree::test_new_game_tree_has_era_1_available_and_era_2_future` |
| AC2 | `test_tech_tree::test_bought_tech_is_researched_and_the_other_takes_a_pass` |
| AC3 | `test_tech_tree::test_third_pass_makes_a_tech_lost`, `test_researched_prerequisite_lowers_the_cost` |
| AC4 | `test_tech_tree::test_adding_era_2_makes_its_techs_available` |
| AC5 | `test_tech_tree::test_gives_merges_create_and_unlock` |
| AC6 | `test_tech_tree::test_era_names_come_from_config_with_a_default`, `test_era_names_validation` |
| UI | `test_tech_tree_modal::test_t_opens_the_tree_by_era_and_esc_closes_it`, `test_knowledge_button_opens_the_tree` |

## Manual check
- [ ] Knowledge (T) opens the tree. The columns read Stone Age and Bronze Age, and the Bronze Age column shows its
  thresholds until it's added.
- [ ] Prereqs read "after X" on each tech (text, not lines: approved at red). The states are distinguishable without
  colour alone (✔ Researched, ○ Available, … Later era, ✕ Lost).
- [ ] Clicking a tech opens its details.

## Log
- 2026-09-29: `GameEngine.tech_tree()`, `era_name()`, `TECH_*` constants; config `era_names` (real data: Stone,
  Bronze, Iron Age). Future techs show their printed cost. UI: `ui/tech_tree_modal.gd`; the research info label became
  the "Knowledge (T) · <era name>" button; the era thresholds moved from its tooltip into the tree's column headers.
  Techs open `CardDetailsModal.open_def` (definition details, no live cost line). `UIKit.buttons_in` replaces
  main's `_buttons_in` to keep `main.gd` under 500 lines.
