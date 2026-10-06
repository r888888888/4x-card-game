---
id: 352
title: Flavor text for buildings
type: feature
status: review
branch: feat/352-building-flavor
---

## Goal
Buildings (Farm, Granary, the wonders, …) read like history, not just rules: every building carries a short flavor
line in its details window, like actions (351), techs and events (215). Buildings take no quote. Today buildings
are the loader's standard example of a card that may not set `flavor`.

## Acceptance criteria
- [x] AC1: Given a `TEST_CARDS` building with `"flavor": "Mud brick, baked hard."`, when the cards load, then there
  are no errors or warnings, and both `def_details(id)` and `card_details(uid)` of that building on a territory
  return that `flavor`.
- [x] AC2: Given a building whose `flavor` is `3` or `""`, when the cards load, then the loader reports
  "'flavor' must be a non-empty string", naming the card (as for a civilization, 107).
- [x] AC3: Given a building with `"quote": {"text": …, "by": …}`, when the cards load, then it warns that `quote`
  doesn't apply (ignored), and its details' `quote` is `{}`.
- [x] AC4: Given a territory with `flavor`, when the cards load, then it warns "'flavor' only applies to
  civilizations (ignored)": territories, cities and units still take no flavor.
- [x] AC5: Given a building with a flavor, when its card face is built (`CardView.setup`, in hand and not),
  then the face's lines are the same as for the card without it: flavor shows only in the details window.
- [x] AC6 (content): in `data/cards.json` every building, projects and upgrades included, has a `flavor`
  (`test_content.gd` invariant).

## Out of scope
- Quotes on buildings.
- Flavor on territories, cities or units.
- Flavor on any card face, or in the territory view's building rows.

## Design notes
- Builds on 351 (actions): start from `main` once 351 is merged, since both edit `TYPE_FIELDS.flavor`.
- Data: `TYPE_FIELDS.flavor` gains `CardDef.BUILDING`; `quote` is unchanged. Update the `CardDef.flavor` comment
  and `_parse_flavor`'s doc comment.
- Existing tests that change (AC4): `test_tech_event_flavor::test_flavor_on_a_building_is_still_ignored_with_a_warning`
  and the "flavor on a building" case in `test_civ_flavor::test_flavor_and_quote_validation` use a building as the
  card that may not have flavor; they switch to a territory (same warning).
- `card_details` / `def_details` already return `flavor` and the details modal shows it first, so no UI change.
- Content: 54 buildings today, one sentence each (≤ ~25 words), historical in tone, no rules talk. Wonders name
  their real monument (Pyramids, Hanging Gardens, Great Library, …); an upgrade's line can follow on from its base's.
- `docs/testing.md` is at its 25 KB cap (351's Log): don't grow it; the test file's `##` header names 352.
- PLAN.md: extend the Flavor (107) paragraph.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_tech_event_flavor::test_a_building_may_have_flavor` |
| AC2 | `test_tech_event_flavor::test_building_flavor_validation` |
| AC3 | `test_tech_event_flavor::test_a_quote_on_a_building_is_ignored_with_a_warning` (already passes: guards the rule) |
| AC4 | `test_tech_event_flavor::test_flavor_on_a_territory_is_still_ignored_with_a_warning` (was `…_on_a_building_…`), the "flavor on a territory" case of `test_civ_flavor::test_flavor_and_quote_validation` (was "on a building"); both already pass |
| AC5 | `test_tech_event_flavor::test_a_building_face_shows_no_flavor` |
| AC6 | `test_content::test_every_building_has_flavor` |

## Manual check
- [ ] Open a few buildings' details from hand and from a territory (a basic one, an upgrade, a wonder): italic
  flavor, then the rules.
- [ ] Building faces in hand, on the board and in the territory view look exactly as before.
- [ ] Read through all building lines for tone, accuracy and length.

## Log
- 2026-10-06: AC3 and AC4 held before the change; their tests guard the rules. The two tests that used a building as
  the card that may not have flavor now use a territory (same warning).
- `docs/testing.md` unchanged (at its 25 KB cap); the test file's `##` header names 352.
- Lines to double-check at the manual check: Hanging Gardens (hedged with "it was said": its existence is debated),
  Walls of Uruk (credited to Gilgamesh by the epic; ~9 km is the usual estimate), Mint (Lydian electrum, the lion
  stamp), Dye Works (Tyrian purple's value varies by source).
