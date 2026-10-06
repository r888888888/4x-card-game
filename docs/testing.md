# Testing

Dependency-free runner: no addon, just Godot headless.

## Running

```bash
scripts/test.sh              # everything but tests/balance/
scripts/test.sh rules        # files/tests whose "file::method" contains "rules"
scripts/test.sh test_create  # a single test (or group) by name
scripts/test.sh --balance    # only tests/balance/ (filter as above)
```

**The balance suite** (`tests/balance/`): tests that play GenericBot games on the real data (`data/*.json`): the
sim's report, its options and the parallel run. They grow with every bot change, so the main suite and the Stop hook
leave them out; run `scripts/test.sh --balance` when touching `sim/`. Bot rules and `SimStats` stay in the main suite,
tested on fixture games of a few turns.

The script re-imports the project first when a `.gd` file changed, so a new `class_name` resolves
in the same run. Output is quiet: one `FAIL` line per problem, then `N tests, M failures`.
Exit code 0 means green.

**Speed (223).** The suite takes ~11 s on a 12-core Mac (~40 s serial). Godot's start costs ~3 s per shard; the
slowest file, `test_generic_bot_cache.gd`, plays its 6 bot games once and shares them (335). Three settings help:
- The test files run in parallel shards, one Godot process per CPU (`TEST_JOBS=n` to change it; 1 runs serially).
  The slow files (`TestShards.SLOW`) go first, then shard i of n gets every n-th file (`TEST_SHARD=i/n`). Each
  shard has its own empty `HOME` (no `//` in its path, 330), so no two share `user://` and a run never touches the
  player's settings. Tests must not depend on which files ran before them.
- The runner turns off headless Godot's frame sleep (6.9 ms a frame), and the script passes `--fixed-fps 120`: every
  frame advances 1/120 s of game time however long it really took. Timers and tweens finish after a fixed number of
  frames, so a test that waits for an animation (`create_timer`, `wait_screen_transition`) is quick and deterministic.
  A test that checks an animation part-way through should wait frames or game seconds, never wall-clock time.
  `Sfx.clock()` is the wall clock, so a test that checks when a sound is due freezes it first (`main.sfx.set_clock`),
  then compares against that time (236).
- The engine isn't the cost (a `make_engine` game builds in 0.5 ms); building and freeing the main scene is (~18 ms
  per UI test).

A test fails when:
- an assertion fails (`eq`, `check`, `has_msg`);
- it makes no assertions (empty, or crashed before the first one);
- any engine or script error is logged while it runs (null access, missing method, `push_error`), unless the test
  expected it with `expect_error(fragment)` (then the test fails if no such error is logged);

and the whole run fails if a test file doesn't parse or the filter matches nothing.

## Writing tests

Put tests in `tests/test_<area>.gd`. Each file opens with a `##` header saying what it covers (the suite checks):
that header is the source. The index below gives each file one short row (the suite checks it lists every file, in
rows of at most 160 characters); "UI" marks files that run the real `main.tscn`.

