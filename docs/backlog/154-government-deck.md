---
id: 154
title: Government deck: choose your next government instead of drawing it
type: feature
status: review
branch: feat/154-government-deck
---

## Goal
Governments stop being cards you draw. Every government you unlock goes into a separate government deck, and when
Anarchy ends you choose any of them. Changing government becomes a plan rather than luck of the draw, and government
cards no longer clog the hand or deck. First of the rework from `spike/revolution` (154–159).

## Acceptance criteria
- [x] AC1: Given Chiefs ruling, when a card `create`s Kings (into any zone), then Kings is in the new `governments`
  zone and not in that zone, and the play outcome's `created` lists it. When Kings is created again (already in
  `governments`), or Chiefs is created (ruling), then nothing is created and `created` doesn't list it.
- [x] AC2: Given Chiefs ruling, when Anarchy falls (unrest at the limit, 145), then Chiefs is in `governments`, not in
  the deck, and the deck's size is unchanged.
- [x] AC3: Given Anarchy ruling with Chiefs and Kings in `governments`, when Anarchy burns out (its last counter) or
  `restore_order()` succeeds, then no government rules, the Anarchy card is in `removed`, and `pending()` is
  `{kind: PENDING_GOVERNMENT, options: [the uids in governments, in zone order]}`. Every other action (play, grow,
  buy, research, renew, revolt, restore order, end turn) refuses with `"Choose a government first."`.
- [x] AC4: Given that choice owed and unrest 6, when `choose_government(kings_uid)` is called, then Kings rules, it
  has left `governments`, Chiefs stays there, the choice is no longer owed, unrest is 3 (at most half Kings' 7, the
  `unrest_limit` modifier added before halving), and Kings' `play` effects resolve (its `cost` isn't paid).
- [x] AC5: `choose_government_error(uid)` is `"No government to choose."` when no choice is owed and
  `"That government isn't in your government deck."` for any other uid; `choose_government` then returns false and
  changes nothing. Choosing uses no action.
- [x] AC6: A Government overlay opens while the choice is owed, showing the government deck's cards (heading from
  the engine: "Order returns: choose your government."); a click chooses. The top-bar civilization and government
  modal lists the government deck below the ruling government.
- [x] AC7 (bot): `ScriptedBot` chooses the government with the most `actions`, then the highest `unrest_limit`, then
  the first in zone order.

## Out of scope
- Revolting any time, counters by share of the limit, restore order priced by counters (155); the Anarchy drain (156).
- The bot's lookahead choice (159).

## Design notes
- New zone `governments` (GameEngine.ZONES); `EngineCore.create_card` redirects a government there, once per id
  (ruling or in the deck). The starting government rules and the deck starts empty.
- New pending kind `PENDING_GOVERNMENT`, first in `pending()` and `_blocked_error`; `GameState.choosing_government`.
  API `choose_government(uid)`, `choose_government_error(uid)`.
- Replaces: 145's burn-out to `unrest.fallback` and 146's `restore_order` installing the fallback (both now owe the
  choice); 146's half-limit acceptance gate and the government-first play under Anarchy (no government reaches a
  hand). `unrest.fallback` leaves the config (an unknown-field warning, as other unknown keys).
- Assumption (no question asked): a government's `cost` is never paid now; its `play` effects resolve when chosen.
  Real governments cost nothing.
- Tests: `TEST_GOVS`/`gov_engine` tests that play a government from hand need rewriting to choose from the deck;
  that changes approved tests on purpose (065, 145, 146, 148), as this item replaces those rules. List each in the Log.
- UI: the overlay fits beside the Explore and Renewal overlays in `ui/choice_overlays.gd`. `ui/main.gd` is at
  691 of 700 lines; if the wiring pushes it over, spec the split first.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_government_deck::test_a_created_government_goes_to_the_government_deck`, `test_a_known_government_isnt_created_again` |
| AC2 | `test_anarchy::test_a_turn_starting_at_the_limit_falls_into_anarchy` (changed), `test_revolution::test_revolting_starts_anarchy_with_renewal_owed_at_once` (changed) |
| AC3 | `test_government_deck::test_burning_out_owes_the_government_choice`, `test_while_the_choice_is_owed_everything_else_refuses`; `test_anarchy::test_anarchy_burns_out_at_max_counters_and_the_government_choice_is_owed` (changed), `test_leaving_anarchy::test_restore_order_pays_and_a_government_is_chosen` (changed) |
| AC4 | `test_government_deck::test_choosing_a_government_rules_it_and_calms_unrest`, `test_the_unrest_limit_modifier_counts_before_halving_a_chosen_government`, `test_a_chosen_government_resolves_its_play_effects_without_paying`; `test_anarchy::test_burning_out_keeps_unrest_below_half_the_limit` (changed) |
| AC5 | `test_government_deck::test_choose_government_error_names_each_reason_and_a_refusal_changes_nothing`, `test_choosing_uses_no_action` |
| AC6 | `test_government_deck::test_the_government_overlay_shows_the_deck_and_a_click_chooses`, `test_the_identity_modal_lists_the_government_deck` |
| AC7 | `test_government_deck::test_the_bot_chooses_the_government_with_most_actions_then_highest_limit`, `test_the_bot_breaks_government_ties_by_deck_order`; `test_leaving_anarchy::test_the_bot_restores_order_after_2_counters` (changed) |
| Design notes (`fallback` dropped) | `test_anarchy::test_unrest_fallback_is_no_longer_read`, `test_the_unrest_block_loads_with_its_defaults` (changed), `test_unrest_block_validation` (fallback case removed) |

## Manual check
- [ ] `godot --path . -- --civ egypt --seed 5`: open the top-bar civilization and government button; the modal ends
  with "Government deck: Kingship" (Egypt's start gives it), and Kingship is not in the discard or hand.
- [ ] Raise unrest to the limit (play Settlers) and end turns through the Anarchy (or pay Restore order on its
  button, whose tooltip now says "…then choose a government."): the Government overlay opens over the board with the
  heading "Order returns: choose your government.", showing Chiefdom and Kingship; clicking Kingship closes it and the
  top-bar button reads "Egypt · Kingship", unrest at most 3.
- [ ] Research Priesthood: Theocracy joins the government deck in the modal.

## Log
- 2026-10-01: Specced from `spike/revolution` (worktree `../4x-spike-revolution`, commits 0573e9c, 65fe287, d8b7a75).
- 2026-10-01: Red (approved): playing a government from hand stays for now (unreachable in real games; 155 retires it
  with the half-limit gate and the bot's government-first play). Changed approved tests on purpose (Test plan, "changed").
- Green: `put_in_hand` went through `create_card`, which now sends governments to the government deck; the helper
  gained `put_in(engine, id, zone)`, which places a government directly, so the kept hand-play tests and 147's
  governments-in-the-discard renewal tests keep their Givens (setup only, assertions unchanged). The Altar in
  `test_the_unrest_limit_modifier_counts_before_halving_a_chosen_government` is built on the home with `build_on` (a
  loose `create_card` Altar isn't working, so its modifier didn't count; setup only).
- `create_card` returns null for a government it doesn't create; nothing in the engine used the return for one.
  A fall no longer shuffles the deck, so seeded games after an Anarchy draw differently.
- `ui/main.gd` is at 694 of 700 lines: 155's Revolt button changes will likely need the split first.
- Follow-ups for 155: the bot's 148 revolt rule needs a government in hand, so it never revolts in real games now;
  Egypt's start Kingship now waits in the government deck until an Anarchy. Balance worry, not simmed (feature item).
