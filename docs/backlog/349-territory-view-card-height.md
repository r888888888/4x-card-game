---
id: 349
title: The territory view's cards open far too tall
type: bug
status: review
branch: fix/349-territory-view-card-height
---

## Bug
Opening a territory's view in a new game (seed 5, Egypt) shows the Capital and the free-slot outlines 1394 px tall
when 226 px holds the Capital's text: the row runs off the bottom of the window.

## Root cause
345 gives every card in the view the tallest card's height, measured in `refresh`. A card made by that refresh has not
been laid out yet: its face is 1 px wide, so its wrapped text measures one character per line and its minimum height is
huge. That height is kept as every card's `min_height` and the outlines' height until the next refresh.

## Acceptance criteria
- [x] AC1: Given a new game with the Capital on Homeland, when the player opens Homeland's view, then once it is laid
  out the Capital and every free-slot outline are the height of the tallest card measured at its width (175 here, the
  tableau height), not more.
- [x] AC2: 345's criteria still hold (two ribbons make every card and outline the Farm's height; they shrink back when
  the ribbons go).

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_territory_view::test_bug_349_cards_open_no_taller_than_the_tallest_needs` |
| AC2 | `test_upgrade_ribbons::test_the_view_s_cards_and_outlines_share_the_tallest_height`, `test_upgrade_ribbons::test_the_view_s_cards_shrink_back_when_the_tallest_goes` |

## Manual check
- [ ] `godot --path . -- --civ egypt --seed 5`, click Thebes: the Capital and the empty slots are one card tall.

## Log
- Fix: the view measures its cards again every frame while open (`_process`), so a card made by a refresh is
  re-measured once laid out; its first frame may still be tall, under the opening transition.
- Checked on the real data (seed 5, Egypt): the Capital and the outlines settle at 226 px.
- Built without a red-checkpoint stop: the user asked for the fix directly and it is UI-only (as 244, 345).
