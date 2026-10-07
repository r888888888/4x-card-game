---
id: 388
title: Veteran pips on unit cards
type: feature
status: review
branch: feat/388-veteran-pips
---

## Goal
A veteran unit (165) wears its counters where the player sees it: a row of pips on its card in the territory view,
filled per counter and dim up to the cap, so a glance shows which garrisons have earned strength and how much more
they can earn. Today veterancy only shows as a "Strength N" tag and a line in the card's details.

## Acceptance criteria
- [x] AC1 (engine query): `unit_veteran_pips(uid)` returns `{filled, total}`: with config `veteran_max` 2, a unit in
  the tableau with 1 counter gives `{filled: 1, total: 2}` and a fresh one `{filled: 0, total: 2}`; with
  `veteran_max` 0, or for anything but a unit in the tableau (a territory, a building, a unit in hand, an unknown
  uid), `{filled: 0, total: 0}`.
- [x] AC2 (pips): Given `veteran_max` 2, when the territory view opens on Hills with a Levy holding 1 counter, the
  Levy's card shows a row of 2 pips, the first tinted the filled colour and the second the dim one; a Levy with 0
  counters on the same territory shows 2 dim pips.
- [x] AC3 (none): With `veteran_max` 0, no unit card shows a pip row; a card that isn't a unit never does.
- [x] AC4 (refresh): When a repelled raid gives the Levy its first counter, the open territory view's Levy shows 1
  filled pip once the raid modal closes, without reopening the view; a Levy that is disbanded and played again shows
  2 dim pips.
- [x] AC5 (tally): When a counter is gained, the new pip switches on with the tally (§10.3): it lights after the raid
  modal closes and plays one `ui.counter.tick`; several units promoted by one raid light one at a time, 60 ms apart,
  in tableau order. With Reduce motion the pips are lit at once, still with one tick each.

## Out of scope
- Chevrons or a new icon: pips are discs, the guide's indicator shape (§2 geometric vocabulary, `radius.full`).
- Pips anywhere but the unit's card (the details modal keeps its "Veteran 1 (+1 strength)" line; the Realm has no unit
  cards).
- Merging the training and veteran lines in the details (165's Log follow-up).

## Design notes
- New engine API: `unit_veteran_pips(uid) -> Dictionary` (`Military`), so the UI never reads `config.veteran_max` or
  `counters`. The UI takes the promoted uids from the `raid_resolved` outcome's `veterans` (165) for the tally.
- Placement: on the card face like the strength tag (`CardView.set_unit_strength`), set from the same loop in
  `board_views.gd` that sets the unit's origin and strength; the pip size, colours (`Palette`) and gap are tokens.
  Follow the pop meter's pattern (`TerritoryView._show_meter`, `_tint_pips`): filled and dim tints of one colour.
- UI tests go in a new `tests/test_veteran_pips.gd` (row in `docs/testing.md`); the engine query in
  `tests/test_veterans.gd`.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_veterans::test_a_units_pips_are_its_counters_out_of_veteran_max`, `test_no_pips_without_veterans_or_for_anything_but_a_unit_in_the_tableau` |
| AC2 | `test_veteran_pips::test_a_units_card_shows_its_counters_filled_out_of_the_cap` |
| AC3 | `test_veteran_pips::test_no_pips_without_veterans_or_on_a_card_that_isnt_a_unit` |
| AC4 | `test_veteran_pips::test_a_repelled_raids_counter_lights_once_the_modal_closes_as_a_tally`, `test_a_unit_played_again_starts_dim` |
| AC5 | `test_veteran_pips::test_a_repelled_raids_counter_lights_once_the_modal_closes_as_a_tally` (ticks at 0 and 60 ms), `test_with_reduce_motion_the_pips_light_at_once_with_a_tick_each` |

## Manual check
- [ ] `godot --path .`: play until a raid is announced at a territory, garrison it with a unit and enough defence, and
  open that territory's view: the unit shows 2 dim pips. Let the raid strike and close its modal: the first pip lights
  with a tick. Pips read clearly in day and night mode and don't crowd the strength tag or the "from Homeland" strip.
- [ ] Turn on Reduce motion and repeat: the pip appears lit with no animation.

## Log
- 2026-10-07: red. Decisions: after 394 the query is on the military area, `e.military.veteran_pips(uid)`, not
  `GameEngine.unit_veteran_pips` (the README's order put 388 after 394 for this). Pips are tinted `Palette.UNIT` lit
  and the same at alpha 0.35 dim (`CardView.PIP_DIM`), the pop meter's pattern; hook `CardView.veteran_pips()` gives
  each pip's tint. A turn's end closes the territory view (existing behaviour), so the strike tests open Hills' view
  under the open raid modal, then close the modal: the pip lights without reopening the view. Ticks are counted from
  the press of OK, since the resource odometers tick in the same turn. The tally's first pip lights at once, the next
  unit's 60 ms later (`Anim.TALLY_STEP`, new).
- 2026-10-07: green (2498 → 2505). The pip row is a `CardFace` part (`set_veteran_pips`, `light_veteran_pips`): 8 px
  discs (`Tokens.SPACE_2`, `RADIUS_FULL`) `SPACE_1` apart, under the card's info lines; `CardView` forwards and counts
  the lit ones for the tally. `TurnNews` keeps the promoted uids from `raid_resolved` until `RaidModal.dismissed`, then
  emits `veterans_promoted`; `BoardViews` holds those pips back while waiting and `tally_veterans` lights them.
  Sizes: `card_face.gd` 516, `card_view.gd` 581, `military.gd` 544 lines (each past the 500 WARN, under 700).
  Follow-up worth noting: if the raid modal never opens (the game ends on that turn), the pips stay one short; the
  game is over then.
