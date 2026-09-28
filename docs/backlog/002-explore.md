---
id: 002
title: Explore reveals 2 territories, keep 1
type: feature
status: ready
branch: feat/002-explore
---

## Goal
Playing an explore card reveals the top 2 territories. The player keeps one in the frontier
(discovered, unclaimed) and the other goes to the bottom of the territory deck. This gives Scout a
lasting effect and feeds settling (003).

## Acceptance criteria
In these criteria, `explorer` is a test action card with `{"op": "explore"}`. The territory deck is
arranged so the top (last element) is listed first.

- [ ] AC1: Given a territory deck of [hills, grassland, jungle] (top first), when I play Explorer, then:
  - `pending_choice` offers exactly the Hills and Grassland uids
  - both are in the `reveal` zone
  - the territory deck holds only [jungle]
  - Explorer is in the discard pile.
- [ ] AC2: Given AC1's pending choice, when I `choose(hills_uid)`, then:
  - it returns true
  - the frontier is [hills] and the reveal zone is empty
  - the territory deck is [jungle, grassland] (top first), so Grassland is at the bottom
  - `pending_choice` is empty.
- [ ] AC3: Given a pending choice, when I check `play_error` on any hand card or call `end_turn`, then:
  - `play_error` is "Choose a territory first."
  - `play_card` returns false
  - `end_turn` leaves the turn number, hand, and food unchanged.
- [ ] AC4: Given a pending choice, when I `choose` a uid that isn't one of the options, or call `choose`
  with nothing pending, then it returns false and nothing changes.
- [ ] AC5: Given a territory deck of exactly 1 territory, when I play Explorer, then that territory goes
  straight to the frontier with no pending choice. Given an empty territory deck, when I play Explorer,
  then nothing is revealed, nothing is pending, and play continues.
- [ ] AC6: Given `{"op": "explore"}`, when the data loads, then `reveal` defaults to 2 and the card text is
  "Explore: reveal 2, keep 1". `reveal: 0` is an error naming the card and `reveal`.

## Out of scope
- Settling frontier territories (003).
- A frontier size limit.
- Other explore rewards, such as Ruins.

## Design notes
- **New op:** `explore` with `reveal` (int ≥ 1, default 2). Build it with the `add-effect` skill.
- **Engine:**
  - new zone `reveal`
  - `pending_choice: Dictionary` (`{options: Array[int], source: CardInstance}`; empty = none)
  - `choose(uid) -> bool`
  - `play_card`, `play_error`, and `end_turn` respect a pending choice
  - `changed` is emitted after `choose`
- **Real data:** Scout becomes `explore` + `draw 1` (provisional; tuned in 006).
  `territory_deck` gets a starter set so exploring works in play.
- **UI:**
  - a choice panel shows the revealed territories while a choice is pending; clicking one calls `choose`
  - a frontier row appears above the tableau
  - End Turn is disabled while a choice is pending

## Test plan
| AC | Test |
|---|---|

## Manual check
- [ ] Playing Scout shows 2 territories to pick from. Picking one adds it to the frontier row.
  End Turn is disabled until you pick.

## Log
