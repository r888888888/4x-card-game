---
id: 107
title: Replace the starting civilizations with ancient historical ones
type: feature
status: done
branch: feat/107-ancient-civilizations
---

## Goal
You play as a real civilization of antiquity instead of an invented one (Children of the River, Salt Road Traders,
Hearth Clans, Star Watchers). Six civilizations, each with a bonus that fits its history, built from effect ops the
engine already has. Items 108–111 add new mechanics and give some civilizations a second, signature bonus.

## Acceptance criteria
Content item: the tests assert invariants of the real data; the roster and its numbers are under Manual check.

- [x] AC1 (no orphans): every card of type `civilization` in the real `data/cards.json` is listed in config
  `civilizations`. (The four old civilizations are removed from the data, not left unlisted.)
- [x] AC2 (roster): the real config lists at least 6 civilizations, each with at least one effect, no two with the
  same card text, and `starting.civilization` is one of them. (Extends
  `test_real_config_lists_at_least_3_different_civilizations`.)
- [x] AC3 (start gifts): every `create` with trigger `start` on a real civilization puts a card into `discard`, and
  that card is one the player can get in the game otherwise (in `deck`, `supply`, or created by a tech in
  `research_deck`).
- [x] AC4: the real data loads with no warnings or errors (existing test), and a `new_game` with each listed
  civilization succeeds and leaves that civilization in the `civilization` zone.
- [x] AC5 (loader): a civilization may have `flavor` (a non-empty string) and `quote` ({"text", "by"}, both
  non-empty strings), each optional. A wrong type, an empty string or a missing `text`/`by` is one load error naming
  the card and the field. On any other card type they're ignored with "'flavor' only applies to civilizations".
- [x] AC6 (details): `def_details` and `card_details` return `flavor` (a string, "" when none) and `quote`
  ({text, by}, or {} when none) for every card.
- [x] AC7 (UI): the details modal of the civilization shows its flavor paragraph and its quote with who said it.
- [x] AC8 (content): every listed real civilization has a flavor and a quote.
- [x] AC9 (new game screen): clicking a civilization card selects it (and saves the choice, as before) and opens its
  details modal, which starts with the flavor and shows every line of its rules (all its bonuses).
- [x] AC10 (details order): in the details modal, the flavor comes first, then the quote, then Rules, Now and How it
  works; the same modal opens from the civilization line in play.
- [x] AC11 (bug, found in review): with the details open over the new game screen, a real mouse click on Close
  closes them. (The new game screen, later in the scene tree, took the click: Godot picks by tree order, not z_index.)
- [x] AC12 (new game screen): the details of a civilization opened there have a "Play as <name>" button that selects
  it (and saves the choice), closes the details and starts a game as it with the seed field's seed. Details opened
  anywhere else have no such button.
- [x] AC13 (bug, found in review): before any game has started, `card_details(uid)` returns {} without a script
  error, so clicking a civilization on the new game screen (a card with no live copy) shows its definition's details.

## Out of scope
- New mechanics: cost discounts (108), hand size (109), housing (110), home territory (111).
- Leaders, unique units or unique buildings per civilization.
- Balance: numbers are tuned in a later balance item.

## Design notes
- No engine or format change. Uses `gain`, `gain_per_keyword`, `gain_per_tag`, `score` (upkeep) and `gain`, `create`
  (start).
- Proposed roster (ids are the lowercase names):
  - **Egypt** (default, "Gift of the Nile"): ⟳ +1 food per settled territory with fresh water or flood plain.
  - **Sumer** ("the first farmers and scribes"): Start: add an Insight to your discard; ⟳ +1 food per farm.
  - **Phoenicia** ("sea traders"): Start: +3 wealth; ⟳ +1 wealth per coastal territory.
  - **Babylon** ("Code of Hammurabi"): Start: add Kingship to your discard.
  - **Greece** ("philosophy and drama"): Start: add a Storyteller to your discard; ⟳ +1 VP.
  - **Persia** ("the Royal Road"): Start: add a Caravan to your discard; ⟳ +1 wealth.
- Flavor and quotes (quotes are in translation; wording to check under Manual check):
  - **Egypt**: "Along a thin green ribbon of the Nile, the yearly flood laid down black silt, and pharaohs raised
    monuments meant to outlast time." — "Egypt is the gift of the river." (Herodotus, *Histories*)
  - **Sumer**: "Between the Tigris and the Euphrates, the Sumerians dug canals, built the first cities, and pressed
    wedges into clay to keep their accounts: the first writing." — "Go up on the wall of Uruk and walk around."
    (*Epic of Gilgamesh*)
  - **Phoenicia**: "From Tyre and Sidon, Phoenician ships carried cedar, glass and purple dye across the
    Mediterranean, and their alphabet travelled with them." — "A merchant of the people for many isles."
    (Ezekiel 27:3, of Tyre)
  - **Babylon**: "Hammurabi carved his laws in stone for all to see, and Babylon's astronomers kept the most careful
    records of the heavens in the ancient world." — "That the strong should not harm the weak." (Code of Hammurabi)
  - **Greece**: "Rival city-states argued in the agora, staged tragedies in open theatres, and asked questions
    philosophers still ask." — "The unexamined life is not worth living." (Socrates, in Plato's *Apology*)
  - **Persia**: "Cyrus and Darius ruled the largest empire yet seen, held together by satraps, respect for local
    customs, and a road of relay stations from Sardis to Susa." — "Neither snow nor rain nor heat nor gloom of night
    stays these couriers from the swift completion of their appointed rounds." (Herodotus, *Histories*)
