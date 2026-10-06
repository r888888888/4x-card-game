---
id: 340
title: Loader tests as tables: the last one-off rejections and the "loads / defaults to" tests
type: chore
status: done
branch: feat/340-loader-test-tables
---

## Goal
Most loader rejections already sit in `check_cases` tables (046) in ~55 feature files. What's left is one test per
case: 16 one-off rejection tests beside tables they could be rows of, and ~60 positive tests ("an event loads with its
discard turns", "the supply defaults to empty", "era defaults to 1") that each load a card or config and check a
value or two, often behind an `if r.cards.has("x"):` guard. A `check_loads` table does for accepted input what
`check_cases` does for rejected input, so a new field adds a row, not a test. Tests stay in their feature files.
This compacts the loader tests before 338 and 339 refactor the loaders.

## Acceptance criteria
- [x] AC1: `tests/lib/test_case.gd` holds `check_loads(rows, load_input)`. Each row is `[label, input, expected]`:
  `load_input.call(input)` returns `{cards, config?, errors, warnings}`, and `expected` maps a dotted path
  (`"cards.x.era"`, `"config.supply"`, `"cards.x.is_permanent()"`) to the value it must equal. A row passes when
  there are no errors and no warnings and every path's value equals the expected one.
- [x] AC2: Given a fresh test case and a row whose loaded `cards.x.era` is 2 where 1 is expected (or that loads with
  a warning), when `check_loads` runs it, then that test case records a failure naming the row's label and the path
  (or the warning); a missing path is a failure naming the path, not a script error.
- [x] AC3: The one-off rejection tests become rows of their file's `check_cases` table (or a new table in that file):
  `test_settle_non_city_is_error`, `test_settle_unknown_card_is_error`, `test_explore_reveal_0_is_error`,
  `test_government_effect_needing_a_target_is_a_load_error`, `test_territory_printing_resource_keyword_is_error`,
  `test_unknown_resource_cost_is_still_an_error`, `test_administers_only_applies_to_governments`,
  `test_tolerates_only_applies_to_governments`, `test_an_events_revolt_field_is_unknown`,
  `test_growth_surplus_is_an_unknown_population_field`, `test_unrest_fallback_is_no_longer_read`,
  `test_unrest_relief_is_no_longer_read`, `test_population_start_must_fit_each_listed_home`. Each keeps the fragments
  it asserts today.
- [x] AC4: Every test whose only job is to check that a card field or config block loads, or what it defaults to, is a
  row of a `check_loads` table in its own file, with the values it checks today. The Log lists each test folded and
  its new row label.
- [x] AC5: A test file's loader wrapper that adds nothing to `fixture_load` or `config_errors` but fixed arguments
  goes: the table calls the shared helper (a bound `Callable`); a shared `config_load(overrides, sets := [])`
  returning `{cards, config, errors, warnings}` joins `config_errors` in `test_case.gd` for config rows.
- [x] AC6: Nothing is lost: every folded case runs as a row (the suite's test count drops by the number of tests
  folded, listed in the Log), and every remaining test passes unedited.

## Out of scope
- Moving loader tests between feature files (they stay where their feature is).
- Loader tests that also play the loaded game (they stay tests).
- The int-field table 338 adds for every (field, type) pair (340 leaves those int-field rows to it).

## Design notes
- Count from the review's scan: 121 loader-touching tests outside `check_cases`; 16 one-off rejections (AC3 lists the
  13 that are pure loader checks; `test_sim_run_files_reports_loader_errors`, `test_the_famine_card_is_never_in_…` and
  `test_an_upgrade_is_never_in_the_deck_…` check more than a message and stay); ~60 "loads / defaults / normalized /
  optional / cleanly" tests, mostly in `test_events`, `test_research`, `test_population`, `test_tech_eras`,
  `test_supply`, `test_data_loader`, `test_civ_home`, `test_gain_actions`, `test_government`.
- 48 per-file loader wrappers in 44 files today (`load_x` ×2, `load_action` ×3, `card_errors` ×2, `unit_load`,
  `tier_load`, …). Wrappers that add fixtures (a set, a resource list, extra cards) may stay; AC5 removes only the
  ones that are a renamed call.
