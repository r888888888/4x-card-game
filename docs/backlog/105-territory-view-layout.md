---
id: 105
title: Territory view layout: framed, the territory large, its slots with free ones outlined
type: feature
status: review
branch: feat/105-territory-view-layout
---

## Goal
Make the territory view (101) look like the inside of a place, not the Realm rearranged: a frame in the territory
colour, the territory itself as a large card on the left with its stats and Grow under it, and on the right its city
and buildings in slots, with an outline for each free slot so the capacity shows at a glance and buildings have an
obvious place to go. Uses 104's header.

## Acceptance criteria
<!-- UI tests in the real main scene on a TEST_CARDS game (tests/test_territory_view.gd). -->
- [x] AC1: Frame. The open view is inside a panel whose border colour is `CardView.TYPE_COLORS` for territories and
  whose background is tinted (not transparent).
- [x] AC2: The territory large on the left. The territory's card is at `CardView.HAND_SIZE`, left of the slot area,
  with the stats line and Grow under it; the slot area holds the city, then the buildings, in tableau order.
- [x] AC3: Free slots. After the city and buildings, the slot area shows one empty-slot outline per free slot
  (`free_slots(T)`). Given Homeland (5 slots) with the Capital and 1 Farm, when a Temple is played onto it from the
  view, then there is one outline fewer. A territory with no free slots shows none.
- [x] AC4: Still a drop target anywhere on the view (101 AC4), outlines included.

## Out of scope
- Hiding the Frontier, Known and Events sections while the view is open (the user chose not to).
- Per-slot placement (a building dropped on a particular outline goes in that slot): slots have no order in the engine.

## Design notes
- UI only. The outline is a `Panel` like `TableauView.ghost`, sized `CardView.TABLEAU_SIZE`, dashed or dim border.
- Test hooks: `territory_view.frame` (the panel), `territory_view.free_slot_count()` (outlines shown).
- 101's `card_uids()` keeps listing the territory first, then the city and buildings.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_territory_view::test_the_view_is_framed_in_the_territory_colour` |
| AC2 | `test_the_territory_is_large_on_the_left_with_its_stats_and_grow_under_it` |
| AC3 | `test_free_slots_show_as_outlines_after_the_cards`, `test_a_full_territory_shows_no_outlines` |
| AC4 | `test_an_outline_is_a_drop_target_for_the_territory` |

## Manual check
- [ ] Seed 1: open the home territory. Under the "← Realm  Realm › …" header, a purple-bordered, faintly purple panel
  with the territory card large on the left, the stats line and Grow under it, the Capital and buildings in a row on
  the right, then dim outlines for the free slots. The large card grows out of the Realm card as the view opens.
- [ ] Drag a building onto an outline: it lands and one outline goes.

## Log
- 2026-09-30: Specced with 104, after the user said the territory view gives no sign you're in it.
- 2026-09-30: Built. `TerritoryView` is header, then `frame` (a panel bordered in `Palette.TERRITORY`, its background
  `Palette.RAISED` tinted 12% towards it) holding a left column (`hero` with the territory's card, the stats line
  wrapped to the card's width, Grow) and the `row` (city, buildings, then `outlines()`, one per `free_slots`, from the
  new `UIKit.slot_outline()` the Realm's ghost now uses too). `CardView.setup(..., large)` gives a board card the hand
  size; `main._place` passes it for `hero`. `CardFocus` walks `hero` then `row`.
- 2026-09-30: With the user's OK, the AC2 test checks where the territory's card rests (`card.slot` in `hero`): it is
  still flying from the Realm when the view's transition ends.
