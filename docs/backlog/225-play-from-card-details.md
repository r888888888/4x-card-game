---
id: 225
title: Play a hand card from its details modal
type: feature
status: red-review
branch: feat/225-play-from-card-details
---

## Goal
When the player opens a hand card's details (I on the focused hand card, or a click), they can play it from there
with a Play button instead of closing the modal and dragging or double-clicking the card.

## Acceptance criteria
- [ ] AC1: Given a hand card whose `playable_error` is "" and that needs no target, when its details are opened from
  its hand view, then the modal's footer shows an enabled Play button next to Close; pressing it closes the modal and
  plays the card (it leaves the hand and the action count drops by 1).
- [ ] AC2: Given the details of a board card, a supply pile, or a tech (`open_def`), when the modal opens, then it shows
  no Play button.
- [ ] AC3: Given a hand card that can't be played (for example, its cost is more than the player has), when its
  details are opened, then the Play button is shown but disabled, and its tooltip is the engine's `playable_error`
  for that card.
- [ ] AC4: Given a hand card with more than one valid target (`needs_target_choice` is true), when Play is pressed,
  then the modal closes and targeting begins for that card, as a double-click would start it; nothing is played yet.
- [ ] AC5: Given the details of a hand card with Play shown, when the same modal is then opened for a board card,
  then the Play button is gone (the button follows the card it is opened for).
- [ ] AC6: Given a hand card's details open, when a pending decision blocks hand input (`hand_input_error` non-empty,
  for example an explore choice), then Play is disabled with that reason as its tooltip.

## Out of scope
- A keyboard shortcut for Play inside the modal (Enter/P).
- Playing cards from the supply screen or the tech tree.
- Discarding from the modal.

## Design notes
- UI-only: the engine already answers with `playable_error(uid)`, `hand_input_error()` and
  `needs_target_choice(uid)`. No new engine API, no data change.
- Play reuses `main.on_double_clicked(view)` after closing the modal, so targeting, the territory view and the pending
  discard behave exactly as they do for a double-click. The modal gets a callback (or a signal) for it rather than
  reaching into `main`.
- "From my hand" means `CardDetailsModal.open(view)` with `view.in_hand`; `open_def` never shows Play.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_details_modal::test_play_button_plays_a_playable_hand_card_and_closes_the_details` |
| AC2 | `test_details_modal::test_play_button_is_hidden_for_board_supply_and_tech_details` |
| AC3 | `test_details_modal::test_play_button_is_disabled_with_the_reason_for_an_unplayable_hand_card` |
| AC4 | `test_details_modal::test_play_button_begins_targeting_for_a_card_with_several_targets` |
| AC5 | `test_details_modal::test_play_button_goes_when_the_details_reopen_for_a_board_card` |
| AC6 | `test_details_modal::test_play_button_is_disabled_while_a_decision_blocks_the_hand` |

## Manual check
- [ ] Focus a playable hand card, press I: Play sits in the footer beside Close, sized to its text; press it and the
  card plays with its usual motion.
- [ ] Open the details of an unaffordable hand card: Play is dimmed and hovering it says why.
- [ ] Open the details of a building with two settled territories: Play closes the modal and lights the targets.

## Log
- Red: AC6's example was a forced discard, but discarding is itself hand input, so `hand_input_error` is "" then;
  the test uses an explore choice instead.
