---
id: 254
title: The government choice defaults to the starting government
type: feature
status: red-review
branch: feat/254-default-government-choice
---

## Goal
When Anarchy ends the player must choose a government before anything else, and the choice should start on the
config's starting government (Chiefdom in the shipped data), so going back to it is one keypress and the other
governments read as deliberate alternatives.

## Acceptance criteria
- [ ] AC1: Given the government choice is owed and the government deck holds the config's `starting.government`, then
  `default_government()` is that card's uid, and `pending().options` lists it first (the rest keep deck order).
- [ ] AC2: Given the government choice is owed and the deck lacks the starting government (or the config sets none),
  then `default_government()` is the deck's first card's uid.
- [ ] AC3: Given no government choice is owed, then `default_government()` is -1.
- [ ] AC4: Given the government choice is owed, then every other action still refuses ("Choose a government first.")
  and ending the turn doesn't skip the choice: the choice stays owed until `choose_government` succeeds.

## Out of scope
- Anarchy becoming an event (253); this works with either.
- Bot choice: `ScriptedBot` keeps choosing by lookahead (159).

## Design notes
- New engine query `default_government() -> int` (in `engine_queries.gd`, logic in `Anarchy`). Reads
  `config.starting.government`, so no UI or engine code names Chiefdom.
- The overlay (`ChoiceOverlays`) shows the options in `pending().options` order and focuses the default with
  `FocusRing.focus`, so Enter (or the keyboard's choose key) picks it; it has no close, Esc or outside-click dismissal.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_default_government::test_the_default_government_is_the_starting_one_listed_first` |
| AC2 | `test_default_government::test_without_a_starting_government_the_default_is_the_decks_first` |
| AC3 | `test_default_government::test_with_no_choice_owed_there_is_no_default_government` |
| AC4 | `test_government_deck::test_while_the_choice_is_owed_everything_else_refuses` (existing, already green) |
| Design (overlay) | `test_default_government::test_the_government_overlay_lists_and_focuses_the_default_first` |

## Manual check
- [ ] Let Anarchy burn out after a revolt from Kingship (or any government that isn't the starting one): the overlay
  shows the starting government first and focused (ring after Tab); Enter chooses it.
- [ ] Esc and clicking outside the overlay don't dismiss it.

## Log
