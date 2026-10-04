---
id: 255
title: Renewal trashes from your whole library, chosen in a ledger and confirmed
type: feature
status: review
branch: feat/255-renew-from-library
---

## Goal
Under Anarchy, renewal asks you to trash cards from your discard pile only, so it often asks for nothing (unplayed
cards stay in hand, and a reshuffle empties the pile) and never lets you thin the cards you care about most. Let the
player trash from their whole library (hand, draw pile and discard pile), choosing the cards in a ledger on a modal
sheet and confirming them together, so renewal is a deliberate deck-thinning choice every Anarchy turn.

## Acceptance criteria
Engine
- [x] AC1: Given a turn starting under Anarchy (unrest.renewal 1, Anarchy's first turn) with 2 cards in the hand, 3 in
  the deck and 1 in the discard, then `pending()` is `{kind: PENDING_RENEWAL, count: 1, options}`, options holding all
  6 uids, sorted by card name then uid, whatever zone each is in; a government in any of those zones is never an option.
- [x] AC2: Given renewal is owed with count 2, when `renew([a, b])` names 2 distinct options (from any of hand, deck
  and discard), then both move to `trashed`, unrest drops by 2, nothing is pending, and the deck's other cards keep
  their order (no reshuffle). One call pays the whole count.
- [x] AC3: `renew_error(uids)` refuses, and `renew(uids)` then changes nothing: not exactly count uids ("Choose 2 cards
  to trash." / "Choose 1 card to trash."), a uid that isn't an option (a tableau card, a government, an unknown uid:
  "Trash a card from your hand, deck or discard (not a government)."), the same uid twice ("Each card can be trashed
  once."), and no renewal owed ("Nothing to renew.").
- [x] AC4: The count is unchanged (unrest.renewal + Anarchy's turn − 1 + the renewal modifier) and capped at the number
  of options: with no cards in hand, deck and discard nothing is owed; with 2 options and a count of 3, 2 are owed.
- [x] AC5: The texts follow: `revolt_summary()`'s renewal line and the blocking message say "from your hand, deck or
  discard" ("Anarchy: trash 2 cards from your hand, deck or discard first.").
- [x] AC6: The bot pays renewal in one `renew` call with the count's worth-least-to-keep options (`_keep_value`), ties
  going to the earlier option (name order).

UI
- [x] AC7: While renewal is owed, the Renewal modal (a `Modal` on `main.modals`, titled "Renewal") is open with a row
  per option in options order, each reading its card's name; Esc and a click outside leave it open. A click (or Enter)
  on a row chooses it, again puts it back; a choice past the count is refused. The modal's "Trash N cards" key is
  refused until exactly the count is chosen; pressing it then calls `renew` with the chosen uids and the modal closes.
  The hand stays in place behind it. The old Renewal overlay is gone.
- [x] AC8: Sounds (§14.1 tokens): choosing a row plays `ui.toggle.on`, putting it back `ui.toggle.off`, a choice past
  the count `ui.reject.locked`; the modal opens with `ui.sheet.open` and closes with `ui.sheet.close` (as every Modal).

## Out of scope
- The card face beside the ledger shows the row's card plainly, never a chosen state (Manual check).
- Changing how many cards renewal asks for: balance.
- Tableau cards and governments: never trashed by renewal.

## Design notes
- Design: [docs/design/renewal-options.html](../design/renewal-options.html), option B (the ledger) with its sound
  table.
- Engine: `renew(uids: Array) -> bool` and `renew_error(uids: Array) -> String` replace the one-card versions (select,
  then confirm). `Anarchy.renewal_options` gathers hand + deck + discard (governments aside), sorted by `def.name` then
  uid. `RENEW_ERROR` becomes "Trash a card from your hand, deck or discard (not a government)."
- Bot (`ScriptedBot`): one `renew` call with the count's lowest `_keep_value` options.
- UI: `RenewalModal extends Modal`, not dismissable, opened by main when `pending()` is a renewal and closed when it
  isn't. A ledger like `SelectList`: each row a toggle Button with a lamp (lit when chosen) and the card's name; the
  pulled-out row (hover or Up/Down) shows its card face beside the list. Footer: "Chosen n / N" and the primary
  "Trash N cards", which asks `renew_error` and refuses (reject.locked) until it's "". The old overlay
  (`ChoiceOverlays`' renewal parts, `BoardViews`' renewal row, the renewal paths in `CardFocus` and `main.on_picked`)
  goes.
- Sounds: hover ticks already come from `Sfx` for any enabled button (245). Choosing rows plays toggle on/off;
  `ui.selection` isn't used (see the design page's table).

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_renewal::test_renewal_offers_the_hand_deck_and_discard_in_name_order` |
| AC2 | `test_renewal::test_renewing_trashes_the_chosen_cards_at_once_and_keeps_the_deck_order`, `::test_renewing_one_card_calms_1_unrest` |
| AC3 | `test_renewal::test_renew_error_names_each_reason_and_a_refusal_changes_nothing`, `::test_renew_error_says_1_card_when_1_is_owed`; `test_blocking` (renew takes an array) |
| AC4 | `test_renewal::test_renewal_is_capped_at_the_options`, `::test_nothing_is_owed_with_an_empty_library_or_renewal_0` |
| AC5 | `test_renewal::test_renewal_blocks_everything_else`, `test_revolution::test_revolt_summary_describes_the_coming_anarchy_with_this_games_numbers` |
| AC6 | `test_renewal::test_the_bot_pays_a_count_of_2_in_one_go_with_the_least_worth_keeping`, `::test_the_bot_breaks_renewal_ties_by_name_order` |
| AC7 | `test_renewal_modal::test_the_renewal_modal_lists_every_option_in_order`, `::test_the_renewal_modal_cant_be_dismissed`, `::test_rows_are_chosen_and_put_back_up_to_the_count`, `::test_trash_is_refused_until_the_count_then_pays_and_closes` |
| AC8 | `test_renewal_modal::test_choosing_sounds_like_a_lamp_key_and_past_the_count_is_locked`, `::test_the_renewal_sheet_opens_and_closes_with_the_sheet_sounds` |

## Manual check
- [ ] `godot --path . -- --civ egypt --seed 5`, play nothing on turn 1, revolt from the civilization modal, end the turn:
  the Renewal sheet opens over the board with your 11 cards in name order; hovering a row ticks and shows its card,
  plainly; a click lights the row's lamp (toggle sound); "Trash 1 card" unlocks at 1 of 1 and trashes it, the sheet
  lifting; before that, pressing it gives a dead tap and its reason.
- [ ] Esc and a click outside don't close it; the Anarchy card's text says "from your hand, deck or discard".

## Log
- Spec changed after design review: every card listed individually (no stacks), select then confirm, the ledger
  layout (B), sounds from existing tokens; `renew` takes all the chosen uids at once; the overlay becomes a Modal.
- Red checkpoint missed `test_blocking`'s two RENEWAL message constants; AC5 changes that message, so they now read
  "from your hand, deck or discard" (changed in green, the only approved-test edit).
- The ledger rows show the chosen state with their lamp only: no strikethrough (Godot labels have none); the pulled-out
  row is the shown one (hover, focus), drawn with the list's pressed look.
- The rows are in KeySounds' OWN_SOUNDS group (their lamp latch replaces the key click); hover still ticks.
- The bot's lookup of an option's card (`zone(zone_of(uid)).find(uid)`) repeats in RenewalModal and Anarchy.renew; an
  engine `card(uid)` query could serve all three (follow-up, not needed for this item).
