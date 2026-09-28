---
id: 002
title: Explore reveals 2 territories, keep 1
type: feature
status: review
branch: feat/002-explore
---

## Goal
Playing an explore card reveals the top 2 territories. The player keeps one in the frontier
(discovered, unclaimed) and the other goes to the bottom of the territory deck. This gives Scout a
lasting effect and feeds settling (003).

## Acceptance criteria
In these criteria, `explorer` is a test action card with `{"op": "explore"}`. The territory deck is
arranged so the top (last element) is listed first.

- [x] AC1: Given a territory deck of [hills, grassland, jungle] (top first), when I play Explorer, then:
  - `pending_choice` offers exactly the Hills and Grassland uids
  - both are in the `reveal` zone
  - the territory deck holds only [jungle]
  - Explorer is in the discard pile.
- [x] AC2: Given AC1's pending choice, when I `choose(hills_uid)`, then:
  - it returns true
  - the frontier is [hills] and the reveal zone is empty
  - the territory deck is [jungle, grassland] (top first), so Grassland is at the bottom
  - `pending_choice` is empty.
- [x] AC3: Given a pending choice, when I check `play_error` on any hand card or call `end_turn`, then:
  - `play_error` is "Choose a territory first."
  - `play_card` returns false
  - `end_turn` leaves the turn number, hand, and food unchanged.
- [x] AC4: Given a pending choice, when I `choose` a uid that isn't one of the options, or call `choose`
  with nothing pending, then it returns false and nothing changes.
- [x] AC5: Given a territory deck of exactly 1 territory, when I play Explorer, then that territory goes
  straight to the frontier with no pending choice. Given an empty territory deck, when I play Explorer,
  then nothing is revealed, nothing is pending, and play continues.
- [x] AC6: Given `{"op": "explore"}`, when the data loads, then `reveal` defaults to 2 and the card text is
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
  - `choose` does not emit `card_played`: the Explorer's play was already reported, and the UI
    animates the territory's move by comparing zones on `changed`
- **Real data:** Scout becomes `explore` + `draw 1` (provisional; tuned in 006).
  `territory_deck` gets a starter set so exploring works in play.
- **UI:**
  - a choice panel shows the revealed territories while a choice is pending; clicking one calls `choose`
  - a frontier row appears above the tableau
  - End Turn is disabled while a choice is pending
  - **Drag interface (008):**
    - the `reveal` and `frontier` zones are drawn through the same persistent views as hand and tableau,
      each with its own container. The picked territory flies from the choice panel to the frontier row
      (and later, in 003, from the frontier into the tableau).
    - today `_refresh` sends every card that left the hand and tableau to the discard pile. Generalize it:
      a view that leaves flies towards the zone the card went to. Discard and deck go to their counters.
      A territory returned to the territory deck flies to the choice panel's edge and fades.
    - while a choice is pending, hand cards can't be picked up (no drag starts). The tooltip shows
      the engine's "Choose a territory first." Double-click is refused the same way.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_explore::test_explore_reveals_top_two_as_a_choice` |
| AC2 | `test_explore::test_choose_keeps_pick_in_frontier_and_buries_the_rest`, `test_explore::test_choose_emits_changed_but_not_card_played` (design note) |
| AC3 | `test_explore::test_pending_choice_blocks_play`, `test_explore::test_pending_choice_blocks_end_turn` |
| AC4 | `test_explore::test_choose_non_option_is_refused`, `test_explore::test_choose_with_nothing_pending_is_refused` |
| AC5 | `test_explore::test_explore_last_territory_goes_straight_to_frontier`, `test_explore::test_explore_empty_territory_deck_does_nothing` |
| AC6 | `test_data_loader::test_explore_defaults_to_reveal_2`, `test_data_loader::test_explore_reveal_0_is_error` |

## Manual check
- [ ] Playing Scout shows 2 territories to pick from. Picking one flies it into the frontier row, and
  the other slides away. End Turn is disabled until you pick.
- [ ] While the choice is open, trying to drag a hand card does nothing, and its tooltip says why.

## Log
- 2026-09-28: red. Added `jungle` (territory, 1 slot) and `explorer` (action, `explore`) to `TEST_CARDS`.
  Interface-only declarations committed with the tests so they parse: `pending_choice` and a
  `choose` that returns false.
- 2026-09-28: green. Engine: `explore(n, source)` helper, `choose`, `Zone.add_bottom`; options are
  listed top first. UI: an inline choice panel above the tableau (not a modal, so the hand's
  tooltips stay reachable) and a Frontier row; views moving between containers fly, and views that
  leave fly towards their zone (deck / discard counters, or the choice panel's edge for buried territories).
- Follow-ups: revealed territories pop into the panel rather than flying from a territory-deck
  counter (there is none yet). An `explore` on an `upkeep` trigger would open a choice at turn start;
  no card does that, so it's untested.
