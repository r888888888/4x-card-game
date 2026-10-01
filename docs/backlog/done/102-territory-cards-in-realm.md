---
id: 102
title: Territories show as plain cards in the Realm
type: feature
status: done
branch: feat/102-territory-cards-in-realm
---

## Goal
Second half of the territory rework (after 101). In the Realm, each settled territory is a conventional card at
tableau size, not a framed group with its city and buildings inside it. The card shows its slots and pop, and you
click it to open the territory view (101) for the city, buildings and Grow. Collapsing (087) goes away: every
territory is compact now.

## Acceptance criteria
<!-- UI tests in the real main scene on seed 1 unless a fixture is named. -->
- [x] AC1: One card per territory. Given seed 1 has started and a Farm is built on the Capital, the Realm shows
  exactly one card view per settled territory, in tableau order, each at `CardView.TABLEAU_SIZE`, and no view for a
  city or building on a territory (their views exist only while that territory's view (101) is open).
- [x] AC2: Cards on no territory. Given a fixture game with a tableau card that has no territory (`territory_uid`
  −1), the Realm shows it as an ordinary card after the territory cards.
- [x] AC3: Stats on the card. Each territory card shows "U / S slots" and, with population on, "Pop P / H", from the
  same engine queries as 101's view; after a building is placed on it, the card's slots text goes up by 1 without
  reopening anything.
- [x] AC4: Playing onto a territory card. Dragging a building from the hand over a territory card lights the valid
  target cards (`valid_targets`), and dropping it on one plays it there (`play_card(uid, T)`); dropping on an invalid
  one plays nothing and shows `play_error` for that target. In targeting mode (double-click), clicking a lit
  territory card plays onto it (101 AC5). The keyboard targeting moves between territory cards.
- [x] AC5: No collapse and no Grow in the Realm. There is no Collapse all / Expand all button, no ▾/▸ toggle, and no
  Grow button in the Realm (Grow lives in the territory view). `TableauView`'s collapse API is gone.
- [x] AC6: A new territory (settled with a Settler) appears as a new card in the Realm with its stats, and clicking it
  opens its view with its city.

## Out of scope
- Engine changes: `territory_summary` (087) stays unless nothing uses it after this item; if so, remove it and its
  tests in the refactor step and say so in the Log.
- Showing how many idle buildings a territory has on its card (a follow-up if wanted).

## Design notes
- Existing tests that change (name each at the red checkpoint): `tests/test_collapse_territories.gd` is deleted
  (collapse is gone; its keyboard-targeting and drop-target cases move to this item's tests);
  `tests/test_territory_row.gd` (078: a full territory's cards wrap) is deleted or rewritten, since the row no longer
  holds a territory's cards; `test_button_widths::test_board_buttons_fit_their_text` drops Collapse all and the
  group buttons.
- The territory card's stats line is a card-face info line, like a tech's cost line (`CardView.set_*_info`).
- A played building or city lands on its territory's card in the Realm (the card flies there and fades) unless the
  territory view is open, where it takes a slot in the view.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_territory_cards::test_the_realm_shows_one_card_per_territory` |
| AC2 | `test_a_card_on_no_territory_follows_the_territories` |
| AC3 | `test_a_territory_card_shows_its_slots_and_pop` |
| AC4 | `test_dragging_a_building_lights_its_targets_and_a_drop_plays_it_there`, `test_dropping_on_a_territory_that_cannot_take_it_says_why` (guard), `test_clicking_a_lit_territory_card_while_targeting_plays_there` (guard), `test_keyboard_targeting_moves_between_territory_cards` (guard) |
| AC5 | `test_the_realm_has_no_collapse_toggles_or_grow` |
| AC6 | `test_settling_adds_a_territory_card_that_opens_with_its_city` |
| 078 | `test_many_territories_wrap_instead_of_widening_the_realm` (replaces `test_territory_row.gd`) |
| Changed | `tests/test_collapse_territories.gd` and `tests/test_territory_row.gd` deleted; `test_button_widths::test_board_buttons_fit_their_text` checks the territory view's Back and Grow instead of Collapse all and the group buttons |

## Manual check
- [ ] Seed 1: the Realm is a tidy row of territory cards the same size as other tableau cards, each with its gold
  slots and pop line at the bottom; no Collapse all, no ▾, no Grow.
- [ ] Play a building by dragging it onto the home territory's card (the card lights while dragging): it flies onto
  the card and fades, and the card's slots go up. Double-click one with two territories settled: both cards light;
  click one.
- [ ] Settle a new territory: a new card appears; click it to see its city.
- [ ] Play a long game (turn 60+): the Realm stays one or two rows and End turn stays on screen at 1080p.

## Log
- 2026-09-30: Specced with 101. The user chose: stats on the Realm card, Grow only in the view; play onto the card or
  anywhere on the view; collapse removed; cards on no territory shown as ordinary Realm cards.
- 2026-09-30: Built. `TableauView` is one `HFlowContainer` (`row`) with `realm_uids(e)` (territories, then cards on no
  territory) and a ghost for untargeted permanents only; collapse, groups, banners (`CardView` / `CardFace`) and
  `group_at` are gone. `main._refresh` shows a city or building only while its territory's view is open (else its
  view leaves towards the territory's card) and sets each territory card's stats line
  (`CardView.set_territory_info`, text from `TerritoryView.stats`). `DragController.target_at(point)` is public.
- 2026-09-30: With the user's OK, 101's `test_clicking_a_city_or_building_still_shows_its_details` opens the
  territory view before clicking the Capital (a city has no Realm card now); I missed it at the red checkpoint.
- 2026-09-30: `territory_summary` stays: `TerritoryView.is_territory` asks it. Its counts (cities, buildings, idle)
  aren't shown anywhere now; a follow-up could show idle buildings on the territory card (out of scope here).
- 2026-09-30: `ui/main.gd` went from 683 to 668 lines.
