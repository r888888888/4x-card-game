---
id: 147
title: Renewal: Anarchy makes you trash cards from your discard
type: feature
status: review
branch: feat/147-renewal
---

## Goal
Anarchy has an upside: tearing down the old order lets the player thin the deck. Each turn of Anarchy the player
must trash cards from the discard pile, more the longer it lasts, and each trashed card calms 1 unrest, so renewal
is also the way back out (146). Techs can deepen it. Follows 145 and 146. From `spike/unrest`.

## Acceptance criteria
- [x] AC1: Given config `unrest.renewal` 1 (int >= 0, default 0), when a turn starts with Anarchy ruling (including
  the turn it falls), then after the draw `pending()` is `{kind: PENDING_RENEWAL, count, options}` with count = 1 +
  `anarchy_counters()` + the `renewal` modifier, capped at the number of options; options are the uids of the
  `discard` cards that aren't governments, in discard order. With count 0 nothing is pending.
- [x] AC2: Given renewal pending with count 2 and unrest 4, when `renew(uid)` is called on an option, then that card
  is in `trashed`, unrest is 3, and count is 1; after a second `renew` nothing is pending.
- [x] AC3: `renew_error(uid)` is `"Trash a card from your discard (not a government)."` for a government in the
  discard, a hand card or an unknown uid, and `"Nothing to renew."` when renewal isn't pending; `renew` then returns
  false and changes nothing.
- [x] AC4: While renewal is pending, playing, growing, buying, discarding and ending the turn are refused with
  `"Anarchy: trash 2 cards from your discard first."` (`"1 card"` for one). So the hand drawn that turn can't be
  discarded and then trashed.
- [x] AC5: `modifiers` accepts the key `renewal` (text `"Renewal trashes 1 more card"` / `"… 1 fewer card"`); a
  researched tech with `{"renewal": 1}` makes count 1 higher.
- [x] AC6 (bot): `ScriptedBot` renews the option worth least to keep, by cost + 2 × VP, +4 for a building, +3 for a
  card that loses unrest, +3 for a card that explores or settles while territories remain, +3 for a card that
  researches; ties go to the first in discard order. Given a discard of Farm, Storyteller and a government, it trashes
  the Storyteller.

## Out of scope
- Optional extra trashes (the spike's "techs add optional, not forced" idea); every renewal trash is forced here.
- Trashing anywhere but the discard.

## Design notes
- `GameState.renewal_left` (copied by `copy()`), set in `TurnLoop.start_turn` after the draw; a new
  `PENDING_RENEWAL` kind and one branch in `pending()` and `_blocked_error` (as 050 planned for new decisions).
- API: `renew(uid)`, `renew_error(uid)`; modifier key `Anarchy.RENEWAL` in `DataLoader.MODIFIER_KEYS`.
- UI: a Renewal overlay like Explore and Knowledge, showing the discard pile's cards in a wrapping row with the
  heading "Anarchy tears down the old ways: trash N card(s) from your discard pile. Each one calms 1 unrest." A click
  renews; a government refuses with the reason.
- Content: config `unrest.renewal` 1; Mysticism gets `"modifiers": {"renewal": 1}` (spike's pick; review).
- Spike: 4–10 cards trashed per game; wealth trashes the most (its deck fills with cheap cards). With the bot's
  crude choices renewal was a small net benefit; watch for players courting Anarchy to thin their deck.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_renewal::test_renewal_is_owed_the_turn_anarchy_falls`, `test_renewal_grows_with_the_counters`, `test_renewal_is_capped_at_the_options`, `test_nothing_is_owed_with_an_empty_discard_or_renewal_0`, `test_unrest_renewal_validation` |
| AC2 | `test_renewal::test_renewing_trashes_the_card_and_calms_1_unrest` |
| AC3 | `test_renewal::test_renew_error_names_each_reason_and_a_refusal_changes_nothing` |
| AC4 | `test_renewal::test_renewal_blocks_everything_else` |
| AC5 | `test_renewal::test_the_renewal_modifier_loads_with_its_text`, `test_a_researched_renewal_tech_raises_the_count` |
| AC6 | `test_renewal::test_the_bot_renews_the_card_worth_least_to_keep`, `test_the_bot_breaks_renewal_ties_by_discard_order` |
| UI (Design notes) | `test_renewal::test_the_renewal_overlay_shows_the_discard_and_a_click_trashes` |

## Manual check
- [ ] In Anarchy, the Renewal overlay shows the discard pile at the start of each turn; clicking a card trashes it
  and the unrest counter floats −1; a government refuses; the overlay closes when done.
- [ ] Shipped numbers: renewal 1 (+1 per counter), Mysticism +1.

## Log
- 2026-10-01: Built. Red checkpoint (agreed): `unrest.renewal` stays out of the normalized block when absent (like
  `relief`); "a card that researches" in AC6 reads as one that gains insight (no research op since 140); one UI test
  for the overlay (Design notes).
- Green: with no `unrest.renewal` key renewal is off altogether. Treating the absent key as 0 still asked for 1 card
  per counter, which blocked 145's own tests (a Feast in the discard). With `"renewal": 0` the counters still count.
- `ui/main.gd` is at 684 of 700 lines; 148 will likely need a split item first.
- Balance: not simmed. The spike's worry stands: players may court Anarchy to thin the deck.
