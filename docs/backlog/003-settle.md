---
id: 003
title: Settle a discovered territory
type: feature
status: ready
branch: feat/003-settle
---

## Goal
Founding a City requires a discovered territory. Settler moves a frontier territory into the
tableau and founds a City on it, which makes exploring the gate for expanding.

## Acceptance criteria
In these criteria, `pioneer` is a test action card with cost 3 food and `{"op": "settle", "card": "city"}`.

- [ ] AC1: Given a frontier of [hills], 3 food, and Pioneer in hand, when I play Pioneer with no target, then:
  - it returns true
  - Hills and a new City are in the tableau
  - `territory_of(city)` is Hills
  - the frontier is empty and food is 0.
- [ ] AC2: Given a frontier of [hills, grassland], when I play Pioneer with no target, then `play_error` is
  "Choose a territory to settle." and play fails. When I play it with the Grassland uid, then Grassland is
  settled and Hills stays in the frontier.
- [ ] AC3: Given an empty frontier, when I try to play Pioneer, then `play_error` is "No discovered territory
  to settle.", Pioneer stays in hand, and food is unchanged.
- [ ] AC4: Given a frontier of [hills], when I play Pioneer targeting a uid that isn't in the frontier (for
  example the Capital), then `play_error` is "That target isn't valid." and nothing changes.
- [ ] AC5: `valid_targets(pioneer_uid)` returns the frontier uids. `valid_targets` returns [] for a card that
  needs no target. Passing a target to a card that needs none is ignored.
- [ ] AC6: Given `{"op": "settle", "card": "farm"}` (not a city) or an unknown card, when the data loads, then
  it is an error naming the card and the `card` field. The text for a valid settle is "Settle a discovered
  territory with a City".

## Out of scope
- Building slots (004).
- Real-data Settler cost changes (006).

## Design notes
- **New op:** `settle` with `card` (must be a `city`-type card). Build it with the `add-effect` skill.
- **Engine API:**
  - `play_card(uid, target_uid := -1)`
  - `play_error(uid, target_uid := -1)`
  - `valid_targets(uid) -> Array[int]`
  - `needs_target(uid) -> bool`
- **Check order:** game over → pending choice → in hand → cost → target.
  With exactly one valid target and no target given, the engine uses it.
- **Tests:** the existing `create` op and the TEST_CARDS `settler` stay as they are, so
  `test_create_card` still passes.
- **Real data:** Settler switches to `settle`.
- **UI:** clicking a card that needs a target (with more than one option) highlights the valid
  targets. Clicking one plays the card; Esc cancels.

## Test plan
| AC | Test |
|---|---|

## Manual check
- [ ] With 2 frontier territories, clicking Settler highlights both. Clicking one founds a City there.
- [ ] With 0 territories, Settler shows the reason on hover or click.

## Log
