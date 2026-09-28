---
id: 003
title: Settle a discovered territory
type: feature
status: in-progress
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
- [ ] AC7: The `card_played` outcome (007) gains `target: int`. It is the uid the card was played on (given, or
  picked by the engine when there was exactly one), or -1 for a card that needs no target. Given a frontier of
  [hills, grassland], when I play Pioneer targeting Grassland, then `target` is the Grassland uid. Given a
  frontier of [hills] and no target given, `target` is the Hills uid. Playing a Farm gives `target: -1`
  (until 004 gives buildings targets).

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
- **UI (drag interface, 008):**
  - **Drag onto a target:** when a card that needs a target is picked up, only its `valid_targets`
    light up, not the whole tableau. Dropping on one calls `play_card(uid, target_uid)`.
    - If there is exactly one valid target, dropping anywhere in the drop zone plays it (the engine picks it).
    - Otherwise, dropping away from a target shakes the card back with "Choose a territory to settle."
    - Hovering a card over a target it can't use turns the card red, and the reason comes from
      `play_error(uid, target_uid)`.
  - **Drop zone:** the frontier row (002) becomes part of the drop zone. Settle targets live there,
    outside the tableau.
  - **Double-click fallback:** double-clicking a card with several valid targets enters targeting mode.
    The targets light up, clicking one plays the card, and Esc or right-click cancels. With one target,
    double-click plays straight away.
  - **Animation:** use the outcome's `target` (AC7) to fly an action like Settler to its target
    before it goes to the discard pile, so the player sees where the City was founded.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_settle::test_settle_founds_city_on_only_frontier_territory` |
| AC2 | `test_settle::test_settle_needs_a_target_when_several_territories`, `test_settle::test_settle_chosen_territory` |
| AC3 | `test_settle::test_settle_with_empty_frontier_fails`, `test_settle::test_cost_is_checked_before_target` (check order) |
| AC4 | `test_settle::test_settle_on_invalid_target_fails` |
| AC5 | `test_settle::test_valid_targets_are_frontier_territories`, `test_settle::test_untargeted_card_has_no_targets_and_ignores_one` |
| AC6 | `test_data_loader::test_settle_text`, `test_data_loader::test_settle_non_city_is_error`, `test_data_loader::test_settle_unknown_card_is_error` |
| AC7 | `test_settle::test_outcome_target_is_given_target`, `test_settle::test_outcome_target_is_engine_pick`, `test_settle::test_outcome_target_for_untargeted_card` |

## Manual check
- [ ] With 2 frontier territories, picking up Settler lights up both (and not the tableau). Dropping it
  on one founds a City there: the Settler flies to the territory, and the territory and new City
  move into the tableau. Dropping it on empty tableau space shakes it back with "Choose a territory to settle."
- [ ] With 1 frontier territory, dropping Settler anywhere in the tableau or frontier settles it.
- [ ] Double-clicking Settler with 2 territories lights them up. Clicking one settles it, and Esc cancels.
- [ ] With 0 territories, Settler is greyed out, its tooltip gives the reason, and dropping it shakes it back.

## Log
- 2026-09-28: red. Added `pioneer` to `TEST_CARDS`. Interface-only declarations committed with the
  tests so they parse: optional `target_uid` on `play_card`/`play_error` (ignored), `valid_targets`
  returning [], `needs_target` returning false.
