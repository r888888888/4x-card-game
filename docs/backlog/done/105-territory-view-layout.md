---
id: 105
title: Territory view layout: the territory as a framed box, its slots with free ones outlined, no bounce
type: feature
status: done
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
- [x] AC2 (revised at review): The territory is the box, not a card. At the top of the frame, a title line gives the
  territory's name and its info (the same text as its card's info line: slots, housing, keywords, rolled resources),
  then the stats line and Grow. The territory's card isn't in the view (it stays in the Realm); the slot area under the
  title holds only the city, then the buildings, in tableau order, and `card_uids()` lists just those.
- [x] AC3: Free slots. After the city and buildings, the slot area shows one empty-slot outline per free slot
  (`free_slots(T)`). Given Homeland (5 slots) with the Capital and 1 Farm, when a Temple is played onto it from the
  view, then there is one outline fewer. A territory with no free slots shows none.
- [x] AC4: Still a drop target anywhere on the view (101 AC4), outlines included.
- [x] AC5 (added at review): No bounce when navigating. Opening the view shows its city and buildings at once, at rest
  and full size (no pop-in); closing it removes them at once (nothing flies off); the territory's card in the Realm
  never moves. A card played while the view is open still flies to its slot and lands, as before.
- [x] AC6 (follows from AC2): In the view the card focus starts on the first city or building (101 AC6 said the
  territory's card); Left/Right, I and Esc work as before.

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
| AC2 | `test_the_territory_is_the_box_with_its_name_info_stats_and_grow_on_top` (replaces the large-card test) |
| AC3 | `test_free_slots_show_as_outlines_after_the_cards`, `test_a_full_territory_shows_no_outlines` |
| AC4 | `test_an_outline_is_a_drop_target_for_the_territory` |
| AC5 | `test_opening_shows_the_cards_at_once_without_a_bounce`, `test_closing_removes_the_cards_at_once`, `test_a_card_played_in_the_view_still_flies_in` (guard) |
| AC6 | 101's `test_keys_in_the_view_move_through_its_cards_show_details_and_esc_closes` (focus starts on the city) |
| Changed | 101's `test_clicking_a_territory_opens_its_view_in_place_of_the_realm` (`card_uids()` without the territory) and its keyboard test (the first card is the city, Right goes to the building) |

## Manual check
- [ ] Seed 1: open the home territory. Under the "← Realm  Realm › …" header, a purple-bordered, faintly purple box
  titled with the territory's name and its "▢ ⌂ · keywords" line, the stats line and Grow under that, then the Capital
  and buildings in a row, then dim outlines for the free slots. No territory card inside the box.
- [ ] Open and close a territory several times: the box grows out of the card and shrinks back, and the cards inside
  appear and vanish with it (no pop or bounce, nothing flies off). Play a building from the hand into the open view:
  it still flies in and lands.
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
- 2026-09-30: Review changes from the user: show the territory as text in the box instead of as a card (AC2 revised,
  AC6), and no bounce on the cards when navigating (AC5). Back to in-progress.
- 2026-09-30: Built the review changes. The frame's body is a title line (the territory's name, and
  `CardFace.territory_info`, now public, with its icons), a stats and Grow line, then the row; `hero` and
  `CardView.setup(..., large)` are gone; `card_uids()` lists only the city and buildings, so the territory's card stays
  in the Realm. `main` refreshes quietly after the view opens or closes (`_quiet`): new views `attach` at rest instead
  of popping in, and `_remove_view(uid, at_once)` frees the view's cards instead of flying them off. `CardFocus`
  puts the focus on the view's first card after Enter opens it.
- 2026-09-30: With the user's OK, `test_closing_removes_the_cards_at_once` counts only the view's cards on the effects
  layer (hand cards were still being dealt). `ui/main.gd` is at 675/700 lines.