| File | Covers |
|---|---|
| `tests/balance/test_parallel_sim.gd` | Balance suite: the sim on several processes (152, 291, 318) |
| `tests/balance/test_sim_anarchy_report.gd` | Balance suite: the Anarchy, government and famine metrics (158) |
| `tests/balance/test_sim_cache_runs.gd` | Balance suite: the sim's result cache (292) |
| `tests/balance/test_sim_compare_runs.gd` | Balance suite: comparing two checkouts game by game (293) |
| `tests/balance/test_sim_reports.gd` | Balance suite: the sim's report (042, 134, 135) |
| `tests/test_action_errors.gd` | `discard_error`, `choose_error`, and the main scene showing their reasons (093) |
| `tests/test_actions.gd` | Actions per turn (127) |
| `tests/test_admin_unrest.gd` | Admin unrest (319) |
| `tests/test_anarchy.gd` | Anarchy (145) |
| `tests/test_anarchy_drain.gd` | Anarchy's drain (156) |
| `tests/test_anarchy_event.gd` | Anarchy as an event (253) |
| `tests/test_anarchy_length.gd` | Anarchy's length (155) |
| `tests/test_blocking.gd` | Every action refused while a decision is owed or the game is over (171, 172) |
| `tests/test_board_faces.gd` | Board card faces (138; UI) on a `board_engine` game |
| `tests/test_board_labels.gd` | The board's game words (UI) |
| `tests/test_board_layout.gd` | The board without a sidebar (115; UI) |
| `tests/test_board_row.gd` | One board row (137; UI) |
| `tests/test_build_menu.gd` | The build menu (295) |
| `tests/test_build_ceremony.gd` | The build ceremony (357; UI) |
| `tests/test_build_modal.gd` | Building from a territory's view (297; UI) |
| `tests/test_building_tiers.gd` | Buildings that need a settlement tier (301) |
| `tests/test_button_widths.gd` | Button widths (100; UI) |
| `tests/test_cabinet_doors.gd` | The government choice behind cabinet doors (209; UI) |
| `tests/test_built_signal.gd` | The engine's `built` signal (357) |
| `tests/test_card_details.gd` | `def_details` / `card_details`: rules, live state and terms (056, 289) |
| `tests/test_card_faces.gd` | Index-card faces and card motion (179) |
| `tests/test_card_landing.gd` | How a card lands (117) |
| `tests/test_card_slots.gd` | Card slots (UI) start at their card's resting height (075) |
| `tests/test_card_text.gd` | Card text generated from effects |
| `tests/test_changed.gd` | The `changed` signal |
| `tests/test_choice_events.gd` | Choice events (269) |
| `tests/test_choice_modal.gd` | The event modal for a choice event (269; UI) |
| `tests/test_choose_civilization.gd` | Choosing a civilization (064) |
| `tests/test_civ_flavor.gd` | Civilization `flavor` and `quote` (107) |
| `tests/test_civ_home.gd` | A civilization's `home` territory (111) |
| `tests/test_civ_start_building.gd` | A civilization's start building (133) |
| `tests/test_civilization.gd` | Civilization cards (062) |
| `tests/test_content.gd` | The real data: invariants over the whole data set (006, 145) |
| `tests/test_cost_per_territory.gd` | Cost per territory (320) |
| `tests/test_counter_and_card_sounds.gd` | Counter and card sounds (188; UI), `main.sfx`'s clock frozen |
| `tests/test_counters.gd` | The top bar's and the Supply screen's counters by name (177) |
| `tests/test_data_loader.gd` | `DataLoader`: JSON parsing, validation errors and warnings |
| `tests/test_day_mode.gd` | Day mode (183; UI) |
| `tests/test_default_government.gd` | The government choice's default (254) |
| `tests/test_defence.gd` | Territory defence (161) |
| `tests/test_details_modal.gd` | The details modal (056, 225, 229, 259; UI) |
| `tests/test_diffusion.gd` | Diffusion (142) |
| `tests/test_discounts.gd` | Civilization `discounts` (108) |
| `tests/test_docs.gd` | The docs stay true to the tree; test file headers and this index (330, 331) |
| `tests/test_end_turn_key.gd` | End turn as the specimen's key (203) at the sidebar's foot (UI) |
| `tests/test_end_turn_returns.gd` | Ending the turn returns to the Realm (290; UI) |
| `tests/test_engine_scaling.gd` | How engine queries scale with the tableau (150) |
| `tests/test_engine_structure.gd` | GameEngine's split (249, 281) |
| `tests/test_era_sheet.gd` | The era ceremony (211; UI) |
| `tests/test_eurekas.gd` | Eurekas (141) |
| `tests/test_event_eras.gd` | Event decks by era (074) |
| `tests/test_event_modal.gd` | `event_drawn`, `outcome_summary`, and the drawn-event modal (079; UI) |
| `tests/test_event_panel.gd` | The active events (in the Realm's row since 137; UI) |
| `tests/test_event_sounds.gd` | Event sounds (191; UI) |
| `tests/test_events.gd` | The event deck (039, 237) |
| `tests/test_events_at_turn_start.gd` | When the turn's event is drawn (237) |
| `tests/test_explore.gd` | The `explore` op |
| `tests/test_famine.gd` | The Famine (083) |
| `tests/test_famine_guard.gd` | Building `housing` and `famine_guard` (060) |
| `tests/test_famine_relief.gd` | Relieving a Famine (084) |
| `tests/test_focus_ring.gd` | The focus ring waits for Tab (230) |
| `tests/test_food_upkeep.gd` | Pop eating food at upkeep, and a first shortfall's one death |
| `tests/test_forecast.gd` | `upkeep_forecast` |
| `tests/test_gain_actions.gd` | The `gain_actions` op (128) |
| `tests/test_gain_per_keyword.gd` | The `gain_per_keyword` op (081) |
| `tests/test_gain_per_pop.gd` | The `gain_per_pop` op (304) |
| `tests/test_game_state.gd` | `GameState.copy` and `GameEngine.fork` |
| `tests/test_generic_bot.gd` | The generic bot (313) on fixture games; expansion costs (321) |
| `tests/test_generic_bot_cache.gd` | The bot's forecast cache (315) |
| `tests/test_generic_raids.gd` | The generic bot meets raids (314, superseding 168) through `turn_forecast` |
| `tests/test_generic_rollouts.gd` | The generic bot's rollouts (314, porting 159) |
| `tests/test_government.gd` | Government cards (065) |
| `tests/test_government_deck.gd` | The government deck (154) |
| `tests/test_grow_meter.gd` | The territory view's pop meter (124; UI) |
| `tests/test_growth_cards.gd` | The `grow` op (013, 261, 262) |
| `tests/test_hand_limit.gd` | The hand: `hand_size`, `hand_limit`, `discard_needed` / `discard_card`, voluntary discards |
| `tests/test_hand_size.gd` | Hand size as a modifier (109) |
| `tests/test_harmful_ops.gd` | The `lose` and `lose_pop` ops (072) |
| `tests/test_housing_modifier.gd` | The `housing` modifier key (110) |
| `tests/test_hover_sound.gd` | Hover sound (245; UI) |
| `tests/test_identity_cards.gd` | The civilization modal as two cards (231) |
| `tests/test_identity_lines.gd` | The civilization and government (088, 115, 119; UI) |
| `tests/test_insight.gd` | Insight (139) |
| `tests/test_insight_per_gain.gd` | The `insight_per_gain` modifier (157) |
| `tests/test_key_sounds.gd` | Key sounds (187; UI) |
| `tests/test_keywords.gd` | Territory keywords, `requires` and keyword effects (005) |
| `tests/test_knowledge_screen.gd` | The Knowledge screen (208; the tech tree modal before it, 059, 140; UI) |
| `tests/test_launch_options.gd` | Command-line options (135) |
| `tests/test_leaving_anarchy.gd` | Restoring order (146, 155) |
| `tests/test_legal_actions.gd` | `legal_actions` (312) |
| `tests/test_legend_key.gd` | The toggle key (182; the window bar since 219; UI) |
| `tests/test_log_drawer.gd` | The log drawer (115; UI) |
| `tests/test_lose_pct.gd` | The `lose_pct` op (268) |
| `tests/test_lose_per_keyword.gd` | The `lose_per_keyword` op (268) |
| `tests/test_menu.gd` | The menu (UI) |
| `tests/test_milestones.gd` | Milestones (191) |
| `tests/test_modal_sheets.gd` | Modals as drafting sheets (207; UI) |
| `tests/test_modal_stack.gd` | The modal stack (153; UI) on a seed-1 game with the tech tree and a tech's details over it |
| `tests/test_modifiers.gd` | Standing `modifiers` (129) |
| `tests/test_navigator.gd` | `Navigator` (103) on plain Controls |
| `tests/test_notice_priorities.gd` | Notice priorities (190) |
| `tests/test_notification_flags.gd` | Notification flags (250, guide §15.9; UI) |
| `tests/test_odometer.gd` | `Odometer` (181; UI) |
| `tests/test_palette_roles.gd` | Palette roles (192) |
| `tests/test_pending.gd` | `pending()` for each decision kind and the one blocking rule (050, 172) |
| `tests/test_play_outcome.gd` | `card_played`: the outcome reported for each card play (007) |
| `tests/test_population.gd` | Population: pop, housing, feeding, workers |
| `tests/test_prices.gd` | Prices and unrest in one place (173) |
| `tests/test_raid_modal.gd` | The raid modal (271; UI) |
| `tests/test_raid_pacing.gd` | Raid pacing (257) |
| `tests/test_raids.gd` | Barbarian raids (162) |
| `tests/test_ready_lamp_keys.gd` | The ready lamps on Knowledge and Buy Cards (288; UI) |
| `tests/test_ready_lamps.gd` | Ready lamps (288) |
| `tests/test_recruit.gd` | Recruiting units from the build menu (296) |
| `tests/test_rename_modal.gd` | Names on screen and the naming modal (248) (seed 5, Egypt; UI) |
| `tests/test_renewal.gd` | Renewal (147) |
| `tests/test_renewal_modal.gd` | The Renewal modal (255) |
| `tests/test_research.gd` | Techs: the research deck, learning, prerequisites (025, 139, 140) |
| `tests/test_resource_glyphs.gd` | Resource glyphs (180; UI) |
| `tests/test_resource_tokens.gd` | Counter changes (114, 126, 181, 218; UI) |
| `tests/test_revolt_modal.gd` | Revolt from the civilization modal (205; UI) |
| `tests/test_revolution.gd` | Revolution (148, 155) |
| `tests/test_rules.gd` | `GameEngine` rules: setup, playing cards, the turn loop, scoring, game end |
| `tests/test_scaffolding.gd` | No red-phase scaffolding left in tests (333; `tests/lib/scaffolding_checks.gd`) |
| `tests/test_shared_helpers.gd` | Shared UI test helpers; no copies of `tests/lib/` helpers (334) |
| `tests/test_screen_header.gd` | The screens' `ScreenHeader` and transitions (104, 118; UI) |
| `tests/test_script_size.gd` | Script size limits (`tests/lib/script_sizes.gd`) |
| `tests/test_select_list.gd` | The selectable list (217) |
| `tests/test_settings.gd` | `SettingsStore`: saving and loading the player's settings (183) |
| `tests/test_settings_modal.gd` | The Settings modal (206; UI) |
| `tests/test_settle.gd` | The `settle` op (loading and play) and card targets |
| `tests/test_sfx.gd` | The sound player (186) |
| `tests/test_sheet_sounds.gd` | Sheet, screen and notice sounds (189; UI), `main.sfx`'s clock frozen |
| `tests/test_sidebar.gd` | The right sidebar (202; UI) |
| `tests/test_sim.gd` | The simulator on fixtures |
| `tests/test_sim_anarchy.gd` | Sim metrics for Anarchy, governments and famine (158) |
| `tests/test_sim_cache.gd` | The sim cache's code hash (292) |
| `tests/test_sim_compare.gd` | Comparing two checkouts (293) |
| `tests/test_sim_procs.gd` | How many processes a sim run uses (291) |
| `tests/test_sim_stall.gd` | A parallel run's stalled or dead worker (318) |
| `tests/test_sim_strategies.gd` | `SimStats` per strategy and civilization (134) |
| `tests/test_size_unrest.gd` | Size unrest (282) |
| `tests/test_slots.gd` | Building slots |
| `tests/test_sound_rows.gd` | The sound rows (185; UI) |
| `tests/test_sound_settings.gd` | Sound settings and the audio buses (184) |
| `tests/test_spacing_tokens.gd` | Spacing and radius tokens (193) |
| `tests/test_start_screen.gd` | The title, new game and settings screens (063, 099; UI) |
| `tests/test_state_copy.gd` | `GameState.copy()` and `CardInstance.copy()` carry every variable and share nothing (171) |
| `tests/test_sunrise_art.gd` | The title screen's art (214) |
| `tests/test_supply.gd` | The card supply (032, 057) |
| `tests/test_supply_screen.gd` | The Supply screen's pile cards (232; UI) |
| `tests/test_surfaces.gd` | Wood grain, paper and soft shadows (341; UI) |
| `tests/test_tech_eras.gd` | Eras: `era`, the `add_era` and `research` ops, `future_techs`, the next era arriving (027) |
| `tests/test_tech_event_flavor.gd` | Tech/event/action `flavor`, tech `quote` (215) |
| `tests/test_tech_gives_modal.gd` | A tech's details' Gives row (289; UI) |
| `tests/test_tech_tree.gd` | `tech_tree()` (states, cost now, `gives`, `affordable`) and `era_name` / config `era_names` |
| `tests/test_terrains.gd` | Terrain keywords (130) |
| `tests/test_territories.gd` | Territory cards, `keywords` / `territory_deck` / `starting.territory` config, territory setup |
| `tests/test_territory_cards.gd` | Territories as plain cards in the Realm (102) |
| `tests/test_territory_names.gd` | Territory names (248) |
| `tests/test_territory_resources.gd` | Rolled resource keywords |
| `tests/test_territory_view.gd` | The territory view (101; UI) |
| `tests/test_test_runner.gd` | The runner itself (223) |
| `tests/test_theme.gd` | The UI theme (106) |
| `tests/test_tiers.gd` | Settlement tiers (281) |
| `tests/test_title_screen.gd` | The title screen as a ledger (213; UI) |
| `tests/test_toasts.gd` | Toasts and the unread marker (116; UI) |
| `tests/test_trade.gd` | The `trade` op |
| `tests/test_training.gd` | Training (164) |
| `tests/test_trash.gd` | The `trash` op (082) |
| `tests/test_trash_targeting.gd` | Trash targeting (UI) |
| `tests/test_turn_forecast.gd` | `turn_forecast` (309) |
| `tests/test_type_tokens.gd` | Text sizes (194) |
| `tests/test_ui_queries.gd` | Engine queries the UI relies on (049, 094, 175, 180) |
| `tests/test_ui_smoke.gd` | The real `main.tscn` follows a whole game played by `play_first_legal` (314) |
| `tests/test_ui_structure.gd` | The shape of `ui/`: one script per component, no engine internals (052, 175, 176, 316) |
| `tests/test_unit_moves.gd` | Moving and disbanding units (163) |
| `tests/test_units.gd` | Unit cards (160) |
| `tests/test_unrest.gd` | Unrest (144) |
| `tests/test_upgrade_ribbons.gd` | Upgrades on screen (302; UI) |
| `tests/test_upgrades.gd` | Building upgrades (300) |
| `tests/test_vellum.gd` | Targeting under vellum (210; UI) |
| `tests/test_wealth.gd` | Wealth, the second resource |
| `tests/test_wonder_sites.gd` | Wonders built over turns (286) |
| `tests/test_workers.gd` | Workers |
| `tests/test_would_target.gd` | `would_need_target` / `would_target` (310) |

Add a new file when an area grows past ~300 lines or is a separate concern.

```gdscript
extends "res://tests/lib/test_case.gd"
## One line: what this file covers.


func test_settler_creates_city_on_tableau() -> void:
	# Given
	var e := make_engine({"settler": 10})
	e.resources.food = 3
	# When
	check(e.play_card(first_in_hand(e)), "play should succeed")
	# Then
	eq(card_ids(e.zone("tableau")), ["capital", "city"], "tableau")
	eq(e.resources.food, 0, "food after paying 3")
```

The runner creates a fresh instance for every `test_*` method, so tests don't share state. It waits one frame
before the first test so the `Game` and `Settings` autoloads are in the tree and ready. Otherwise no frames run unless
a test awaits them, so UI tests see structure (views, labels, overlays), never finished animations. The runner
awaits every test: a UI test that measures laid-out sizes or positions calls `await wait_frames()` first (088).
After each test the runner frees anything the test left in the
tree (a UI test that crashed before `close_main`), so one crash doesn't fail every later UI test (087).
Before the first test the runner swaps the `Settings` store for a fresh one (`user://test_run_settings.cfg`, its
defaults), so the player's settings never change a result; it prints a `WARN` line if the player's
`user://settings.cfg` changed during the run (195, 196: `tests/lib/settings_watch.gd`). A test that needs a setting on
uses `with_temp_settings` or `with_reduce_motion`.

### Available in every test (`tests/lib/test_case.gd`)

Each helper's `##` comment in `tests/lib/test_case.gd` has the details (331).

| Name | Use |
|---|---|
| `eq(actual, expected, what)` | Equality. Always pass `what` so failures say which value was wrong |
| `check(cond, message)` | Boolean assertion |
| `has_msg(messages, fragment)` | Some loader error/warning contains `fragment` |
| `check_noticed(recorded, fragment, priority)` | A notice follows its log line in `record_messages`' recording |
| `expect_error(fragment)` | An error containing `fragment` must be logged (`push_error`) during the test |
| `make_engine(deck, overrides, seed, extra_cards)` | New game from `TEST_CARDS` plus `extra_cards` (raw card dicts one file needs) |
| `TEST_CARDS` | Small, stable card set (includes territories `grassland` and `hills`) |
| `tests/lib/tech_case.gd` | Base class for tech tests: `TECHS`, `tech_db`, `tech_engine` |
| `tests/lib/raid_case.gd` | Base class for raid tests: `RAID_CARDS`, `raid_load`, `raid_engine` |
| `tests/lib/anarchy_case.gd` | Base class for Anarchy tests (145–148): fixture governments, `anarchy_engine` |
| `keywords()` | Keyword ids the `TEST_CARDS` territories use; pass to `parse_cards` |
| `raw_config(deck, overrides)` | Config dictionary for loader tests |
| `fixture_load(extra, sets, resource_list, resource_keywords)` | `TEST_CARDS`, fixture sets (`[TEST_GOVS]`, …), then `extra`, parsed for loader tests |
| `fixture_db(extra, sets, resource_list)` | `fixture_load`'s cards, failing the test on a load error (170) |
| `cards_of(r, errors, warnings)` | A `fixture_load` result's cards, its errors and warnings appended to the out arrays |
| `config_errors_for(cards, overrides, deck)` | The errors from parsing a config against the parsed card db `cards` |
| `config_errors(overrides, sets, deck)` | `config_errors_for` on `fixture_db([], sets)` |
| `explore_engine()` / `over_engine()` | A game with an explore choice open; a finished game |
| `card_with(type, effect)` / `set_home_pop(engine, n)` / `capital_land(engine)` | A card "x" with one effect; the home's pop; the Capital's territory |
| `card_ids(zone)` / `first_in_hand(engine)` / `home_uid(engine)` | Inspection helpers; `home_uid` is the config's starting territory |
| `uid_of(zone, id)` / `sorted(array)` | First uid with that id (or -1); a sorted copy |
| `arrange(zone, ids_top_first)` | Puts those cards on top of the zone, top first; the rest stay below |
| `settle(engine, ids)` / `to_frontier(engine, ids)` | Moves those territory copies from `territory_deck` to the tableau / frontier |
| `wait_frames(n)` | Lets containers lay out before a UI test measures sizes or positions (088) |
| `put_in_hand(engine, id)` | Puts a new copy in the hand (via `create_card`) and returns its uid |
| `put_in(engine, id, zone)` | Same, into any zone (a government placed directly) |
| `build_on(engine, territory_uid, ids)` | Puts new copies of those buildings straight on a territory, in order |
| `check_cases(cases, load)` | Table-driven loader validation: rows `[label, input, fragment(s), kind]` |
| `TEST_CIVS` / `civ_db()` / `civ_engine(civ, deck, overrides)` | Fixture civilizations and a game as one (062) |
| `TEST_GOVS` / `gov_db()` / `gov_engine(gov, deck, overrides)` | Fixture governments and a game under one (065) |
| `TEST_EVENTS` / `event_db()` | Fixture events (039) and their card db |
| `with_event_engine(body, event_deck, overrides)` | UI tests: `body` with `Game.engine` on `TEST_CARDS` + `TEST_EVENTS` |
| `open_main()` / `close_main(main)` / `play_seed_1(main, after_turn)` | UI tests: add and free the main scene; play seed 1 to the end |
| `with_temp_settings(body, path)` | Runs `body` with the settings saved to a temp file, then restores them |
| `shown_state(key)` | The state a toggle key shows, "ON" or "OFF" (219) |
| `close_event(main)` | UI tests: closes the drawn-event modal if one is up |
| `mid_game()` / `each_screen(visit)` / `visible_controls(root)` | UI: a seed-1 game at turn 3; every screen and modal; visible controls |
| `with_main(engine, body)` / `with_territories_main(body, deck, overrides)` / `with_game(calm, body)` | UI: `body(main)` on the main scene, seed 1 |
| `state_dump(v)` / `state_equal(a, b)` / `state_diff(a, b)` | Deep state as text, equality on it, and what differs |
| `script_vars(o)` / `shared_refs(a, b)` / `scribble(v)` | Script variables; shared references; change everything in place |
| `accent_footer(modal)` | UI tests: a modal's footer buttons in the primary look (251) |
| `press_key(main, keycode)` | UI tests: presses and releases a key through main's viewport |
| `open_game(big, freeze_sfx)` / `close_game(main)` | UI tests: main on seed 1 (1920 × 1080, the sound clock frozen, if asked) (334) |
| `click_control` / `click_point` / `move_mouse` / `away` / `centre` / `hovers` / `open_details` | UI: real clicks and moves, hover ticks, a card's details |
| `shown_button(root, prefix)` / `wait_seconds(s)` / `hills_of(engine)` | The first shown button by text; game seconds; Hills' uid |

A helper a second test file needs moves to `tests/lib/` (the suite checks copies, 334); look there before writing one.
Helpers take and return `GameEngine` (the suite fails on an engine typed `Object`, 333). Tests never call engine
members that start with `_`: if setup needs one, add a public method.

### Guidelines

- **One behavior per test**, named for the behavior: `test_cannot_afford`, not `test_play_card_2`.
- **Concrete numbers** that match the acceptance criterion, with the arithmetic in the `what`
  string (`"food carries over + capital 2 + farm 1"`).
- **Deterministic**: use `make_engine`'s seed (default 1). To reproduce a bug from the UI, use
  that game's seed.
- **Test through the public API** (`play_card`, `end_turn`, `play_error`, `score`, zones,
  signals). Setting state directly (`e.resources.food = 1`) is fine for setup.
- **Balance** is not tested, and not checked per change: it's a separate step (a balance item, or when the user
  asks), using `scripts/sim.sh` / the `balance` skill.
- **Helper names** must not start with `test_`: the runner calls every `test_*` method with no arguments.
- **Real data** is only checked by `test_real_data_loads` and `tests/test_content.gd` (invariants and a
  smoke test). Don't assert exact numbers from `data/` (slots, costs, deck sizes): a balance edit must not
  break a test. Warnings in the real data are checked once, in `test_real_data_loads_without_warnings`.
- **Signals**: connect a lambda that appends to an array, then assert on the array
  (see `test_game_ends_at_turn_limit`).
- **Loader errors**: assert the message names the file, card and field, since that is the
  user-facing contract. Put the cases for one config block or card field in one table test,
  `test_<area>_validation`, with `check_cases([[label, input, fragment, kind?], ...], load)`: adding a rule is
  a row, and a failing row names its label. Valid input that loads and normalizes stays a named test.
