---
id: 205
title: Revolt from the civilization modal, after a confirmation that says what follows
type: feature
status: done
branch: feat/205-revolt-in-civilization-modal
---

## Goal
Revolution is a big, rare decision, so it moves off the board into the civilization modal, beside the government it
overthrows, and asks first: a confirmation sheet explains what Anarchy will do to this realm (with this game's
numbers) under a line of flavor, so nobody revolts by a stray click.

## Acceptance criteria
- [x] AC1 (engine): Given a game where revolt is legal (Chiefdom, unrest 3 of limit 5, food 6, wealth 3), when
  `revolt_summary()` is called, then it returns the lines that describe the coming Anarchy with live numbers, in order:
  when it falls ("Anarchy falls at the start of next turn."), how long (`revolt_forecast()` turns: "It lasts up to N
  turns; calming shortens it."), the actions it allows ("1 action each turn; only order cards can be played."), what
  stops ("Nothing can be grown, bought or researched."), the drain ("Each turn it eats 20% of stored food and wealth."
  from `unrest.drain_pct`), renewal (from `unrest.renewal`) and the end ("When it ends, choose a government from your
  government deck."). With a config block missing (no drain, no renewal), its line is left out.
- [x] AC2 (engine): Given revolt is not legal (`revolt_error()` non-empty), `revolt_summary()` returns [].
- [x] AC3 (loader): A government card may have `flavor` (paragraph and quote, as civilizations, 107); the shipped
  Anarchy card has one. Flavor on any other non-civilization type is still a load error naming file, card and field.
- [x] AC4: Given the civilization modal is open and revolt is legal, then the government section ends with a "Revolt…"
  button; given `revolt_error()` is non-empty, the button is disabled with the error as its tooltip. The board no
  longer has a Revolt button (`BoardLayout.revolt` goes; Relieve famine and Restore order stay).
- [x] AC5: When "Revolt…" is pressed, then a confirmation modal opens stacked on the civilization modal: title
  "Revolution", context caps "Turn N · <government>", the Anarchy card's flavor (italic, quote attributed), then
  `revolt_summary()`'s lines as a list, and a footer with "Keep <government>" (closes it, nothing changes) and
  "Revolt" (primary, rightmost).
- [x] AC6: When "Revolt" is pressed, then `revolt()` runs once (state `revolt_pending` true), the confirmation closes,
  and the civilization modal stays open showing the revolution under way (its Revolt… button disabled with "A
  revolution is already under way."). Esc or a click outside the confirmation closes it without revolting.

## Out of scope
- The bot (it calls `revolt()` directly; no change). Balance of Anarchy.

## Design notes
- New engine API `revolt_summary() -> Array[String]` (in `anarchy.gd`, exposed on `GameEngine`), generated from the
  config like the Anarchy card's text; the UI never writes the numbers.
- Data: `flavor` joins `TYPE_FIELDS` for `CardDef.GOVERNMENT`; add a flavor paragraph and quote to `anarchy` in
  `data/cards.json` (content: reviewed at the manual check).
- New `RevoltModal` (extends `Modal`); its look follows 207's sheet (title block, footer rule). Build after 207, or
  restyle it in 207.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_revolution::test_revolt_summary_describes_the_coming_anarchy_with_this_games_numbers`, `test_a_summary_leaves_out_what_the_config_lacks` |
| AC2 | `test_revolution::test_no_summary_while_revolt_is_refused` |
| AC3 | `test_civ_flavor::test_a_government_may_have_flavor_and_a_quote`; `test_content::test_the_anarchy_government_has_flavor_and_a_quote` (the config's Anarchy, by the config, not by id); existing `test_flavor_and_quote_validation` keeps flavor on a building or an action a warning |
| AC4 | `test_revolt_modal::test_the_civilization_modal_ends_its_government_section_with_revolt`, `test_with_revolt_refused_the_button_is_disabled_with_the_reason`, `test_the_board_has_no_revolt_button`; removed: `test_revolution::test_the_revolt_button_shows_while_you_may_revolt_and_forecasts_the_anarchy` (the board's button goes) |
| AC5 | `test_revolt_opens_a_confirmation_with_the_flavor_and_the_summary` |
| AC6 | `test_revolt_in_the_confirmation_revolts_once_and_leaves_the_civilization_modal_open`, `test_keep_esc_or_a_click_outside_close_the_confirmation_without_revolting` |

Decisions made writing the tests:
- The renewal line reads "Each turn: trash N card(s), +1 per turn so far, from your discard (−1 unrest each)." (the
  Anarchy card's own wording); the actions line names the config's `allowed_tag` ("order").
- AC3 says flavor elsewhere is "still a load error", but today it is a warning ("only applies to civilizations",
  ignored); "still" reads as "as today", so it stays a warning and the existing validation test is unchanged.
- Hooks: `IdentityModal.revolt_button`; `main.revolt_modal` (`keep_button`, `confirm_button`, `body_text()`);
  `main.revolt_button()` goes with the board's button.

## Manual check
- [ ] Seed 5: open Sumer · Chiefdom, press Revolt…: the sheet reads well (flavor, list, two buttons), in both palettes.
- [ ] Review the Anarchy flavor text and quote.

## Log
- Specced 2026-10-02 from the notes list. Decided 2026-10-02: the engine writes the summary; the flavor is the Anarchy
  card's (it has none yet, so this item adds it).
- 2026-10-02: Built. Engine: `revolt_summary()` (`Anarchy.revolt_summary`) and `anarchy_id()` (added test-first in
  the green phase, so the confirmation needn't read the config: `test_revolution::test_anarchy_id_names_the_configs_anarchy_government`).
  Loader: `flavor` and `quote` apply to governments too. Data: Anarchy's flavor and a Yeats quote (review them). UI:
  `IdentityModal.revolt_button` ends the government section; `ui/revolt_modal.gd` (`RevoltModal`, `main.revolt_modal`);
  the board's Revolt button, `ActionButton.revolt` and `main.revolt_button()` are gone.
- Manual-check notes: the flavor's `[i]` shows upright (RichBody has no italic face); at 1280×720 the civilization
  modal under the confirmation is taller than the window (as before this item).
