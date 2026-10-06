---
id: 358
title: Print the Build modal's flavor inside its card
type: feature
status: in-progress
branch: feat/358-flavor-on-build-card
---

## Goal
354 put the selected entry's flavor under its card on the Build modal's sheet, between the card and the preview. It
reads as a loose caption there, and it pushes the preview down. Print it inside the card instead, at the card's foot
in the Flavor look, as the identity modal's cards already do (231), so the card carries its own history and the sheet
under it is only the preview or the refusal.

Builds on 356 (its branch is cut from `feat/356-build-modal-polish`); merge after 356.

## Acceptance criteria
- [ ] AC1: Given the Build modal with the Kiln (`"flavor": "Mud brick, baked hard."`) selected, then its flavor shows
  once, inside the card on the sheet, in the `Flavor` look, wrapping inside the card, below its rules and at the
  card's foot (the label's bottom within `Tokens.SPACE_3`, the card's margin, of the card's bottom); and nothing in
  the `Flavor` look shows outside the card.
- [ ] AC2: Given the Lore Hall (147 characters of flavor and three upkeep lines) selected, then the card stays
  `CardView.HAND_SIZE` (264 × 320) and its flavor lies wholly inside it.
- [ ] AC3: Given the modal open, when another row is selected (by click or Up/Down), then the card shows the newly
  selected entry's flavor only (354's AC2 holds).
- [ ] AC4: Given a refused row with flavor, then its flavor shows inside its card and its reason under the card (354's
  AC3 holds); given a row with no flavor (a unit), then the card shows no flavor line and no empty one (354's AC5).
- [ ] AC5: Given the Kiln built and on the tableau, then its card there shows no flavor (only the Build modal's card
  prints it).

## Out of scope
- Flavor on hand, tableau or supply cards (they have no room); the details modal keeps its flavor as is.

## Design notes
- `CardView.show_flavor(text)` (a replayed `show_*`, like `show_settled`) → `CardFace.show_flavor(text)`: a `Flavor`
  label named `Flavor` at the face's foot, wrapping; "" removes it. `BuildModal._show_entry` calls it and stops adding
  the Flavor line under the card; `flavor_text()` stays.
- Guide §11.10's ledger sheet and the specimen's territory note say where the flavor goes.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_build_modal::test_the_selected_buildings_flavor_shows_inside_its_card` (was `…_shows_under_its_card`, 354) |
| AC2 | `test_build_modal::test_the_longest_flavor_fits_inside_the_hand_size_card` (also: below the card's other text) |
| AC3 | `test_build_modal::test_the_flavor_follows_the_selection` (354, unchanged) |
| AC4 | `test_build_modal::test_a_refused_rows_flavor_shows_above_its_reason`, `test_build_modal::test_a_card_without_flavor_shows_no_flavor_line` (354, unchanged) |
| AC5 | `test_build_modal::test_a_built_cards_flavor_stays_off_the_tableau` (passes today: a guard) |

## Manual check

## Log
