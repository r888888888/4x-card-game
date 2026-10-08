---
id: 402
title: A larger art plate that keeps most of the picture
type: feature
status: review
branch: feat/402-larger-art-plate
---

## Goal
The art plate on a hand-size face (381) is a 5:2 strip, 240 × 96 px, showing only the middle 60 % of each 3:2
picture's height. Make it 16:9, 240 × 135 px, so it shows 84 % of the height and mostly keeps the picture's framing.
The card stays 264 × 360: the extra 39 px come from the room for rules, and 383's cut and hover rise show what no longer
fits. (The user's choices, 2026-10-08: 16:9 over 2:1 and the full 3:2; the text gives the room, the card doesn't grow.)

## Acceptance criteria
- [x] AC1: Given a hand-size face of any card, when it is laid out, then its art plate (`Art`, right after the band) is
  135 px tall and fills the face's width (240 px on a 264 px card); `CardArt.HAND_HEIGHT` is 135. The card is still
  264 × 360.
- [x] AC2: Given a 1536 × 1024 picture in a 240 × 135 plate, `CardArt.cover_region` is the picture's full width and its
  middle 864 rows (rows 80 to 944): 84.4 % of its height, centred.
- [x] AC3: Given a hand-row card whose rules don't all fit (383's Long), when its sheet rises, then it rises at most the
  plate and its gap, 143 px (135 + 8), and the rules still shown are whole (383's AC1 and AC3 hold at the new size).
- [x] AC4: Smaller faces (tableau, board) still have no plate, and the details, Build, event, raid and Renewal modals
  show the hand-size face with the 135 px plate.

## Out of scope
- New or redrawn pictures: the 189 pictures are already 3:2 with the subject inside the middle 60 %, so they all still
  fit; recomposing briefs for the wider view is a card-art run, not this item.
- The card's size and the hand row's height (unchanged by the user's choice).
- Tableau-size faces.

## Design notes
- `CardArt.HAND_HEIGHT` 96 → 135 (16:9 at 240 wide). `CardSheet.cap()` reads the plate's height, so 383's rise cap
  follows (104 → 143) with no code change.
- Approved tests whose numbers change on purpose (flag at the red checkpoint): `test_card_art`'s "96 px tall" and
  `CardArt.HAND_HEIGHT` 96.0; `test_card_overflow`'s `CAP` 104.0. `test_card_art`'s `cover_region` cases for a
  240 × 96 rect test the function, not the plate, and can stay.
- At rest about two lines fewer rules fit on a hand card (39 px at the 20 px body size), so more cards show "+N more"
  and reach the hover rise; Medium-length cards (383's fixture) may now need the meter. 383's tests use fixtures
  whose outcome doesn't depend on the exact room except Medium: check it is still cut at rest and whole once risen.
- Docs: `docs/design/card-art.md` (the band the game shows: 16:9, rows 80–944), the guide's §6.7 ("5:2") and §19
  (the crop, the thumbnail test at 240 × 135, the hand card's anatomy), and the card-art skill's composition rule (the
  subject inside the middle 60 % stays safe; the view is now 84 %).
- Depends on 383 (merged first): its sheet and cut are what make a taller plate workable.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_card_art::test_a_hand_face_without_a_picture_has_a_placeholder_plate_after_its_band`, `test_card_art::test_a_hand_card_is_264_by_360` (unchanged) |
| AC2 | `test_card_art::test_the_hand_plate_shows_the_pictures_middle_864_rows` |
| AC3 | `test_card_overflow` (`CAP` 104 → 143): `test_resting_on_a_long_card_raises_its_sheet_to_the_cap`, `test_keyboard_focus_raises_the_sheet_at_once_with_no_meter`, `test_reduce_motion_jumps_the_sheet_steps_the_meter_and_places_the_popover`, `test_a_medium_card_rises_only_as_far_as_its_hidden_rules_need` |
| AC4 | `test_card_art::test_tableau_and_realm_row_faces_have_no_plate` (unchanged), `test_card_art::test_the_hand_and_the_details_show_plates_and_the_realm_doesnt`, `test_build_modal::test_the_card_on_the_sheet_has_its_art_plate`, `test_event_modal::test_the_events_card_has_its_art_plate`, `test_raid_modal::test_the_raids_card_has_its_art_plate`, `test_renewal_modal::test_the_shown_card_has_its_art_plate` |

## Manual check
- [ ] `godot --path . -- --civ sumer --seed 5`: hand cards show most of each picture (no subject cut at the head or
  feet), the plate's 1 px frame is intact, and the text below reads with no rule cut through.
- [ ] Long cards (Sailing, Code of Laws, Theocracy): "+N more" shows, the sheet rises over the larger plate on hover,
  covering it cleanly in Night and Day.
- [ ] The details, Build and Renewal modals: the face fits its column with the larger plate.

## Log
- 2026-10-08: specced after 383. The user chose 16:9 (240 × 135) and keeping the card at 264 × 360.
- 2026-10-08: built. `CardArt.HAND_HEIGHT` 96 → 135; the sheet's rise cap follows (143) with no code change. Medium
  is still cut at rest and whole once risen. 383's `Tail` fixture no longer fit 4 short rules at rest (3 now), so it
  was trimmed to 3 rules with the user's approval; the test still shows a paragraph that doesn't fit hidden whole.
  Docs: card-art.md, the guide's §6 card anatomy, §19.5 and §19.7, the card-art skill's composition rule. The id
  clash with the court rank item was resolved by renumbering that one to 413.
