---
id: 381
title: Hand-size cards carry an art plate, with a placeholder until the picture exists
type: feature
status: red-review
branch: feat/381-card-art-plates
---

## Goal
Every card gets a picture (style guide §19, the list in `docs/design/card-art.md`), shown as a plate under the type
band on hand-size faces. Until a card's picture is drawn, the plate is a placeholder printed in the card type's
colour with a period motif, so the layout is final now and art can be dropped in file by file
(`assets/cards/<card id>.png`) with no code change. Hand cards grow to 264 × 360 to make room. From `spike/card-art`.

## Acceptance criteria
<!-- UI tests build CardViews as test_card_faces does. "Hand-size face": CardView.setup with in_hand true. -->
- [ ] AC1: Given a hand-size face for a card with no file at `CardArt.file_for(id)`, when it is built, then the face
  has one `CardArt` child named `Art`, placed directly after the type band, full width and 96 px tall
  (`CardArt.HAND_HEIGHT`), whose `has_picture()` is false; the placeholder prints no text (the face's `text()` is
  unchanged by the plate).
- [ ] AC2: Given a PNG in the art directory for a card id (tests point `CardArt`'s directory at a fixture holding one
  1536 × 1024 image), when that card's hand-size face is built, then its plate's `has_picture()` is true and the
  picture is drawn cropped to the plate from its centre (the middle 5:2 band of a 3:2 image); a card without a file
  in the same run still gets the placeholder.
- [ ] AC3: Given the same card, when its face is built hand-size (the hand, the details modal, the Build modal, the
  event or raid modal, Renewal), then it has the plate; when built tableau-size, in the Realm's row or as a supply
  pile, then it has none.
- [ ] AC4: `CardView.HAND_SIZE` is 264 × 360, and the hand's slots are `HAND_SIZE.y + Anim.LIFT_ROOM` tall (as the
  existing slot test checks against the constant).
- [ ] AC5: `Palette.ART_SHADE` is black at 25 % in Night and fully transparent in Day, and is drawn over the plate
  (picture or placeholder) under its 1 px `EDGE` frame; after a Day mode switch the rebuilt face's plate uses the
  new mode's values.
- [ ] AC6: `CardArt.motif_for(id)` returns one of the four motifs (sun on a horizon, rings, split disc, steps) and
  the same one for the same id every call and every run; across the real card ids all four occur. Every card id in
  `data/cards.json` has exactly one row in `docs/design/card-art.md` naming `<id>.png`, and the list names no id that
  isn't a card (a content test, like the flavor checks).

## Out of scope
- The pictures themselves (generated later from `card-art.md`); this item ships placeholders only.
- What happens when rules overflow the smaller rules area: 383. Until then a long card grows taller, as today.
- Tighter face text: 382.
- Art on tableau, Realm or supply-pile faces (decided against: at their size a picture costs a line of rules).
- The spike's screenshot hook in `main.gd` (spike-only).

## Design notes
- New `ui/card_art.gd` (`CardArt`, a `Control`): `setup(id, color)`, `static file_for(id) -> String`
  (`res://assets/cards/<id>.png`), `has_picture()`, `static motif_for(id) -> int`. It loads the texture through
  `ResourceLoader` when the file exists (so imported PNGs work in exports), draws it covering the rect from its
  centre, else the placeholder (the plane colour, a darker and a lighter tint of it from `Color.darkened` /
  `lightened`, no literals), then `Palette.ART_SHADE`, then a 1 px `Palette.EDGE` frame inset by half a pixel.
  The art directory is a static var so tests can point it at a fixture. Starting code: `spike/card-art`'s
  `ui/card_art.gd` (drop its file-name caption: the user chose a plain motif).
- `CardFace.build` adds the plate after the band when `in_hand` is true.
- `Palette`: new `ART_SHADE` in both sets (Night `Color(0, 0, 0, 0.25)`, Day transparent).
- `CardView.HAND_SIZE` 264 × 320 → 264 × 360. Every layout that reads the constant follows (the hand row, the Build
  modal's slot, `Modal.LEDGER_DETAIL_WIDTH` uses only x).
- Docs: tokens.md gains `ART_SHADE` and the plate; the specimen's card gains the plate (an item that changes how the
  game looks updates `mcm-specimen.html`).

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_card_art::test_a_hand_face_without_a_picture_has_a_placeholder_plate_after_its_band`, `test_the_placeholder_prints_no_text` |
| AC2 | `test_card_art::test_a_card_with_a_picture_shows_it_and_one_without_keeps_the_placeholder`, `test_the_picture_is_cropped_to_its_middle_band` |
| AC3 | `test_card_art::test_tableau_and_realm_row_faces_have_no_plate`, `test_the_hand_and_the_details_show_plates_and_the_realm_doesnt`; `test_build_modal::test_the_card_on_the_sheet_has_its_art_plate`; `test_event_modal::test_the_events_card_has_its_art_plate`; `test_raid_modal::test_the_raids_card_has_its_art_plate`; `test_renewal_modal::test_the_shown_card_has_its_art_plate`; `test_supply_screen::test_a_pile_card_has_no_art_plate` (passes already: a guard) |
| AC4 | `test_card_art::test_a_hand_card_is_264_by_360` (+ the existing `test_card_slots::test_hand_slots_keep_their_height`) |
| AC5 | `test_card_art::test_the_art_shade_dims_night_and_is_clear_in_day`, `test_a_rebuilt_face_shades_its_plate_in_the_new_mode` |
| AC6 | `test_card_art::test_a_cards_motif_is_one_of_four_and_always_the_same`; `test_content::test_every_art_motif_occurs_across_the_real_cards`, `test_the_card_art_list_has_one_row_per_card` (passes already: the list is complete) |

## Manual check
- [ ] `godot --path . -- --civ sumer --seed 5`: the hand's cards show plates in their type colours, each with its
  motif, in Night and in Day (Settings → Day mode); in Night the plate is shaded and doesn't outshine the rules.
- [ ] Open a card's details, the Build modal and an event: the card beside the text has its plate.
- [ ] Drop any 1536 × 1024 PNG at `assets/cards/farm.png`, let Godot import it, and open the Farm's details: the
  picture replaces the placeholder, cropped to its middle band. Remove it afterwards.
- [ ] The hand still fits at 1080p with the taller cards; the Realm keeps enough room above it.

## Log
<!-- Decisions and surprises during implementation, newest last. -->
- 2026-10-06: specced from `spike/card-art` (screenshots and findings in the spike's commits). The user chose a
  plain placeholder motif with no file name.
- 2026-10-07: red. Tests imply `CardArt.art_dir` (static var, default `ART_DIR`), `cover_region(tex_size, rect_size)`
  (static: the texture region drawn), `shade()` / `frame()` (the colours the plate draws, read at setup) and
  `enum Motif {SUN, RINGS, SPLIT_DISC, STEPS}`. Fixture picture `tests/fixtures/card_art/farm.png`. Shared test
  helpers `art_plate(view)` and `card_under(node)` in `test_case.gd`.
