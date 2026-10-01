---
id: 129
title: Permanent cards can carry standing modifiers, starting with extra actions each turn
type: feature
status: in-progress
branch: feat/129-standing-modifiers
---

## Goal
Governments set the base actions (127), but techs, buildings, civilizations and events should be able to change
them too: "+1 action each turn" on a tech, "−1 action while active" on an Unrest event. Rather than a new field for
each stat on each card type (109 and 110 each planned their own civilization-only field), any permanent card gets
one `modifiers` object, summed by one lookup. This item adds the field, the lookup and its first key, `actions`;
109 adds `hand_size` and 110 adds `housing`.

## Acceptance criteria
Fixtures: TEST `band` government (`actions: 2`, from 127); a TEST tech with `modifiers: {"actions": 1}`; a TEST
building (no cost) with `modifiers: {"actions": 1}`; a TEST event with `modifiers: {"actions": -1}` lasting 1 turn;
a TEST civilization with `modifiers: {"actions": 1}`.

- [ ] AC1 (loader): field `modifiers` is optional on buildings, cities, techs, civilizations, governments and
  events: an object whose keys are in `DataLoader.MODIFIER_KEYS` (just `"actions"` here) and whose values are
  non-zero ints (negative allowed). An unknown key, a non-int or 0 is a load error naming the card and
  `modifiers.<key>`. On an action or territory card it's an unknown-field warning (`TYPE_FIELDS`).
- [ ] AC2 (lookup): new `modifier(key) -> int` sums `key` over the tableau cards that aren't idle, the cards in
  `ALWAYS_ON_ZONES` (researched techs, civilization, government) and the active events; 0 when none has it. A
  building that goes idle stops counting; one staffed again counts again.
- [ ] AC3 (actions): `actions_per_turn()` is the government's `actions` plus `modifier("actions")`, never below 1.
  Given `band` with the tech researched it's 3; with the civilization as well, 4; with only the event active, 1;
  after the event ends, 2 again.
- [ ] AC4 (mid-turn): given `band` and the +1 building in hand, playing it uses 1 action and leaves `actions_left()`
  2 (3 − 1). Buying the +1 tech mid-turn likewise raises `actions_left()` by 1 at once.
- [ ] AC5 (unlimited): with no `actions` on the government, modifiers don't limit anything: `actions_per_turn()`
  stays -1.
- [ ] AC6 (text): a card with `modifiers: {"actions": 1}` has the text "+1 action each turn"; with -1, "−1 action
  each turn"; on an event the tooltip adds "while active".

## Out of scope
- Other keys (`hand_size` in 109, `housing` in 110) and discounts (108 keeps its own field: a discount needs a filter,
  not just a number).
- Content: no shipped card gets `modifiers` here; candidates (a Bronze Age tech, a Palace building, an Unrest event)
  belong to a content item.

## Design notes
- New `CardDef` field `modifiers` (`{key: int}`, via `TYPE_FIELDS`) and `DataLoader.MODIFIER_KEYS`.
- New module `engine/modifiers.gd` (`class_name Modifiers`): `total(e, key)` walks the same cards as
  `TurnLoop.resolve_upkeep` (working tableau, `ALWAYS_ON_ZONES`, active events). Share the "working cards" walk with
  `resolve_upkeep` rather than copying it. `GameEngine.modifier(key)` delegates.
- The floor of 1 keeps a turn from being skipped outright by a harmful event.
- A building's own `housing` field (its territory, idle or not) is unchanged; `modifiers.housing` (110) is the
  everywhere bonus, and like every modifier it stops while its building is idle.
- Card details list the modifier under the card's rules, with the "Actions" glossary term from 127.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_modifiers::test_modifiers_load_on_permanent_cards`, `test_modifiers_validation` |
| AC2 | `test_modifiers::test_modifier_sums_working_cards_always_on_zones_and_active_events`, `test_an_idle_building_stops_counting` |
| AC3 | `test_modifiers::test_actions_per_turn_adds_the_actions_modifier`, `test_actions_per_turn_never_drops_below_1` |
| AC4 | `test_modifiers::test_a_modifier_played_mid_turn_counts_at_once`, `test_a_tech_bought_mid_turn_counts_at_once` |
| AC5 | `test_modifiers::test_modifiers_dont_limit_unlimited_actions` (a guard: passes already) |
| AC6 | `test_modifiers::test_modifier_text` |

## Manual check
- [ ] With a test data tweak (Calendar given `modifiers: {"actions": 1}`), researching it raises the top bar's
  counter at once and every turn after.

## Log
