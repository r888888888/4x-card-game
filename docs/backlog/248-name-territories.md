---
id: 248
title: Name territories after the civilization's historical cities
type: feature
status: review
branch: feat/248-name-territories
---

## Goal
Each settled territory carries a city name, drawn by default from a list of historical city names for the player's
civilization (Egypt: Thebes, Memphis, …), and the player can rename any settled territory through a naming modal. The
realm reads as a civilization's cities rather than a row of land types.

## Acceptance criteria
- [x] AC1: Given a civilization card whose `city_names` is ["Alpha", "Beta", "Gamma"], when a game starts, then the
  starting territory (the Capital's) is named "Alpha"; when a Settler then settles a frontier territory, it is named
  "Beta", and the next one settled is named "Gamma".
- [x] AC2: Given that civilization has used all three names, when a fourth territory is settled it is named
  "Alpha II", then "Beta II", "Gamma II", "Alpha III", ….
- [x] AC3: Given no civilization, or a civilization with no `city_names`, when a territory is settled, then its name
  is its card's name (e.g. "River Meadow"). Frontier territories (unsettled) have no city name: `territory_name(uid)`
  returns the card's name for them.
- [x] AC4: Given a settled territory named "Alpha", when the player calls `rename_territory(uid, "  Nile Gate  ")`,
  then its name is "Nile Gate" (trimmed), no action or resource is spent, and the next default name is unchanged
  (the next settle still takes the next unused name from the list, not "Alpha").
- [x] AC5: `rename_territory_error` refuses, and `rename_territory` changes nothing, when: the name is empty after
  trimming ("Enter a name."); it is longer than 24 characters after trimming; the uid isn't a settled territory
  (a frontier territory, a non-territory card, an unknown uid); a decision is pending (`_blocked_error`); the game is
  over. A name already used by another territory is allowed.
- [x] AC6: The name is per copy and survives `GameState.copy()`; the count of default names handed out is game state
  too (a copied state settles the same next name).
- [x] AC7: Loader: a civilization's `city_names` must be a list of non-empty, distinct strings (an error naming the
  file, card and field otherwise); `city_names` on any other card type warns and is ignored (TYPE_FIELDS). Content
  invariant: every civilization in `civilizations` has at least 8 city names.
- [x] AC8 (UI): The territory view's title and the territory's card in the Realm show the city name, with the land
  name (card name) as a caption beneath it; the territory view has a "Rename…" button that opens the naming modal,
  prefilled with the current name. The modal's Rename button is disabled with `rename_territory_error` as its tooltip
  while the text is invalid; Enter or Rename applies it and closes, Esc / Cancel / click outside closes without change.

## Out of scope
- Prompting for a name when settling (names arrive automatically; renaming is optional).
- Naming frontier territories, cities or buildings separately from their territory.
- Bot behaviour: `ScriptedBot` never renames (names are cosmetic).
- Save/load (none exists yet).

## Design notes
- Data: civilization cards get `city_names: [String]` (TYPE_FIELDS: civilization only), parsed to
  `CardDef.city_names`. Content: about 10–12 historical names per civilization, the first being its traditional
  capital (Egypt: Thebes or Memphis; Sumer: Uruk; Phoenicia: Tyre; Babylon: Babylon; Greece: Athens; Persia:
  Pasargadae or Persepolis).
- State: `CardInstance.city_name` (""= unnamed, so `territory_name` falls back to `def.name`), copied by `copy()`;
  `GameState.names_given` (int) counts default names handed out, so renames never shift the sequence.
- Engine API: `territory_name(uid) -> String`, `rename_territory(uid, name)` / `rename_territory_error(uid, name)`
  (starts with `_blocked_error`), `const MAX_TERRITORY_NAME := 24`. Naming happens in `Territories.settle` and at
  setup for the starting territory. Log lines that name a settled territory may use the city name ("settled Beta
  (Hills)") — decide at red checkpoint.
- Numerals: II, III, IV, … from the cycle count (cycle 1 has no numeral).
- UI: `ui/rename_modal.gd` extends `Modal` on `main.modals`; a `LineEdit` (themed already in `GameTheme`), footer
  buttons Cancel and Rename via `add_footer_button`, focus with `FocusRing.focus`; tokens/palette/theme variations
  only, per `docs/design/tokens.md` and the guide's modal and form-field sections. The UI asks the engine for the error
  and the name; it never trims or measures the text itself.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_territory_names::test_settled_territories_take_the_civilizations_names_in_order` |
| AC2 | `test_territory_names::test_names_repeat_with_numerals_when_the_list_runs_out` |
| AC3 | `test_territory_names::test_without_city_names_a_territory_keeps_its_card_name`, `test_a_frontier_territory_has_its_card_name` |
| AC4 | `test_territory_names::test_rename_trims_the_name_and_spends_nothing`, `test_renaming_does_not_shift_the_next_default_name` |
| AC5 | `test_territory_names::test_rename_territory_error_refuses_bad_names_and_targets`, `test_rename_is_refused_while_a_decision_is_owed_or_the_game_is_over`; `test_blocking` (new `rename_territory` row) |
| AC6 | `test_territory_names::test_names_survive_a_state_copy` (and `test_state_copy`'s generic checks) |
| AC7 | `test_territory_names::test_city_names_load_on_a_civilization`, `test_city_names_validation`; `test_content::test_every_listed_civilization_has_at_least_8_city_names` |
| AC8 | `test_rename_modal::` `test_the_territory_view_and_its_card_show_the_city_name_over_the_land_name`, `test_rename_opens_the_naming_modal_prefilled_with_the_name`, `test_an_invalid_name_disables_rename_with_the_engines_reason`, `test_enter_renames_the_territory_and_closes_the_modal`, `test_rename_button_renames_and_an_invalid_enter_does_nothing`, `test_cancel_and_esc_close_without_renaming` |

## Manual check
- [ ] `godot --path . -- --civ egypt --seed 5`: the home card in the Realm reads "Thebes" over "Desert Floodplain".
- [ ] Click it: the view's title is "Thebes" with "Desert Floodplain" as a caption, and a small-caps "Rename…" beside it.
- [ ] Rename…: a drafting sheet "Rename territory" (context DESERT FLOODPLAIN), a NAME caption, the field with
  "Thebes" selected, Cancel and Rename under the footer rule. Try Day mode too.
- [ ] Clear the field: Rename dims, its tooltip says "Enter a name."; 25 characters: the length reason.
- [ ] Type "Nile Gate", Enter: the sheet closes, the view's title, its breadcrumb and the Realm card all read "Nile Gate".
- [ ] Play a Settler: the new territory is "Memphis". Esc / Cancel / a click outside leave a name unchanged.
- [ ] Review each civilization's 12 names (`data/cards.json`, `city_names`) for accuracy and order.

## Log
- AC5: renaming is refused while any decision is owed, a hand-limit discard included (the `_blocked_error` rule).
- Rename… sits beside the name as a small-caps link (`CapsLink`), not in the actions row: 227's approved test keeps the
  actions row hidden without population, and renaming has nothing to do with pop.
- The "city name, else card name" rule is `CardInstance.shown_name()`, used by `territory_name` and the card face.
  The board rebuilds a Realm card whose shown name changed (`CardView.shown_name`); `Navigator.retitle` keeps the
  breadcrumb in step after a rename.
- The settle log line still names the land ("settled Hills"); naming the city there is a possible follow-up.
- `engine/game_engine.gd` is at 688 lines (limit 700): the next item that grows it should split it first.
