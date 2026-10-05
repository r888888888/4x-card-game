---
id: 287
title: Start with a single Scout in the deck
type: feature
status: done
branch: feat/287-one-scout-in-starting-deck
---

## Goal
The starting deck holds one Scout instead of two, so exploration is less front-loaded and the opening draws leave room
for other cards. More Scouts are still bought from the supply.

## Acceptance criteria
- [x] AC1: Given the real `data/config.json`, when the loader reads it, then it loads without errors and every starting
  `deck` id is a card in `data/cards.json` (existing deck invariants stay green).
- [x] AC2: Given a new game on the real data, when the deck is dealt, then the opening zones (draw pile and hand) hold as
  many cards as the sum of the `deck` counts (existing deal invariant stays green).

## Out of scope
- The Scout's supply price or pile size, and any Scout effect changes (balance item).
- Per-civilization starting decks.

## Design notes
- Data only: `"scout": 2` becomes `"scout": 1` in `deck` in `data/config.json`. No new fields, ops or engine API.
- Exact shipped numbers belong under Manual check, so no new test pins the Scout count; the existing content
  invariants cover AC1 and AC2.
- If a rules test depends on the real deck's Scout count, that is a smell: fix the test, not the data.

## Test plan
| AC | Test |
|---|---|
| AC1 | no new test: existing `test_content` deck invariants cover it |
| AC2 | no new test: existing deal-count invariant covers it |

## Manual check
- [ ] Shipped number: one Scout copy in `deck`; start `godot --path . -- --civ sumer --seed 5` and check the deck view.

## Log
- Data-only change: `scout` 2 → 1 in `deck`; suite 1855 tests, green.