- New `CardDef` fields `flavor`, `quote_text`, `quote_by` (civilization only, in `TYPE_FIELDS`). Card text (the
  generated rules) doesn't include them. The modal gets a test hook `body_text()`; flavor in italics, then the quote,
  before the rules (AC10).
- Egypt on the starting River Meadow (fresh water) gives ⟳ +1 food, the same as today's default.
- A saved civilization id that no longer exists (e.g. `river_children`) already falls back to the first listed one
  with a warning (064 AC5).
- Update PLAN.md's "Real data (064)" line.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_content::test_every_civilization_card_is_listed` |
| AC2 | `test_content::test_real_config_lists_at_least_6_different_civilizations` (replaces `…_at_least_3_…`) |
| AC3 | `test_content::test_civilization_start_gifts_are_obtainable_cards_in_the_discard` |
| AC4 | `test_content::test_a_new_game_starts_as_each_listed_civilization`, `::test_real_data_loads_without_warnings` |
| AC5 | `test_civ_flavor::test_civilization_flavor_and_quote_load_without_warnings`, `::test_flavor_and_quote_validation`, `::test_flavor_and_quote_are_optional` |
| AC6 | `test_civ_flavor::test_civilization_details_carry_flavor_and_quote`, `::test_cards_without_flavor_have_empty_flavor_and_quote` |
| AC7 | `test_identity_lines::test_civilization_details_show_its_flavor_and_quote` |
| AC8 | `test_content::test_every_listed_civilization_has_flavor_and_a_quote` |
| AC9 | `test_start_screen::test_clicking_a_civilization_selects_it_and_shows_its_flavor_and_bonuses` |
| AC10 | `test_identity_lines::test_civilization_details_start_with_flavor_then_quote_then_rules` |
| AC11 | `test_start_screen::test_a_click_on_close_closes_the_details_over_the_new_game_screen` |
| AC12 | `test_start_screen::test_play_as_in_the_details_starts_a_game_as_that_civilization`, `::test_details_in_play_have_no_play_as_button` |
| AC13 | `test_card_details::test_bug_107_card_details_before_a_game_starts` |
| (content coupling) | `test_identity_lines::test_side_panel_shows_civilization_then_government`, `::test_pressing_a_line_opens_its_details` now read the civilization's name from the engine |

## Manual check
- [ ] The roster in data matches the design notes: six civilizations, Egypt the default, and each bonus reads right on
  its card and in its details.
- [ ] On the new game screen, click each civilization: it highlights and its details open with the flavor and quote
  on top and every bonus under Rules. Close; Start plays the last one clicked.
- [ ] In the details on the new game screen, click Close: they close. Click a civilization again and press
  "Play as …": a game starts as it (with the seed field's seed, if any), and the choice is remembered.
- [ ] In a game, click the Civilization line in the side panel: the same details, flavor first.
- [ ] Flavor reads well in the details modal; quotes are accurate to a published translation.
- [ ] The new game screen fits six civilization cards without clipping, at the default and a narrow window size.
- [ ] Start a game as each civilization: its start gift appears (resources or a card in the discard) and its upkeep
  bonus shows in the forecast.

## Log
- Balance worries: Babylon's Kingship on turn 1 skips the Code of Laws tech; Sumer's per-farm food may snowball.
  Leave to the balance item.
- Built: `CardDef.flavor` / `quote_text` / `quote_by`, `DataLoader._parse_flavor`, `flavor` and `quote` keys in the
  card details, and the modal's `body_text()` hook. Tests 728 → 738.
- `test_identity_lines` no longer names the default civilization; it reads the name from the engine.
- Saved settings naming an old civilization (e.g. `river_children`) fall back to Egypt with a warning, as designed.
- Follow-up (pre-existing, not this item): the `create` op's text says "Add a Insight" (wrong article); Library shows
  it too.
- Review change (AC9, AC10): a click on a civilization on the new game screen selects it and opens its details; the
  details put flavor and quote first. New hook `NewGameScreen.civilization_view(id)`. Tests 738 → 740.
- Review bug (AC11): Close didn't work over the new game screen. Godot routes mouse input by tree order, not z_index,
  and the new game screen is a later sibling of the details modal, so its full-screen CenterContainer took the click.
  The modal now moves itself to the end of its parent when it opens.
- Review change (AC12): the details modal takes an optional action (`open(view, action_text, action)`, hook
  `action_button()`); the new game screen passes "Play as <name>". Tests 740 → 743.
- Review bug (AC13): console errors on the new game screen. The details modal asks `card_details(uid)` first, which
  read zones before `new_game` made them. Right-click details there always hit it; AC9 made every click do it.
  `CardDetails.of_card` now skips missing zones. Tests 743 → 744.
