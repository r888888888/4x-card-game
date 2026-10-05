---
id: 285
title: Seed the starting deck with a warrior card
type: feature
status: red-review
branch: feat/285-warrior-in-starting-deck
---

## Goal
Every game starts with a military unit in the deck, so the player meets Warriors (strength, a defense against raids,
a food upkeep) from the first shuffle instead of only after buying one from the supply.

## Acceptance criteria
- [ ] AC1: Given the real `data/config.json`, when the loader reads it, then the starting `deck` holds at least one
  card of type `unit` tagged `military`, and every such id is a card in `data/cards.json`.
- [ ] AC2: Given a new game on the real data, when the deck is dealt, then at least one `military` unit is among the
  cards in the draw pile and hand (the opening zones), and the count of cards matches the sum of `deck` counts.
- [ ] AC3: Given the starting deck has a `military` unit, when `test_every_starting_deck_building_has_a_supply_pile`
  and the other deck invariants in `test_content.gd` run, then they still pass (a deck unit's supply pile, if any,
  keeps a positive count).

## Out of scope
- Balance of the Warriors' upkeep or supply price (balance item).
- Per-civilization starting decks.
- Bot rule changes: `ScriptedBot` already plays Warriors like any unit.

## Design notes
- Data only: add `"warriors": 1` to `deck` in `data/config.json`. The `warriors` card and its supply pile (6) exist.
- No new fields, ops or engine API.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_content::test_the_starting_deck_holds_a_military_unit` |
| AC2 | `test_content::test_a_new_game_deals_a_military_unit_among_the_opening_cards` |
| AC3 | no new test: the existing deck invariants (e.g. `test_every_starting_deck_building_has_a_supply_pile`) already cover it and stay green |

## Manual check
- [ ] Shipped number: one Warriors copy in `deck`; start `godot --path . -- --civ sumer --seed 5` and find it
  in the deck view.

## Log
