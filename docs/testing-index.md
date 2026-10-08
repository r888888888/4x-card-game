# Test file index

One row per test file the runner runs (`tests/test_*.gd` and `tests/balance/test_*.gd`), sorted by path. Each file's
`##` header is the source of what it covers; a row is one short phrase of it, at most 160 characters. "UI" marks files
that run the real `main.tscn`. The suite checks this file lists every test file and no missing one (331, 391). How to
run and write tests: [testing.md](testing.md).

| File | Covers |
|---|---|
| `tests/balance/test_parallel_sim.gd` | Balance suite: the sim on several processes (152, 291, 318) |
| `tests/balance/test_sim_anarchy_report.gd` | Balance suite: the Anarchy, government and famine metrics (158) |
| `tests/balance/test_sim_cache_runs.gd` | Balance suite: the sim's result cache (292) |
| `tests/balance/test_sim_compare_runs.gd` | Balance suite: comparing two checkouts game by game (293) |
| `tests/balance/test_sim_reports.gd` | Balance suite: the sim's report (042, 134, 135) |
| `tests/test_abandon_buildings.gd` | Abandoning finished buildings and their upgrades (412); the details' Abandon… (UI) |
| `tests/test_action_errors.gd` | `discard_error`, `choose_error`, and the main scene showing them (093) |
| `tests/test_actions.gd` | Actions per turn (127) |
| `tests/test_admin_unrest.gd` | Admin unrest (319) |
| `tests/test_anarchy.gd` | Anarchy (145) |
| `tests/test_anarchy_event.gd` | Anarchy as an event (253) |
| `tests/test_anarchy_length.gd` | Anarchy's length: a fixed `anarchy_turns` (155, 384) |
| `tests/test_blocking.gd` | Every action refused while a decision is owed or the game is over (171, 172) |
| `tests/test_board_faces.gd` | Board card faces (138; UI) on a `board_engine` game |
| `tests/test_board_labels.gd` | The board's game words (UI) |
| `tests/test_board_layout.gd` | The board without a sidebar (115; UI) |
| `tests/test_board_row.gd` | One board row (137; UI) |
| `tests/test_build_ceremony.gd` | The build ceremony (357; UI) |
| `tests/test_build_menu.gd` | The build menu (295) |
| `tests/test_build_modal.gd` | Building from a territory's view (297; UI) |
| `tests/test_building_tiers.gd` | Buildings that need a settlement tier (301) |
| `tests/test_building_upkeep.gd` | Buildings' wealth upkeep, its shortfall unrest, forecast, loader and text (405) |
| `tests/test_built_signal.gd` | The engine's `built` signal (357) |
| `tests/test_button_widths.gd` | Button widths (100; UI) |
| `tests/test_cabinet_doors.gd` | The government choice behind cabinet doors (209; UI) |
| `tests/test_card_art.gd` | Art plates on hand-size faces: picture or placeholder motif, shade (381) |
| `tests/test_card_details.gd` | `def_details` / `card_details`: rules, live state and terms (056, 289) |
| `tests/test_card_faces.gd` | Index-card faces and card motion (179); the ledger and fine print (382) |
| `tests/test_card_landing.gd` | How a card lands (117) |
| `tests/test_card_overflow.gd` | Overflowing hand-card text: whole rules, the sheet's rise, the meter and rules popover (383; UI) |
| `tests/test_card_slots.gd` | Card slots (UI) start at their card's resting height (075) |
| `tests/test_card_text.gd` | Card text generated from effects: the face (ledger, rules, fine print; 382) and the long form |
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
| `tests/test_engine_structure.gd` | GameEngine's split (249, 281); no forwards to an area (394) |
| `tests/test_era_sheet.gd` | The era ceremony (211; UI) |
| `tests/test_eurekas.gd` | Eurekas (141) |
| `tests/test_event_eras.gd` | Event decks by era (074) |
| `tests/test_event_modal.gd` | `event_drawn`, `outcome_summary`, and the drawn-event modal (079; UI) |
| `tests/test_event_panel.gd` | The active events (in the Realm's row since 137; UI) |
| `tests/test_event_sounds.gd` | Event sounds (191; UI) |
| `tests/test_events.gd` | The event deck (039, 237) |
| `tests/test_events_at_turn_start.gd` | When the turn's event is drawn (237) |
| `tests/test_explore.gd` | The `explore` op |
| `tests/test_fallen_back_pass.gd` | The fallen-back cards in one pass; score and housing match the per-card rule (408) |
| `tests/test_famine.gd` | The Famine (083) |
| `tests/test_famine_guard.gd` | Building `housing` and `famine_guard` (060) |
| `tests/test_famine_relief.gd` | Relieving a Famine (084) |
| `tests/test_focus_ring.gd` | The focus ring waits for Tab (230) |
| `tests/test_food_upkeep.gd` | Pop eating food at upkeep, and a first shortfall's one death |
| `tests/test_forecast.gd` | `upkeep_forecast` |
| `tests/test_gain_actions.gd` | The `gain_actions` op (128) |
| `tests/test_gain_per_keyword.gd` | The `gain_per_keyword` op (081) |
| `tests/test_gain_per_pop.gd` | The `gain_per_pop` op (304) |
| `tests/test_gain_per_tag.gd` | The `gain_per_tag` op's `per`, and played (367); its `"where": "here"` count (414) |
| `tests/test_game_state.gd` | `GameState.copy` and `GameEngine.fork` |
| `tests/test_generic_bot.gd` | The generic bot (313) on fixtures; expansion (321); renewal (373, 385); deck (376) |
| `tests/test_generic_bot_cache.gd` | The bot's forecast cache (315) |
| `tests/test_generic_raids.gd` | The generic bot meets raids (314, superseding 168) through `turn_forecast` |
| `tests/test_generic_rollouts.gd` | The generic bot's rollouts (314, porting 159) |
| `tests/test_government.gd` | Government cards (065) |
| `tests/test_government_deck.gd` | The government deck (154) |
| `tests/test_grow_meter.gd` | The territory view's pop meter (124; UI) |
| `tests/test_growth_cards.gd` | The `grow` op (013, 261, 262) |
| `tests/test_hand_limit.gd` | `hand_size`, `hand_limit`, `discard_needed` / `discard_card`, free discards |
| `tests/test_hand_size.gd` | Hand size as a modifier (109) |
| `tests/test_harmful_ops.gd` | The `lose` and `lose_pop` ops (072) |
| `tests/test_honeymoon.gd` | A new government's honeymoon (399) |
| `tests/test_housing_modifier.gd` | The `housing` modifier key (110) |
| `tests/test_hover_sound.gd` | Hover sound (245; UI) |
| `tests/test_identity_cards.gd` | The civilization modal as two cards (231) |
| `tests/test_identity_lines.gd` | The civilization and government (088, 115, 119; UI) |
| `tests/test_insight.gd` | Insight (139) |
| `tests/test_insight_per_gain.gd` | The `insight_per_gain` modifier (157) |
| `tests/test_key_sounds.gd` | Key sounds (187; UI) |
| `tests/test_keywords.gd` | Territory keywords, `requires` and keyword effects (005) |
| `tests/test_knowledge_screen.gd` | The Knowledge screen (208; the tech tree before it, 059, 140; UI) |
| `tests/test_launch_options.gd` | Command-line options (135) |
| `tests/test_legal_actions.gd` | `legal_actions` (312) |
| `tests/test_legend_key.gd` | The toggle key (182; the window bar since 219; UI) |
| `tests/test_log_drawer.gd` | The log drawer (115; UI) |
| `tests/test_look.gd` | The `look` op (371) |
| `tests/test_lose_pct.gd` | The `lose_pct` op (268) |
| `tests/test_lose_per_keyword.gd` | The `lose_per_keyword` op (268) |
| `tests/test_menu.gd` | The menu (UI) |
| `tests/test_milestones.gd` | Milestones (191) |
| `tests/test_military_area.gd` | The engine's military area: its methods, no state, a fork's own (394) |
| `tests/test_modal_sheets.gd` | Modals as drafting sheets (207; UI) |
| `tests/test_modal_stack.gd` | The modal stack (153; UI) |
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
| `tests/test_recall.gd` | `recall`, the take decision (370) |
| `tests/test_recruit.gd` | Recruiting units from the build menu (296) |
| `tests/test_rename_modal.gd` | Names on screen and the naming modal (248) (seed 5, Egypt; UI) |
| `tests/test_renewal.gd` | Renewal, a free action during Anarchy (147, 385) |
| `tests/test_renewal_modal.gd` | The Renew button and the Renewal modal (255, 385) |
| `tests/test_research.gd` | Techs: the research deck, learning, prerequisites (025, 139, 140) |
| `tests/test_resource_glyphs.gd` | Resource glyphs (180; UI) |
| `tests/test_resource_tokens.gd` | Counter changes (114, 126, 181, 218; UI) |
| `tests/test_revolt_modal.gd` | Revolt from the civilization modal (205; UI) |
| `tests/test_revolution.gd` | Revolution (148, 155) |
| `tests/test_rules.gd` | `GameEngine` rules: setup, playing cards, the turn loop, scoring, game end |
| `tests/test_scaffolding.gd` | No red-phase scaffolding left (333; `tests/lib/scaffolding_checks.gd`) |
| `tests/test_score_breakdown.gd` | Score and pop breakdowns by source, and their popover (380; UI) |
| `tests/test_screen_header.gd` | The screens' `ScreenHeader` and transitions (104, 118; UI) |
| `tests/test_script_size.gd` | Script size limits (`tests/lib/script_sizes.gd`) |
| `tests/test_sea_slots.gd` | Sea slots (366) |
| `tests/test_select_list.gd` | The selectable list (217) |
| `tests/test_settings.gd` | `SettingsStore`: saving and loading the player's settings (183) |
| `tests/test_settings_modal.gd` | The Settings modal (206; UI) |
| `tests/test_settle.gd` | The `settle` op (loading and play) and card targets |
| `tests/test_sfx.gd` | The sound player (186) |
| `tests/test_shared_helpers.gd` | Shared test helpers (UI, 334; `check_loads`, 340), not copied |
| `tests/test_sheet_sounds.gd` | Sheet, screen and notice sounds (189; UI) |
| `tests/test_sidebar.gd` | The right sidebar (202; UI) |
| `tests/test_sim.gd` | The simulator on fixtures |
| `tests/test_sim_anarchy.gd` | Sim metrics for Anarchy, governments and famine (158) |
| `tests/test_sim_cache.gd` | The sim cache's code hash (292) |
| `tests/test_sim_compare.gd` | Comparing two checkouts (293) |
| `tests/test_sim_levels.gd` | `sim.sh --level` (378) |
| `tests/test_sim_procs.gd` | How many processes a sim run uses (291) |
| `tests/test_sim_stall.gd` | A parallel run's stalled or dead worker (318) |
| `tests/test_sim_strategies.gd` | `SimStats` per strategy and civilization (134) |
| `tests/test_size_unrest.gd` | Size unrest (282) |
| `tests/test_slots.gd` | Building slots |
| `tests/test_smooth_scroll.gd` | `SmoothScroll` and the scrollbar (356; UI) |
| `tests/test_sound_rows.gd` | The sound rows (185; UI) |
| `tests/test_sound_settings.gd` | Sound settings and the audio buses (184) |
| `tests/test_spacing_tokens.gd` | Spacing and radius tokens (193) |
| `tests/test_start_screen.gd` | The title, new game and settings screens (063, 099; UI) |
| `tests/test_state_copy.gd` | `GameState` and `CardInstance` copies: everything, nothing shared (171) |
| `tests/test_sunrise_art.gd` | The title screen's art (214) |
| `tests/test_supply.gd` | The card supply (032, 057) |
| `tests/test_supply_screen.gd` | The Supply screen's pile cards (232; UI) |
| `tests/test_surfaces.gd` | Wood grain, paper and soft shadows (341; UI) |
| `tests/test_tech_eras.gd` | Eras: `era`, the `add_era` and `research` ops, `future_techs` (027) |
| `tests/test_tech_event_flavor.gd` | Tech/event/action/building `flavor`, tech and building `quote` (215, 352, 396) |
| `tests/test_tech_gives_modal.gd` | A tech's details' Gives row (289; UI) |
| `tests/test_tech_tree.gd` | `tech_tree()` (states, costs, `gives`, `affordable`), `era_name(s)` |
| `tests/test_terrains.gd` | Terrain keywords (130) |
| `tests/test_territories.gd` | Territory cards, their config and setup |
| `tests/test_territory_cards.gd` | Territories as plain cards in the Realm (102) |
| `tests/test_territory_names.gd` | Territory names (248) |
| `tests/test_territory_resources.gd` | Rolled resource keywords |
| `tests/test_territory_view.gd` | The territory view (101; UI) |
| `tests/test_test_runner.gd` | The runner itself (223) |
| `tests/test_theme.gd` | The UI theme (106); its sections in `ui/theme/` (393) |
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
| `tests/test_ui_smoke.gd` | `main.tscn` follows a game played by `play_first_legal` (314) |
| `tests/test_ui_structure.gd` | `ui/`: one script per component, no engine internals, no test hooks on main (052, 175, 176, 316, 392) |
| `tests/test_unit_moves.gd` | Moving and disbanding units (163) |
| `tests/test_unit_upgrades.gd` | Unit upgrades (166) |
| `tests/test_units.gd` | Unit cards (160) |
| `tests/test_unrest.gd` | Unrest (144) |
| `tests/test_upgrade_ribbons.gd` | Upgrades on screen (302; UI); the details' Upgrades section (387); the upgrade badge (410) |
| `tests/test_upgrades.gd` | Building upgrades (300); `upgrade_rows` (387) |
| `tests/test_upkeep_breakdown.gd` | Upkeep and unrest-limit breakdowns by source, and the counters' popover (379; UI) |
| `tests/test_vellum.gd` | Targeting under vellum (210; UI) |
| `tests/test_veterans.gd` | Veteran units (165) |
| `tests/test_veteran_pips.gd` | Veteran pips on unit cards, lit as a tally after a raid (388; UI) |
| `tests/test_wealth.gd` | Wealth, the second resource |
| `tests/test_wonder_sites.gd` | Wonders built over turns (286) |
| `tests/test_workers.gd` | Workers |
| `tests/test_would_target.gd` | `would_need_target` / `would_target` (310) |
