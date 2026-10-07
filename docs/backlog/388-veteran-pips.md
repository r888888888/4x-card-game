---
id: 388
title: Veteran pips on unit cards
type: feature
status: ready
branch: feat/388-veteran-pips
---

## Goal
A veteran unit (165) wears its counters where the player sees it: a row of pips on its card in the territory view,
filled per counter and dim up to the cap, so a glance shows which garrisons have earned strength and how much more
they can earn. Today veterancy only shows as a "Strength N" tag and a line in the card's details.

## Acceptance criteria
- [ ] AC1 (engine query): `unit_veteran_pips(uid)` returns `{filled, total}`: with config `veteran_max` 2, a unit in
  the tableau with 1 counter gives `{filled: 1, total: 2}` and a fresh one `{filled: 0, total: 2}`; with
  `veteran_max` 0, or for anything but a unit in the tableau (a territory, a building, a unit in hand, an unknown
  uid), `{filled: 0, total: 0}`.
- [ ] AC2 (pips): Given `veteran_max` 2, when the territory view opens on Hills with a Levy holding 1 counter, the
  Levy's card shows a row of 2 pips, the first tinted the filled colour and the second the dim one; a Levy with 0
  counters on the same territory shows 2 dim pips.
- [ ] AC3 (none): With `veteran_max` 0, no unit card shows a pip row; a card that isn't a unit never does.
- [ ] AC4 (refresh): When a repelled raid gives the Levy its first counter, the open territory view's Levy shows 1
  filled pip once the raid modal closes, without reopening the view; a Levy that is disbanded and played again shows
  2 dim pips.
- [ ] AC5 (tally): When a counter is gained, the new pip switches on with the tally (§10.3): it lights after the raid
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

## Manual check
- [ ] `godot --path .`: play until a raid is announced at a territory, garrison it with a unit and enough defence, and
  open that territory's view: the unit shows 2 dim pips. Let the raid strike and close its modal: the first pip lights
  with a tick. Pips read clearly in day and night mode and don't crowd the strength tag or the "from Homeland" strip.
- [ ] Turn on Reduce motion and repeat: the pip appears lit with no animation.

## Log
