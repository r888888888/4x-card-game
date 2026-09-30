---
id: 101
title: Territory view: click a territory to see its city and buildings
type: feature
status: in-progress
branch: feat/101-territory-view
---

## Goal
First half of the territory rework (102 is the second). Clicking a settled territory opens a territory view in
place of the Realm: the territory's card, its stats, its Grow button, and its city and buildings, with Back to the
Realm. The top bar, side panel and hand stay, so you can still play onto the territory or end the turn. Once this
exists, 102 can shrink the Realm's territories to plain cards.

## Acceptance criteria
<!-- UI tests in the real main scene (tests/test_territory_view.gd) on seed 1 unless a fixture is named. -->
- [ ] AC1: Open. Given seed 1 has started, when I click the Capital's territory card in the Realm, then the territory
  view is open for that territory's uid, the Realm section is hidden, and the top bar, side panel and hand are still
  shown. The view shows the territory's card and one card view for each tableau card on that territory (its city and
  buildings), in tableau order, and no card from another territory.
- [ ] AC2: Stats and Grow. The view shows "U / S slots used" (`total_slots` − `free_slots`, `total_slots`) and, with
  population on, "Pop P / H" (`pop`, `housing`), and a Grow button reading "Grow (N food)" with N = `grow_cost`.
  Grow is disabled with `grow_error` as its tooltip when that is non-empty; when enabled, pressing it calls
  `grow(uid)`, and pop and the Pop stat go up by 1. Without population (config off), no Pop stat and no Grow.
- [ ] AC3: Back. Pressing Back, or Esc with nothing to cancel (no targeting, drag or open modal), closes the view and
  shows the Realm again. Starting a new game (menu Restart, New game) and the game ending also close it.
- [ ] AC4: Playing onto the viewed territory. With the view open for territory T, dropping a dragged building or city
  from the hand anywhere on the view plays it onto T (`play_card(uid, T)`); if that is illegal, nothing is played
  and the engine's `play_error` for target T is shown as today. Double-clicking such a card in the hand plays it onto
  T when T is a valid target, and otherwise logs the engine's reason. The new card appears in the view.
- [ ] AC5: Targeting wins. While a hand card is waiting for a target (double-clicked with several targets), clicking
  a territory card picks it as the target, as today, and does not open the view.
- [ ] AC6: Keyboard. With the keyboard focus on a territory card in the Realm, Enter opens its view. In the view the
  focus starts on Back; Tab and the arrows reach Grow and the view's cards; Esc works like Back (AC3); I on a
  focused card opens its details.

## Out of scope
- The Realm's look: territories stay as today's groups until 102.
- Frontier territories (unsettled): clicking them does nothing new.
- Paging between territories inside the view.

## Design notes
- UI only: every value comes from existing engine queries (`total_slots`, `free_slots`, `pop`, `housing`,
  `grow_cost`, `grow_error`, `grow`, `play_error`, `valid_targets`, `territory_groups`).
- A `TerritoryView` component (`ui/territory_view.gd`) swapped with the Realm section in `_play_area`. Test hooks:
  `main.territory_view.is_open()`, `.uid`, `.back_button`, `.grow_button`, `.card_uids()` (the cards shown, the
  territory first) and `.stats_text()`.
- `ui/main.gd` is at 669/700 lines: the wiring must stay small, or this item first moves the start-screen navigation
  out (099's Log names that boundary). Say at the red checkpoint which.
- The view's cards reuse `CardView` (tableau size) and the board's `views` map, so a card never has two views at
  once. Its card views are the ones the Realm shows today: opening the view moves them, Back moves them back.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_territory_view::test_…` |

## Manual check
- [ ] Seed 1: click the Capital. The Realm is replaced by the Capital, its city and buildings, stats and Grow; the
  hand is still at the bottom. Back returns to the Realm with nothing out of place.
- [ ] Drag a Farm from the hand onto the view: it lands in the view.
- [ ] Right-click a building in the view: its details open above the view.

## Log
- 2026-09-30: Specced. The user chose: the view replaces the Realm on the board (hand, top bar and side panel
  stay); stats show on the Realm card (102) and Grow only in the view; you can play onto the card or anywhere on the
  view; collapse goes away and cards on no territory show as ordinary Realm cards (102).
