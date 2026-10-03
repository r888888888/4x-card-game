---
id: 248
title: Name territories after the civilization's historical cities
type: feature
status: red-review
branch: feat/248-name-territories
---

## Goal
Each settled territory carries a city name, drawn by default from a list of historical city names for the player's
civilization (Egypt: Thebes, Memphis, …), and the player can rename any settled territory through a naming modal. The
realm reads as a civilization's cities rather than a row of land types.

## Acceptance criteria
- [ ] AC1: Given a civilization card whose `city_names` is ["Alpha", "Beta", "Gamma"], when a game starts, then the
  starting territory (the Capital's) is named "Alpha"; when a Settler then settles a frontier territory, it is named
  "Beta", and the next one settled is named "Gamma".
- [ ] AC2: Given that civilization has used all three names, when a fourth territory is settled it is named
  "Alpha II", then "Beta II", "Gamma II", "Alpha III", ….
- [ ] AC3: Given no civilization, or a civilization with no `city_names`, when a territory is settled, then its name
  is its card's name (e.g. "River Meadow"). Frontier territories (unsettled) have no city name: `territory_name(uid)`
  returns the card's name for them.
- [ ] AC4: Given a settled territory named "Alpha", when the player calls `rename_territory(uid, "  Nile Gate  ")`,
  then its name is "Nile Gate" (trimmed), no action or resource is spent, and the next default name is unchanged
  (the next settle still takes the next unused name from the list, not "Alpha").
- [ ] AC5: `rename_territory_error` refuses, and `rename_territory` changes nothing, when: the name is empty after
  trimming ("Enter a name."); it is longer than 24 characters after trimming; the uid isn't a settled territory
  (a frontier territory, a non-territory card, an unknown uid); a decision is pending (`_blocked_error`); the game is
  over. A name already used by another territory is allowed.
- [ ] AC6: The name is per copy and survives `GameState.copy()`; the count of default names handed out is game state
  too (a copied state settles the same next name).
- [ ] AC7: Loader: a civilization's `city_names` must be a list of non-empty, distinct strings (an error naming the
  file, card and field otherwise); `city_names` on any other card type warns and is ignored (TYPE_FIELDS). Content
  invariant: every civilization in `civilizations` has at least 8 city names.
- [ ] AC8 (UI): The territory view's title and the territory's card in the Realm show the city name, with the land
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
- [ ] Start as Egypt: the capital territory reads with its city name over its land name in the Realm and the view.
- [ ] Rename… opens a modal that matches the design guide (panel, title, field, button spacing, focus ring on Tab).
- [ ] Typing an empty or 25-character name disables Rename with the reason on hover; Enter renames; Esc cancels.
- [ ] Review each civilization's list of names for historical accuracy and order.

## Log
