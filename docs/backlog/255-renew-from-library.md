---
id: 255
title: Renewal trashes from your whole library
type: feature
status: red-review
branch: feat/255-renew-from-library
---

## Goal
Under Anarchy, renewal asks you to trash cards from your discard pile only, so it often asks for nothing (unplayed
cards stay in hand, and a reshuffle empties the pile) and never lets you thin the cards you care about most. Let the
player trash from their whole library (hand, draw pile and discard pile) so renewal is a real deck-thinning choice
every Anarchy turn.

## Acceptance criteria
- [ ] AC1: Given a turn starting under Anarchy (unrest.renewal 1, Anarchy's first turn) with 2 cards in the hand, 3 in
  the deck and 1 in the discard, then `pending()` is `{kind: PENDING_RENEWAL, count: 1, options}`, and options holds
  all 6 uids: hand, deck and discard together.
- [ ] AC2: options are sorted by card name, then by uid, whatever zone each card is in; a government in any of those
  zones is never an option.
- [ ] AC3: Given renewal is owed, when `renew(uid)` names a card in the hand, the deck, or the discard, then that card
  moves to `trashed`, unrest drops by 1 and count drops by 1; the deck's other cards keep their order (no reshuffle).
- [ ] AC4: Given renewal is owed, then `renew_error(uid)` refuses a tableau card, a government, and an unknown uid with
  "Trash a card from your hand, deck or discard (not a government)."; a refusal changes nothing.
- [ ] AC5: The count is unchanged (unrest.renewal + Anarchy's turn − 1 + the renewal modifier) and is capped at the
  number of options now: with 0 cards in hand, deck and discard nothing is owed; with 2 options and a count of 3, 2 are
  owed.
- [ ] AC6: `revolt_summary()`'s renewal line says the cards come "from your hand, deck or discard".

## Out of scope
- Keyboard play on the Renewal screen (the government choice has it since 254; renewal is still click only).
- Changing how many cards renewal asks for: balance.
- Tableau cards (buildings, cities, units, territories) and governments: never trashed by renewal.

## Design notes
- `Anarchy.renewal_options` gathers hand + deck + discard (governments aside), sorted by `def.name` then uid;
  `Anarchy.renew` takes the card from whichever of those zones holds it. `RENEW_ERROR` becomes "Trash a card from
  your hand, deck or discard (not a government)."
- Bot (`ScriptedBot._renewal_pick`): unchanged rule, worth least to keep over all options; a tie goes to the first in
  options order (now name order, was discard order).
- UI: the Renewal screen shows the options as one row in `pending().options` order (sorted by name, so the draw order
  stays hidden). Hand cards appear there instead of in the hand while renewal is owed, and go back after. Today
  `BoardViews.sync` fills the row from the discard zone; it fills it from `pending().options` instead. The heading
  stops saying "from your discard pile".
- Text: the Anarchy card's `text` in `data/cards.json` and the heading say "from your hand, deck or discard".

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1, AC2 | `test_renewal::test_renewal_offers_the_hand_deck_and_discard_in_name_order` |
| AC3 | `test_renewal::test_renewing_trashes_a_hand_or_deck_card_and_keeps_the_deck_order` |
| AC4 | `test_renewal::test_renew_error_names_each_reason_and_a_refusal_changes_nothing` (changed), `::test_renewal_blocks_everything_else` (message changed) |
| AC5 | `test_renewal::test_renewal_is_capped_at_the_options` (changed), `::test_nothing_is_owed_with_an_empty_library_or_renewal_0` (changed, already green) |
| AC6 | `test_revolution::test_revolt_summary_describes_the_coming_anarchy_with_this_games_numbers` (SUMMARY line changed) |
| Bot | `test_renewal::test_the_bot_breaks_renewal_ties_by_name_order` (was by discard order) |
| UI | `test_renewal::test_the_renewal_overlay_shows_the_options_in_order_with_the_hand_in_it`, `::test_the_renewal_overlay_shows_the_discard_and_a_click_trashes` (changed) |

## Manual check
- [ ] `godot --path . -- --civ egypt --seed 5`, play nothing on turn 1, revolt from the civilization modal, end the turn:
  the Renewal screen opens with your 11 cards (hand and deck) in name order, the hand empty behind it; a click trashes
  one and the hand comes back with the rest.
- [ ] The heading and the Anarchy card's text say "from your hand, deck or discard".

## Log