- Paths in `expected`: a segment ending in `()` calls a method with no arguments; anything else is a key or property.
- Before 338 (compact the tests that cover the loaders before refactoring them); after 334 (shared helpers).

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_shared_helpers::test_check_loads_passes_a_clean_row_whose_paths_match`, `test_check_loads_indexes_arrays_and_int_keys_and_calls_builtin_methods` |
| AC2 | `test_shared_helpers::test_check_loads_names_the_row_and_path_of_a_wrong_value`, `test_check_loads_fails_a_row_that_loads_with_a_warning_or_an_error`, `test_check_loads_a_missing_path_is_a_failure_naming_the_path` |
| AC3 | `test_shared_helpers::test_the_one_off_loader_rejections_are_table_rows` |
| AC4, AC6 | The folded tests' rows (listed in the Log); the suite's count |
| AC5 | `test_shared_helpers::test_config_load_returns_cards_config_errors_and_warnings` |

## Log
- 2026-10-06: specced from the project review; the user chose to keep tables in the feature files and to table the
  positive load tests too.
- 2026-10-06: built. check_loads(rows, load) and value_at (a "()" segment calls through Expression, so built-in types'
  methods work and a missing one fails quietly; a number indexes an array or is an int key); config_load and
  config_load_on, plus card_load (one card's fixture_load) for the four files that each had their own card_messages.
  Suite 2304 → 2311 at red (7 new tests) → 2288: 23 fewer. The tests folded, where their rows went, and the wrappers
  that went (AC3 = rejection rows, AC4 = load rows):
  - test_settle (AC3): test_settle_non_city_is_error → test_bad_settle_is_a_load_error "not a city"; test_settle_unknown_card_is_error → "unknown card"
  - test_explore (AC3): test_explore_reveal_0_is_error → test_bad_explore_is_a_load_error "reveal 0"
  - test_government (AC3): test_government_effect_needing_a_target_is_a_load_error → test_bad_government_card_is_a_load_error "an effect needing a target"
  - test_government (AC4): test_government_cards_load → test_governments_and_starting_government_load "the fixture governments"; test_starting_government_is_optional → "no starting.government", "starting.government council"
  - wrappers: test_government card_errors → fixture_load.bind([TEST_GOVS])
  - test_territory_resources: test_territory_printing_resource_keyword_is_error → test_bad_resource_card_is_a_load_error "a territory printing a resource keyword" (AC3)
  - test_territory_resources: test_valid_resource_config_loads_cleanly → test_resource_config_loads "half gold (…)" (AC4)
  - wrappers: test_territory_resources gold_config_errors → gold_config_load (config_load_on); new gold_load
  - test_wealth: test_unknown_resource_cost_is_still_an_error → test_bad_cost_is_a_load_error "an unknown resource" (AC3); test_wealth_cost_and_gains_load → its own check_loads row "a wealth cost and gains" (AC4, name kept); load_x now fixture_load-based (adds TEST_CARDS, returns warnings)
  - test_admin_unrest: test_administers_only_applies_to_governments → test_administers_on_the_wrong_type_is_a_load_warning "on a building" (AC3)
  - test_anarchy: test_unrest_fallback_is_no_longer_read → test_unrest_block_validation "fallback is no longer read" (AC3; drops its "not in the normalized block" check: the defaults row pins the normalized block)
  - test_leaving_anarchy: test_unrest_relief_is_no_longer_read → test_retired_unrest_fields_are_load_warnings "relief is no longer read" (AC3; same note)
  - test_revolution: test_an_events_revolt_field_is_unknown → test_retired_revolt_field_is_a_load_warning "an event's revolt" (AC3)
  - test_size_unrest: test_tolerates_only_applies_to_governments → test_tolerates_on_the_wrong_type_is_a_load_warning "on a building" (AC3)
  - test_anarchy: test_the_unrest_block_loads_with_its_defaults → its own check_loads row (AC4, name kept)
  - test_anarchy_drain: test_drain_pct_loads_and_is_optional → rows "drain_pct 20", "absent" (AC4, name kept)
  - wrappers: anarchy_case raw_config_errors → raw_config_load ({cards, config, errors, warnings})
  - test_civ_home: test_population_start_must_fit_each_listed_home → test_home_config_validation "population.start must fit each listed home (…)" (AC3; one_error keeps "no error for Highlanders"); test_home_validation's trailing warning check → row "on a building"; test_home_loads_on_a_civilization → its own check_loads row (AC4, name kept)
  - test_growth_cards: test_growth_surplus_is_an_unknown_population_field → test_retired_population_fields_are_load_warnings "growth_surplus" (AC3; drops the normalized-block check); test_grow_op_loads → row "amount 2 on each" (name kept); test_best_loads_on_any_card_type + test_count_loads_with_each → test_best_and_count_load rows "best on an action/a building/a unit/an event/a tech", "count with each"
  - wrappers: test_civ_home card_errors, home_config_errors → home_load, home_config_load; test_growth_cards grow_card_errors → grow_load (= grow_on an action; both on fixture_load)
  - test_actions: test_government_actions_load → its own row "the fixture governments" (name kept)
  - test_build_menu: test_build_menu_loads_with_defaults → rows "normalized", "an empty menu", "no build_menu: {}" (name kept)
  - test_building_tiers: test_a_building_loads_its_tier → row "the fixture buildings" (name kept)
  - test_choice_events: test_choices_load_on_an_event → row "Envoys and a plain event" (name kept; effects' ops as size() + .0.op)
  - test_civ_flavor: test_civilization_flavor_and_quote_load_without_warnings + test_flavor_and_quote_are_optional → test_civilization_flavor_and_quote_load_and_are_optional rows "flavor and quote", "no quote", "no flavor"
  - wrappers: card_messages (test_civ_flavor, test_famine_guard, test_population, test_tech_event_flavor) → shared card_load(card, sets); menu_load and tier_load on config_load_on; func(args) → x.callv in test_build_menu, test_building_tiers, test_eurekas
  - test_civilization: test_civilization_cards_load + test_starting_civilization_is_optional (+ the trailing "start gain on a civilization" check) → test_civilizations_and_starting_civilization_load rows "the fixture civilizations", "start gain on a civilization", "no starting.civilization", "starting.civilization tribe"
  - test_choose_civilization: test_civilizations_list_loads + test_civilizations_list_is_optional (+ validation's trailing positive check) → test_civilizations_list_loads_and_is_optional rows "civilizations in order", "no list", "starting.civilization without a list", "starting civilization in the list"
  - wrappers: test_civilization card_errors → fixture_load.bind([TEST_CIVS]); one-line table lambdas that only fixed arguments or projected .errors → bound Callables / callv (actions, cost_per_territory, choose_civilization, civilization, discounts, events, famine, famine_relief, gain_per_keyword, government, harmful_ops, lose_pct, lose_per_keyword, modifiers, research, tech_eras, trash, unrest, upgrades, wonder_sites)
  - test_data_loader: test_bug_048_create_loads_into_tableau_hand_discard_and_deck + test_city_slots_loads → test_cards_load rows "city slots", "048: create into the tableau/hand/discard/deck" (parse now returns cards)
  - test_defence: test_defense_loads_on_buildings_and_cities → row "Palisade and Town" (name kept)
  - test_eurekas: test_card_and_tag_eurekas_load → rows "a card eureka", "a tag eureka" (name kept)
  - test_discounts: test_discounts_load → row "the fixtures" (name kept)
  - test_gain_actions: test_gain_actions_loads → row "Drill and Muster" (name kept); its validation's load_one lambda → card_load.bind
  - test_gain_per_keyword: test_gain_per_keyword_loads → rows "Hunt", "amount is optional and defaults to 1", "a resource keyword is known" (name kept)
  - test_events: test_event_loads_with_discard_turns + test_event_discard_defaults_to_one_turn + test_grow_each_on_an_event_loads → test_events_load rows "discard turns", "discard defaults to one turn", "grow each on an event"; test_event_deck_is_normalized + test_event_deck_defaults_to_empty → test_event_deck_loads rows "normalized", "defaults to empty"
  - test_hand_limit: test_hand_limit_defaults_to_7 → row "default" (name kept; reads the config, not a new game's); parse_with → config_load
  - test_harmful_ops: test_lose_and_lose_pop_load_on_a_building → row "lose and lose_pop" (name kept)
  - test_famine_guard: test_building_housing_and_famine_guard_load → row "Silo, Farm and Homeland (…)" (name kept)
  - test_insight: test_a_tech_costing_insight_loads → row "insight 2" (name kept); tech_errors → tech_load
  - test_keywords: test_keyword_fields_load_without_warnings → row "requires and an effect keyword" (name kept)
  - test_lose_pct: test_lose_pct_loads_and_may_trigger_on_upkeep → rows "Fire", "on upkeep", "100% is allowed" (name kept)
  - test_lose_per_keyword: test_lose_per_keyword_loads_and_may_trigger_on_upkeep → rows "Storm", "on upkeep", "amount is optional and defaults to 1" (name kept)
  - test_population: test_housing_defaults_to_slots_plus_2 + test_housing_loads_when_given → test_housing_loads_and_defaults_to_slots_plus_2 rows "defaults: …", "given"; test_population_block_defaults + test_population_block_values_load + test_no_population_block_leaves_population_off + test_population_start_equal_to_starting_housing_loads → test_population_block_loads rows "defaults (no tiers: 281)", "values (no tiers: 281)", "no population block -> empty (off)", "start == starting housing is fine"; parse_test_cards removed (fixture_load)
  - test_modifiers: test_modifiers_load_on_permanent_cards → row "Palace's, and a negative value" (name kept)
  - test_raids: test_raid_loads_on_an_event → row "Raiders, Horde (no targets) and a plain event" (name kept)
  - test_research: test_tech_with_an_insight_cost_loads + test_prereq_loads (+ the cycle test's trailing "a chain loads") → test_techs_load rows "an insight cost (techs are permanent)", "a prereq", "a prereq chain"; test_research_deck_is_normalized + test_research_deck_defaults_to_empty → test_research_deck_loads rows "normalized", "defaults to empty"
  - test_tech_eras: test_era_defaults_to_1_and_loads + test_add_era_loads → test_era_and_add_era_load rows "default era", "era 2", "add_era"; test_era_unlocks_is_normalized + test_era_unlocks_defaults_to_empty → test_era_unlocks_loads rows "normalized", "defaults to empty"; threshold_config_errors → era_unlocks_load
  - test_territories: test_territory_card_loads_with_slots_and_keywords → row "Hills (territories are permanent)" (name kept); test_territory_deck_is_normalized + test_config_without_territories_loads_cleanly → test_territory_config_loads rows "territory_deck normalized", "without territories: the defaults"
  - test_supply: test_supply_block_is_normalized + test_supply_defaults_to_empty → test_supply_block_loads rows "normalized", "defaults to empty"; test_unlock_op_loads → row "unlock Guildhall" (name kept); supply_errors → supply_load
  - test_terrains: test_terrains_list_loads_into_the_config + test_terrains_default_to_empty + test_one_terrain_with_features_loads → test_terrains_list_loads rows "normalized terrains; Peak and River (a terrain plus features) load", "no terrains"; terrain_errors → terrain_load (new terrain_cards_load)
  - test_trash: test_trash_loads → row "Purge" (name kept)
  - test_trade: test_trade_op_loads → row "Trade" (name kept)
  - test_training: test_training_loads_on_buildings → row "Drill Yard and Sparring Ring" (name kept)
  - test_tiers: test_tiers_load_and_are_optional → rows "the fixture tiers, in the normalized block", "no tiers: []" (name kept); tier_messages on config_load_on, null = no tiers
  - test_units: test_unit_loads_with_its_strength → row "Levy (a unit is permanent)" (name kept)
  - test_upgrades: test_an_upgrade_loads_its_base → row "Plough, Cathedral and a Farm (no upgrade)" (name kept)
  - test_territory_names: test_city_names_load_on_a_civilization → row "Founders' names, none by default" (name kept); new names_load
  - wrappers: test_civ_start_building start_db and test_event_eras era_db / load_event no longer copy fixture_load's parse (fixture_load, card_load)
- Checks dropped while folding: the "not in the normalized block" asserts of the fallback, relief and growth_surplus
  one-offs (check_cases has no such kind; the unrest defaults row pins the normalized unrest block exactly). Rows also
  fail on warnings, which some folded tests didn't check: none warned.
- Left as tests: loads tests that also check card text (rules_text needs the db), play the game (gain_per_pop,
  raid_pacing), check the real data, or expect a warning while checking a value (test_prereq_on_a_card_that_is_not_a_tech_is_ignored).
- add-effect's loader step now asks for a check_loads table; testing.md's loader paragraph and helper rows say how.
