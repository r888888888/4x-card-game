---
id: 342
title: Hover the territory view's building cards and free slots, with the hover tick
type: feature
status: in-progress
branch: feat/342-territory-view-hover
---

## Goal
In the territory view, the city and building cards and the empty build slots answer the pointer: the card lifts and
inks its border like a hand card does, the free slot inks its outline, and each gives the quiet `ui.hover` tick
(style guide §16, `ui.hover`, 245). Today the buildings are inert under the cursor (they open details on click but
show nothing on hover), and a free slot's "+ Build" ticks but doesn't change at all.

## Acceptance criteria
- [ ] AC1: Given a territory view open on a territory with a city and 1 building, when the mouse enters the building's
  card, then the card shows the hover look (border `Palette.TEXT`, `Surfaces.CARD_HOVER` lift, no scale) and `Sfx.HOVER`
  plays once; the city card does the same.
- [ ] AC2: Given a hovered building card, when the mouse leaves it, then it returns to its rest look and nothing plays;
  a fresh entry plays `Sfx.HOVER` again (subject to the existing `Sfx.HOVER_GAP`).
- [ ] AC3: Given the territory view closed (back on the Realm), when the mouse enters the territory's card in the
  Realm, then it keeps today's behaviour: no hover look and no sound. (Buildings aren't shown in the Realm; the view's
  units row also stays as today.)
- [ ] AC4: Given a territory with 2 free slots and a non-empty build menu with no `build_menu_error`, when the mouse
  enters free slot 0, then that outline's border turns `Palette.TEXT` (slot 1 unchanged) and `Sfx.HOVER` plays once
  (not twice: the outline and its "+ Build" key are one target); leaving restores `Palette.GHOST_EDGE`.
- [ ] AC5: Given a free slot whose "+ Build" is disabled (`build_menu_error` non-empty) or hidden (empty build menu),
  when the mouse enters it, then the outline doesn't change and nothing plays.
- [ ] AC6: Given a drag in progress or a mouse button held, when the cursor enters a building card or free slot, then no
  hover sound plays (as for every hover tick, 245).

## Out of scope
- Hover on Realm tableau cards, unit cards, and cards elsewhere (only the territory view's city/building row and slots).
- New sound tokens: this reuses `ui.hover`.
- Changing what a click on a building or slot does.

## Design notes
- Sound: `ui.hover` (`Sfx.HOVER`, Level 1, −8 dB, 80 ms gap) per the guide's `ui.hover` row and §16.8: it is the tick
  for "an enabled key or an actionable card"; a building card opens its details on click, so it counts. Update the
  guide's `ui.hover` row / §16.8 "silent by design" line to name the territory view's buildings and free slots.
- Visual: the card HOVER state of §15 (border ink, `shadow.card-hover`, no scale), the same `_set_hover` path as hand
  cards; no slide (only hand and supply cards rise, `lift_on_hover`). The free slot's outline inks its border like a card's hover border (§10, hover never changes hue).
- `CardView._set_hover` hovers only `in_hand or pickable`; add a flag the territory view sets on the views it places in
  its row (and clears when it gives them back to the Realm), e.g. `CardView.hoverable`. State lives on the view only
  while it is placed; nothing in `GameState`.
- The slot's "+ Build" key already ticks through `KeySounds` (enabled only); the outline's look follows that key's
  `mouse_entered`/`mouse_exited` so the sound stays single.
- UI only; engine untouched. Tests in `tests/test_territory_view.gd` or `tests/test_hover_sound.gd`.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_territory_view::test_entering_a_building_in_the_view_lifts_it_and_ticks_once`, `test_entering_the_city_in_the_view_lifts_it_and_ticks` |
| AC2 | `test_territory_view::test_leaving_a_building_restores_it_silently_and_a_fresh_entry_ticks_again` |
| AC3 | `test_territory_view::test_a_realm_card_has_no_hover` (guard: passes today) |
| AC4 | `test_territory_view::test_entering_a_free_slot_inks_its_outline_and_ticks_once` |
| AC5 | `test_territory_view::test_a_disabled_free_slot_is_unchanged_and_silent`, `test_a_free_slot_with_an_empty_build_menu_is_unchanged_and_silent` (guards: pass today) |
| AC6 | `test_territory_view::test_entering_a_building_or_slot_with_the_mouse_held_is_silent` (guard: passes today) |

## Manual check
- [ ] Open a territory and sweep the cursor over the city, buildings and free slots: each lifts or inks with a faint
  tick, never louder than a click.
- [ ] With nothing buildable, hover a free slot: silent and unchanged.
- [ ] Back on the Realm, hovering those same cards does nothing.

## Log
