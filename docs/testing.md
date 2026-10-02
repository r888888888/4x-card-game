# Testing

Dependency-free runner: no addon, just Godot headless.

## Running

```bash
scripts/test.sh              # everything but tests/balance/
scripts/test.sh rules        # files/tests whose "file::method" contains "rules"
scripts/test.sh test_create  # a single test (or group) by name
scripts/test.sh --balance    # only tests/balance/ (filter as above)
```

**The balance suite** (`tests/balance/`): tests that play ScriptedBot games on the real data (`data/*.json`): the
sim's report, its options and the parallel run. They grow with every bot change, so the main suite and the Stop hook
leave them out; run `scripts/test.sh --balance` when touching `sim/`. Bot rules and `SimStats` stay in the main suite,
tested on fixture games of a few turns.

The script re-imports the project first when a `.gd` file changed, so a new `class_name` resolves
in the same run. Output is quiet: one `FAIL` line per problem, then `N tests, M failures`.
Exit code 0 means green.

A test fails when:
- an assertion fails (`eq`, `check`, `has_msg`);
- it makes no assertions (empty, or crashed before the first one);
- any engine or script error is logged while it runs (null access, missing method, `push_error`), unless the test
  expected it with `expect_error(fragment)` (then the test fails if no such error is logged);

and the whole run fails if a test file doesn't parse or the filter matches nothing.

## Writing tests

Put tests in `tests/test_<area>.gd`. Current areas:

| File | Covers |
|---|---|
| `tests/test_content.gd` | The real data: invariants over the whole data set, never a single card (every keyword used, every cost has a source, every building's requires met in play, eras reachable with 2+ techs, techs and supply consistent). No many-seed bot sweeps: real games over seeds are sim runs (`scripts/sim.sh`), not tests (145) |
| `tests/test_ui_smoke.gd` | The real `main.tscn` follows a whole `ScriptedBot` game: no script errors, hand views match the hand, game-over text; uses main's test hooks (`start_game`, `hand_view_count`, `game_over_text`) |
| `tests/test_event_modal.gd` | `event_drawn`, `outcome_summary`, and the drawn-event modal in the real `main.tscn` (079): what it shows, closing it, hand-limit and last-turn order |
| `tests/test_event_panel.gd` | The active events in the real `main.tscn` (in the Realm's row since 137): event views match `active_events`, turns left, none without an event deck; runs main on fixture data with `with_event_engine` and the `event_panel()` hook |
| `tests/test_board_row.gd` | One board row (137) in the real `main.tscn` on a TEST_CARDS + TEST_EVENTS game (`with_main`, `board_engine`): events, then frontier, then the Realm in `main.tableau.row`; only Realm and Hand headings; no view for a known tech; a settled frontier card keeps its view and moves into the Realm; drops on frontier cards; the frontier and event explanations in their cards' tooltips; Relieve (`relieve_button()`) during a Famine |
| `tests/test_board_faces.gd` | Board card faces (138) in the real `main.tscn` on a `board_engine` game: every card in the Realm's row at `CardView.BOARD_SIZE`; the frontier face (badge, name, keywords, "▢N ⌂N"), the event face (badge, turns left or a Famine's counters, name, first rules line, no "Lasts"), settling switches to the settled face, the details name clipped keywords, hand cards unchanged; read with `face_text()` |
| `tests/test_ui_structure.gd` | The shape of `ui/`: one script per component (and `CardView`'s content and motion in `CardFace` and `CardMotion`), no engine internals (`state`, the RNG, the log lines; 175: the config) read in `ui/`; 175: one `ActionButton`, `main.gd` asks `hand_input_error()`; 176: `BoardViews` and `BoardLayout`, `main.gd` within 500 lines, `zone_of` in the UI; 183: no `const` holds a Palette colour |
| `tests/test_board_labels.gd` | The board's game words in the real `main.tscn`: no "tableau" on screen, no seed in the top bar, Buy Cards, Knowledge; uses the `section_headings()` hook |
| `tests/test_card_slots.gd` | Card slots in the real `main.tscn` start at the height their card rests at (frontier cards while still flying, at `BOARD_SIZE`; hand slots) |
| `tests/test_start_screen.gd` | The title, new game and settings screens in the real `main.tscn` (063, 099): the title screen on launch with no game started and three buttons, New game → Start with a seed or a random one, Settings with the shared Reduce motion setting (saved to a temp file), Back and Esc to the title, Exit, the menu's New game to the new game screen, Restart and Replay skipping the screens, keyboard focus and wrapping; the civilization cards (064: listed, preselected, selecting saves, Restart keeps, named in the menu and at game over); uses `main.start_screen`, `main.new_game_screen`, `main.settings_screen` and `main.board_shown()` |
| `tests/test_title_screen.gd` | The title screen as a ledger (213) in the real `main.tscn` at 1920×1080: the ledger left (kicker, the title on two lines, subtitle, three `BigButton`s flush left in one width) and an empty `Art` half right behind a 1 px rule; a `BigButton`'s caps label, caption, › and lamp edge; the `BigButton` / `BigButtonPrimary` / `BigLabel` variations (plinth, pressed travel); its key sounds; Day mode |
| `tests/test_legend_key.gd` | The Reduce motion legend key (182) in the real `main.tscn`: ON with a lit lamp / OFF with a dark one (also after `set_pressed_no_signal`), the theme's key boxes with room for the lamp, a "Reduce motion" row on the settings screen and in the menu (`main.menu_motion_toggle()`) that sets, saves and mirrors the setting, the row at the menu column's width, Tab and Space |
| `tests/test_sound_rows.gd` | The sound rows (185) in the real `main.tscn`: the settings screen's Interface sounds key and Master, Game and Interface sliders under Day mode (`settings_screen.sound_toggle`, `sliders`, `figures` by bus), showing and setting the settings (Right on a slider), the menu's key (`main.menu_sound_toggle()`) at the column's width and mirroring, the focus loops and the sliders' tooltips; a temp settings file |
| `tests/test_button_widths.gd` | Button widths in the real `main.tscn` at 1920×1080 (100): buttons fit their text; the title, settings, new game, menu and game-over buttons share one width in a centred column; tech tiles and seed fields still fill (the top bar: `test_board_layout`) |
| `tests/test_territory_view.gd` | The territory view in the real `main.tscn` (101) on a TEST_CARDS game: a click on a territory opens it in place of the Realm (a city's click still shows details), stats and Grow, Back / Esc / new game / game over close it, drops and double-clicks play onto it, targeting wins over opening, ↑/↓ and Enter from the hand; uses `main.territory_view` (`is_open`, `uid`, `card_uids`, `stats_text`, `target_at`, `back_button`, `grow_button`); 105: the territory as the framed box (its name and info as the title, stats and Grow above the cards, its card left in the Realm), free-slot outlines after the cards, no pop-in or fly-off when opening or closing (`frame`, `title_text()`, `outlines()`, `free_slot_count()`) |
| `tests/test_grow_meter.gd` | The territory view's pop meter (124) in the real `main.tscn` on a TEST_CARDS game: a pip per housing with pop filled (`PipFilled`), Grow (`grow_button`) on the first empty pip with its cost and the food icon, `grow_reason` showing `grow_error`, and a grow from the meter popping the pip in, its "+1" and "−3" tags beside the top bar's Pop and Food (126, 181; Reduce motion too); `main.territory_view.pips()`; tweens stepped by hand |
| `tests/test_day_mode.gd` | Day mode (183) in the real `main.tscn`: the palette's Day and Night values and the guide's contrast in both, a game at turn 3 switched to Day and back (theme, background, card panels and bands, glyphs, figures, log) with the game untouched, open modals and screens switching and staying open, the Day mode keys under Reduce motion (mirrored, in the focus loops); a temp settings file, back on the player's palette after |
| `tests/test_sfx.gd` | The sound player (186): every token of the guide's §14.1 tables is an `Sfx` constant with its level (read from the guide), its files under `assets/sounds/` (16-bit, 48 kHz, mono, uncompressed), the streams (Level 1 randomized), `play()` and `played()`, the tick, notification, voice and Level 3 rules, `Anim.contact`, `Sfx.lead` and `at_contact`; the clock set by hand |
| `tests/test_key_sounds.gd` | Key sounds (187) in the real `main.tscn` at 1920×1080 (`main.sfx`'s clock frozen; mouse presses pushed at a button's centre): every button's press and release at their contacts (mouse, Space, Enter, a modal's), hover and focus silent, a press dragged off, a disabled key's dead tap and `main.locked_tip()`, End turn's press, relay and drum (and a plain release when a discard is owed; a dead tap while disabled), the legend key's latch sounds, interface sounds off still heard (`Settings.set_interface_sounds(off, mute_after)`), Reduce motion |
| `tests/test_counter_and_card_sounds.gd` | Counter and card sounds (188) in the real `main.tscn`, `main.sfx`'s clock frozen: an `Odometer`'s ticks (each a dB quieter) and its gain or loss, a long roll ticking only its shown steps, the top bar's counters rolling one after another (one tick stream, gains in order), silent new games, no-op refreshes and the Supply screen's close, Reduce motion's lone registration; a card's lift, a played building's pat (onto its territory's card, or in the open territory view), a refusal's double tap, click-to-target's tick |
| `tests/test_sheet_sounds.gd` | Sheet, screen and notice sounds (189) in the real `main.tscn`, `main.sfx`'s clock frozen: `ModalStack` lays a sheet down (stacked 1 dB quieter, 3 dB under a notice's bell in the same frame) and lifts it once (also for `close_all`), `Navigator` runs screens in and back (root and clear silent), `Toasts` rings each notice 0.4 s apart (hints silent), the player's key or click makes it their input (`Sfx.player_acted()`), Reduce motion |
| `tests/test_notice_priorities.gd` | Notice priorities (190): the three `GameEngine.NOTICE_*`; in the real `main.tscn` each priority's bell pattern at one volume, its hue bar (`Toasts.priorities()`, `bar_role()`), the engine's `noticed` reaching the toast with its priority, an urgent toast staying twice as long. Each notice's priority is checked beside its scenario: `check_noticed(recorded, fragment, priority)` |
| `tests/test_era_sheet.gd` | The era ceremony (211) in the real `main.tscn` on a TEST_CARDS + TEST_EVENTS game whose eras unlock at 50 wealth: `main.era_sheet` covers the window with "A NEW ERA", the era's name at display XL and the turn; the wipe, three rings and the letter-by-letter name (a fade with Reduce motion); a click or key skips, the next closes; one sheet for two eras; none at setup; the turn's event waits for it |
| `tests/test_milestones.gd` | Milestones (191): `milestone(kind)` for a tech learned, a territory settled, each era added (once), before `changed`; none for a failed buy or during a new game's setup (era_unlocks at turn 1) |
| `tests/test_event_sounds.gd` | Event sounds (191) in the real `main.tscn`: the breakthrough, city and era sounds on the Game bus (only the era when a tech adds one), the game-over sheet's victory once, the action's notices and counters giving way, a press still clicking, the Game bus ignoring the Interface sounds key but not the Game volume |
| `tests/test_sound_settings.gd` | Sound settings and the audio buses (184): the `[sound]` section's defaults, round trip and bad values; `Settings.set_volume` / `volume` / `set_interface_sounds`; the bus layout (Game and Interface into Master, limiters, the Interface filters); bus volumes and mutes following the settings, Interface sounds off, and the window in the background; temp settings files |
| `tests/test_palette_roles.gd` | Palette roles (192): `UIKit.stat` takes a role name and follows a Day mode switch, every all-caps StringName in `ui/` is a Palette role, `NIGHT` and `DAY` name exactly Palette's colours |
| `tests/test_spacing_tokens.gd` | Spacing and radius tokens (193): `Tokens` holds the guide's space and radius scales; on the board and every screen and modal (`each_screen`), container spacings and resting styleboxes' radii and content margins are on the scales; zones, hints and slot outlines are square; no spacing or radius literal in `ui/` |
| `tests/test_type_tokens.gd` | Text sizes (194): `Tokens.TYPE_*` hold the guide's type scale; the theme's Display, Title, Heading (capitals, tracked), Body, BodySmall, Caption, Stat and RichBody variations; every text size on every screen (`each_screen`) and card face is on the scale; no literal size in `ui/` |
| `tests/test_theme.gd` | The UI theme (106): the look recorded through the real `main.tscn` (labels, panels, buttons in every state, the field, the focus ring, card type colours; a guard, last set on purpose by 178: the Night shift palette, the guide's typefaces with tabular figures, buttons on a hard shadow that sink when pressed, the accent only on End turn, square panels), no colour literals in `ui/` outside `palette.gd`, the palette's names, `GameTheme.build()`'s controls and variations, UIKit labels and overlay panels using them |
| `tests/test_navigator.gd` | `Navigator` (103) on plain Controls: push hides the screen below, back and Esc return to it (never past the root), focus given and given back, `set_root` / `clear`, one `changed` per step; the title, new game and settings screens on `main.nav`; 104: titles, `ScreenHeader`, and an animated navigator's transitions (grow from a rect, fade, Reduce motion, back reverses with the screen below live at once, a new step finishes the running one) |
| `tests/test_screen_header.gd` | The header on the new game and settings screens and the territory view in the real `main.tscn` (104; 118: the parent title is the only button, a link back), and a territory's view growing out of its card and shrinking back; uses `with_reduce_motion` and `wait_screen_transition` |
| `tests/test_resource_tokens.gd` | Counter changes in the real `main.tscn` (114, 126; tags since 181): every change to Food, Wealth, Score or Pop rolls that counter's odometer and shows one net "+N" / "−N" tag right of its figure for `Anim.TAG_HOLD`, whatever caused it (cards, grow, upkeep, a Famine), staggered left to right, in place and longer with Reduce motion; none for a new game, a no-op refresh or behind the Supply screen, whose own wealth rolls and tags; nothing floats (`assert_net_tags`, `counter_tag` in test_case.gd); steps tweens by hand |
| `tests/test_odometer.gd` | `Odometer` (181) in the real `main.tscn`: rolling up and down one value per `Anim.ODOMETER_STEP`, only the last `Anim.ODOMETER_MAX_STEPS` of a long change, a change mid-roll carrying on, Reduce motion jumping; tweens stepped by hand |
| `tests/test_counters.gd` | The top bar's and the Supply screen's counters by name (177): `main.counter(key)` / `counter_text(key)` for each resource, `TopBar.SCORE`, `POP` and `TURN`, hidden when off, `main.supply.counter`; UI tests find counters this way, never by their text (`test_ui_structure` guards it) |
| `tests/test_cabinet_doors.gd` | The government choice behind cabinet doors (209) in the real `main.tscn` on an `anarchy_case` game: the doors (`main.doors`: `left`, `right`, `moving()`) close, hold and part on the choice with `CABINET_CLOSE` / `CABINET_PART` at those moments, block keys and clicks while moving, close and part again after a choice, only a fade with Reduce motion, once per choice |
| `tests/test_sidebar.gd` | The right sidebar (202) in the real `main.tscn`: the civilization's name and government link (`main.sidebar`: `heading`, `name_button`, `government_button`), at the right edge under the top strip with the Realm and hand to its left (1280×720, 1920×1080), opening the civilization modal (click, Enter), following Anarchy, no top-bar button, in the focus order after the strip, hidden on the start screens |
| `tests/test_revolt_modal.gd` | Revolt from the civilization modal (205) in the real `main.tscn` on the real data (seed 5, Sumer): `identity_modal.revolt_button` ("Revolt…", disabled with `revolt_error`), the confirmation `main.revolt_modal` (title, context, the Anarchy flavor and quote, `revolt_summary()`, Keep / Revolt), revolting once, Keep / Esc / a click outside changing nothing; no Revolt on the board |
| `tests/test_board_layout.gd` | The board without a sidebar in the real `main.tscn` at 1920×1080 (115): no `SidePanel` or `TurnBox`, the Realm and the hand reach the right edge, the top bar's order and fit, End turn in the top bar between Log and Menu (E, the discard text, disabled with its reason; 120), keys in the tooltips, the bar fitting with its longest texts |
| `tests/test_log_drawer.gd` | The log drawer in the real `main.tscn` (115): closed at the start, L / the Log button open it sliding in from the right (fading with Reduce motion), L / Esc / the button / a click outside close it, lines append while closed, a new game clears it; the deck and discard counts in it, cards dealt from the Log button and its pulse (121); uses `main.log_drawer` (`is_open()`, `text()`) |
| `tests/test_toasts.gd` | Toasts and the unread marker in the real `main.tscn` (116): a notice's toast under the top bar for `Anim.TOAST_TIME`, at most 3 newest on top, fading in place with Reduce motion, the targeting hint until targeting ends, refusals not toasted, "Log •" for unseen lines, toasts ignoring mouse and focus and hiding under the menu and tech tree; uses `main.toasts` (`shown()`, `texts()`). Engine notices are tested beside each scenario with `record_messages` / `check_noticed` (test_case.gd) |
| `tests/test_resource_glyphs.gd` | Resource glyphs (180) in the real `main.tscn`: each top-bar counter's glyph (`assets/icons/`) in its hue at its left, figures in ink (food `WARN` when pop would starve), glyphs hiding with their counters, figures without words; a hand card's cost at the right of its name as glyph + figure entries, in food, wealth, insight order, red where `play_shortfall` names the resource; the Grow pip's sprout |
| `tests/test_card_faces.gd` | Index-card faces and card motion (179): every card a `RAISED` sheet in a `CONTROL_BORDER` rule, the type as a `Band` under the name (none on a frontier card), hover / drag / warning / target borders, a hard shadow only when lifted, a hover lift of 8 px with no growth, at most 3° of tilt, no squash; CardViews in a plain Control tree |
| `tests/test_card_landing.gd` | How a card lands (117): a dealt card settles with no squash but still flies and fades in; since 179 no flight squashes; a rejected card still shakes. CardViews in a plain Control tree, stepped by frames |
| `tests/test_menu.gd` | The menu in the real `main.tscn`: Exit is last, pressing it or Enter on it calls `quit_hook` once, Tab wraps through it, no Exit at game over; uses the `menu_buttons()` / `game_over_buttons()` hooks |
| `tests/test_script_size.gd` | Script size limits (`tests/lib/script_sizes.gd`): no script in `engine/` or `ui/` over 700 lines; each one over 500 prints a `WARN` line in `scripts/test.sh` output |
| `tests/test_engine_scaling.gd` | How engine queries scale with the tableau (150): which buildings work (interleaved territories, population off) and `modifier()` linear in the tableau, a met eureka check not growing with it; ratios of `best_time_usec` timings (test_case.gd), never absolute times |
| `tests/test_sim.gd` | The simulator on fixtures: `ScriptedBot` policy, `SimStats.run` metrics, `run_files`' loader errors |
| `tests/test_sim_anarchy.gd` | Sim metrics for Anarchy, governments and famine (158): the metric names, fixture games with known counts, the `revolted` / `order_restored` signals (the real-data parallel run: `tests/balance/test_sim_anarchy_report.gd`) |
| `tests/balance/test_sim_reports.gd` | Balance suite: `SimStats.run_files` on the real data (what `scripts/sim.sh` prints: a line per metric, every strategy and civilization, `--civ` / `--turns`) |
| `tests/balance/test_parallel_sim.gd` | Balance suite: The sim on several processes (152): `run_files`' `procs` gives the same report on 1, 2 and 4 processes (all strategies, or one), never more processes than games, in-process by default; `play_shard` / `read_shards` naming a shard with no results; no results directory left behind |
| `tests/test_launch_options.gd` | Command-line options (135): `LaunchOptions` parse, apply, starts_game (the sim's options on real data: `tests/balance/`) |
| `tests/test_sim_strategies.gd` | Sim strategies (134): each strategy's card order, buying and safe growth (`ScriptedBot.take_turn`), `SimStats` per strategy and civilization |
| `tests/test_card_details.gd` | `def_details` / `card_details`: rules, live state (pop, slots, idle, tech price now), terms and generated keyword terms |
| `tests/test_modal_sheets.gd` | Modals as drafting sheets (207) in the real `main.tscn` at 1920×1080: each modal's sheet (RAISED, 2 px TEXT rule, 8,8 hard shadow), title block (4 px bar, title, context caps), body at most 640 px, footer under a 1 px rule (primary rightmost); the menu and game over on `main.modals` (game over stays); the rise, the stacked +8,+8, the drop, Reduce motion fades; hooks `sheet_offset()`, `sheet_alpha()`, `scrim_alpha()` |
| `tests/test_modal_stack.gd` | The modal stack in the real `main.tscn` (153) on a seed-1 game with the tech tree and a tech's details over it: Esc, a click outside and the close keys close only the top modal, keys reach only the top, closing or reopening the tree closes the details above, the cascade, each modal on `main.modals`, a new game or the title screen closing them all; uses `main.modals` (`depth()`, `top()`) and a modal's `panel` |
| `tests/test_details_modal.gd` | The details modal in the real `main.tscn`: I opens it for the focused card, Esc closes it, board keys blocked, supply piles; uses `main.details.shown()` |
| `tests/test_tech_tree.gd` | `tech_tree()` (states, cost now, `gives`) and `era_name` / config `era_names` |
| `tests/test_tech_tree_modal.gd` | The Knowledge modal in the real `main.tscn`: T and the Knowledge button open it, one column per era by name, T/Esc close; uses `main.tech_tree.shown()` |
| `tests/test_card_text.gd` | Card text: short `rules_text` (⟳, merged keyword bonuses) and full `rules_tooltip` |
| `tests/test_data_loader.gd` | JSON parsing, validation errors and warnings |
| `tests/test_action_errors.gd` | `discard_error`, `choose_error`, and the main scene showing their reasons (093) |
| `tests/test_changed.gd` | The `changed` signal: once per successful action, none when refused |
| `tests/test_ui_queries.gd` | Engine queries the UI relies on: `playable_error`, `end_turn_error`, `supply_error`, `upcoming_era_unlocks`, `territory_groups`, `territory_summary`, `needs_target_choice`, `tech_eras`, `open_supply_piles` (094); `hand_limit`, `research_on` (175); `zone_of` (176); `play_shortfall` (180) |
| `tests/test_pending.gd` | `pending()` for each decision kind (explore, discard, renewal, government) and the one blocking rule every action follows; 172: one `GameState.pending`, `pending()` a copy |
| `tests/test_state_copy.gd` | Guards (171): `GameState.copy()` and `CardInstance.copy()` carry every script variable (read from the property list) and share nothing that can change |
| `tests/test_blocking.gd` | Guards (171): while each decision is owed (explore, discard, renewal, government) and after game over, every other action refuses with a reason and changes nothing; the table of actions is checked against `GameEngine`'s methods with an error query; 172: each decision action's message order, every action under `# --- Actions ---` beside its query |
| `tests/test_game_state.gd` | `GameState.copy` and `GameEngine.fork`: deep copies, independent RNG, pending choice, no signals or log on the original; the forecast not disturbing the next hand |
| `tests/test_rules.gd` | `GameEngine`: setup, actions, turn loop, scoring, game end |
| `tests/test_keywords.gd` | Keywords: building `requires`, keyword-conditioned effects, validation, card text |
| `tests/test_play_outcome.gd` | `GameEngine.card_played`: the outcome reported for each play |
| `tests/test_explore.gd` | The `explore` op: loading, reveal, the explore `pending()`, `choose`, blocking play and end turn |
| `tests/test_settle.gd` | The `settle` op (loading and play) and card targets: `valid_targets`, `needs_target`, target checks, outcome `target` |
| `tests/test_slots.gd` | Building slots: `total_slots`, `free_slots`, city slot bonus, building targets and placement |
| `tests/test_food_upkeep.gd` | Pop eating food at upkeep, and a first shortfall's one death |
| `tests/test_famine.gd` | The Famine (083): arrives, escalates to max_counters, one at a time, ends when fed and leaves the game, blocks growth, guards, forecast, `event_counters`, config |
| `tests/test_famine_relief.gd` | Relieving a Famine (084): `relieve_famine` and its error, the notice, a new Famine after relief, the forecast, `population.famine.relief` validation and price |
| `tests/test_famine_guard.gd` | Building `housing` and `famine_guard` (060): loading, housing cap, saving starving pop, forecast, card text; uses the Silo fixture and `build_on` |
| `tests/test_forecast.gd` | `upkeep_forecast`: next upkeep's net food and wealth, idle buildings, upkeep growth, `starve` |
| `tests/test_gain_per_keyword.gd` | The `gain_per_keyword` op (081): count per settled territory with any keyword (once each, frontier excluded, rolled keywords), `count_territories_with`, upkeep and forecast, loading, card text |
| `tests/test_identity_lines.gd` | The civilization and government in the real `main.tscn` (088, 115, 119): one top-bar button naming both, the modal showing the civilization then the government (flavor, quote, rules; "No bonus."), Esc / Close, above the log drawer, one or neither, a new government, no empty lines; End turn on screen at 1920×1080; uses `identity_button()` and `identity_modal` (`shown()`, `body_text()`, `close_button`) |
| `tests/test_territory_cards.gd` | Territories as plain cards in the Realm (102) on a TEST_CARDS game: one card per territory then cards on no territory (`main.tableau.row`), no city or building card outside the territory view, the live line (123: name, keywords, "▢ F   ⌂ P/H   ⚒ W", Frontier unchanged), drag targets (`drag.target_at`) and targeting, no collapse or Grow in the Realm, a settled territory's card, many cards wrap (078) |
| `tests/test_harmful_ops.gd` | The `lose` and `lose_pop` ops (072): never below 0, the largest territory (ties in tableau order), a drawn event, upkeep and forecast, loading, card text, log |
| `tests/test_trash.gd` | The `trash` op (082): hand targets (never the card played), errors, auto-pick, `trashed` never reshuffled, fork, loading, card text |
| `tests/test_vellum.gd` | Targeting under vellum (210) in the real `main.tscn` on a TEST_CARDS game with a Temple and two territories: `main.vellum` (`covered_rect()`, `lifted()`) wipes in from the left over the Realm and hand with the card and its targets above it (2 px FOCUS outlines), off to the right after a play or a cancel (Esc, right-click, a click on it, a click on a card under it); a fade with Reduce motion; none while dragging |
| `tests/test_trash_targeting.gd` | Trash targeting in the real `main.tscn`: a double-clicked Winnow lights the other hand cards as pickable; picking one trashes it; uses `main.drag` and `main.views` |
| `tests/test_trade.gd` | The `trade` op: loading, the `min_cities` block, √cities + pop payout, card text |
| `tests/test_growth_cards.gd` | The `grow` op: loading, Granary (`here`), Festival (`each`), housing cap |
| `tests/test_growth.gd` | Buying growth: `grow`, `grow_error`, `grow_cost` |
| `tests/test_population.gd` | Population: territory `housing`, the config `population` block, starting and settled pop, pop VP |
| `tests/test_workers.gd` | Workers: `free_workers`, placement needing a worker, idle buildings at upkeep |
| `tests/test_settings.gd` | `SettingsStore`: saving and loading `reduce_motion`, `day_mode` (183) and `civilization`, `Settings.set_day_mode`, `civilization_in` fallback, bad or missing files |
| `tests/test_wealth.gd` | Wealth, the second resource: mixed costs, gaining wealth, carry over, wealth never used as food |
| `tests/test_hand_limit.gd` | Keeping the hand, draw up to `hand_size`, `hand_limit`, `discard_needed` / `discard_card`, voluntary discards |
| `tests/test_hand_size.gd` | Hand size as a modifier (109): the `hand_size` modifier key, past the hand limit a config error, the opening hand and refills, the same deal order |
| `tests/test_events.gd` | The event deck: the `event` type and `discard`, `event_deck` config, one draw per end turn, active events' upkeep and discard, reshuffling |
| `tests/test_event_eras.gd` | Event decks by era (074): an event's `era`, later-era events in `future_events`, shuffled in once when their era is added, the notice, the event tooltip |
| `tests/test_civilization.gd` | Civilization cards (062): the type, the `start` trigger, `starting.civilization`, setup, upkeep, forecast, score, fork, card text; uses `TEST_CIVS` / `civ_engine` |
| `tests/test_civ_flavor.gd` | Civilization `flavor` and `quote` (107): loading and validation, optional, in `def_details` / `card_details` |
| `tests/test_civ_home.gd` | A civilization's `home` territory (111): loading and validation, population start fitting each home, card text, the home settled at new game, the same decks with or without a home, its roll |
| `tests/test_civ_start_building.gd` | A civilization's start building (133): a start `create` into the tableau puts the building on the home, works from turn 1, must be a building fitting the home's keywords and slots |
| `tests/test_discounts.gd` | Civilization `discounts` (108): loading and validation, card text, type and tag discounts on `play_cost` and `tech_cost`, supply discounts on `buy_price`, floors |
| `tests/test_government.gd` | Government cards (065): the type, `starting.government`, `government()`, playing one to replace the ruling one (to `removed`), upkeep, forecast, score, the same-government error, fork; uses `TEST_GOVS` / `gov_engine` |
| `tests/test_government_deck.gd` | The government deck (154): created and fallen governments in `governments`, the government choice owed when Anarchy ends (`PENDING_GOVERNMENT`, `choose_government` and its error), unrest halved, the Government overlay, the identity modal's deck line, the bot's choice; uses `anarchy_case.gd` |
| `tests/test_actions.gd` | Actions per turn (127): the government's `actions`, unlimited without one, each play using one, what needs none, the reset each turn; uses `TEST_GOVS` |
| `tests/test_gain_actions.gd` | The `gain_actions` op (128): loading, the default amount, +N actions this turn, none carried over, nothing with unlimited actions, card text |
| `tests/test_modifiers.gd` | Standing `modifiers` (129): loading and validation, `modifier(key)` over working cards, always-on zones and active events, the `actions` key, card text |
| `tests/test_housing_modifier.gd` | The `housing` modifier key (110): added to every settled territory, never below 1, the growth cap, idle buildings, population start against printed housing, card text |
| `tests/test_choose_civilization.gd` | Choosing a civilization (064): config `civilizations`, `civilizations()`, `new_game(seed, civ_id)`, `new_game_error`, the same seed dealing the same game for any civilization |
| `tests/test_research.gd` | Techs: the `tech` card type and `prereq`, `research_deck` config, learning from the open tree (140: `buy_tech` / `buy_tech_error`, locked techs, the next era), the reveal gone, `research_card_name` |
| `tests/test_diffusion.gd` | Diffusion (142): 1 insight off per later era, none in a tech's own era, stacking with discounts and eurekas, the details |
| `tests/test_eurekas.gd` | Eurekas (141): loading `eureka`, the tableau count (card and tag forms, idle cards), the floor, `tech_tree`'s `eureka`, card text, details and the tree's line |
| `tests/test_unrest.gd` | Unrest (144): the government's `unrest_limit` and the modifier, `unrest_limit()` / `at_unrest_limit()` / `unrest_on()`, gain capped at the limit, unrest can't be paid (cost, discount, relief, trade), the forecast and the top bar's Unrest counter, `ScriptedBot` around the limit |
| `tests/test_anarchy.gd` | Anarchy (145): the config `unrest` block, falling at the limit, what it locks, its upkeep and burning out, era unrest |
| `tests/test_anarchy_length.gd` | Anarchy's length (155): counters by the unrest share of the fallen limit, calming lowers them for good, one off at the end of each Anarchy turn |
| `tests/test_anarchy_drain.gd` | Anarchy's drain (156): config `unrest.drain_pct`, food and wealth lost each Anarchy turn, the forecast |
| `tests/test_leaving_anarchy.gd` | Restoring order (146, 155): the c × (c + 1) price, `restore_order` and its error, the Restore order button, the bot paying |
| `tests/test_renewal.gd` | Renewal (147): what's owed after the draw under Anarchy, `renew` and its error, the block on other actions, the `renewal` modifier, the Renewal overlay, the bot's pick |
| `tests/test_bot_lookahead.gd` | The bot's government lookahead (159): choosing and revolting by forked lookaheads, `ScriptedBot.lookahead`, 154's ranking (`best_government`) |
| `tests/test_revolution.gd` | Revolution (148, 155): revolting at any time, Anarchy next turn, `revolt` and its error, `revolt_forecast`, the Revolt button, the bot's revolt |
| `tests/test_insight_per_gain.gd` | The `insight_per_gain` modifier (157): each insight gain lowered (play, upkeep, per-count ops, trade), modifiers add up, the forecast, its text |
| `tests/test_insight.gd` | Insight (139): techs cost insight only, buying spends it, civilization tech discounts, tree and details prices in insight, the forecast and the top bar's Insight counter |
| `tests/test_tech_eras.gd` | `era`, the `add_era` and `research` ops, `future_techs`, the empty deck adding the next era, era techs never lost, Library |
| `tests/test_prices.gd` | Prices and unrest in one place (173): `can_pay` / `pay` / `price_error`, `Fields.amounts_text`, `set_unrest` stopping at the limit; only EngineCore lowers resources or writes unrest |
| `tests/test_supply.gd` | The card supply: `supply` config, `supply` / `supply_left` / `buy_price` / `buy_error` / `buy`, blocking; locked piles, `supply_locked` and the `unlock` op (057) |
| `tests/test_terrains.gd` | Terrain keywords (130): config `terrains`, exactly one terrain per territory, terrain-keyed roll tables, terrain/feature keyword details |
| `tests/test_territory_resources.gd` | Rolled resource keywords: `resource_keywords` / `territory_resources` config, rolling per copy, `territory_keywords` |
| `tests/test_territories.gd` | Territory cards, `keywords` / `territory_deck` / `starting.territory` config, territory setup |

Add a new file when an area grows past ~300 lines or is a separate concern
(e.g. `test_effects.gd`, `test_market.gd`).

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
Minimum sizes before a layout pass are meaningless. After each test the runner frees anything the test left in the
tree (a UI test that crashed before `close_main`), so one crash doesn't fail every later UI test (087).
Before the first test the runner swaps the `Settings` store for a fresh one (`user://test_run_settings.cfg`, Day mode
and Reduce motion off), so the player's own settings never change a result; after the run it fails if the player's
`user://settings.cfg` changed (195). A test that needs a setting on uses `with_temp_settings` or `with_reduce_motion`.

### Available in every test (`tests/lib/test_case.gd`)

| Name | Use |
|---|---|
| `eq(actual, expected, what)` | Equality. Always pass `what` so failures say which value was wrong |
| `check(cond, message)` | Boolean assertion |
| `has_msg(messages, fragment)` | Some loader error/warning contains `fragment` |
| `check_noticed(recorded, fragment, priority)` | A notice follows its log line in `record_messages`' recording; given a priority, it was noticed with it (190) |
| `expect_error(fragment)` | An error containing `fragment` must be logged (`push_error`) during the test; it doesn't fail it (186) |
| `make_engine(deck, overrides, seed)` | New game from `TEST_CARDS`; `deck` is `{id: count}`; `overrides` replace config keys. The Capital starts on `homeland` (5 slots) |
| `TEST_CARDS` | Small, stable card set (includes territories `grassland` and `hills`). Add cards here when a test needs a new shape |
| `tests/lib/tech_case.gd` | Base class for tech tests: fixture `TECHS`, `tech_db`, `tech_engine` (a `GameEngine` with 20 wealth and 20 insight) |
| `tests/lib/anarchy_case.gd` | Base class for Anarchy tests (145–148): fixture governments and cards, `anarchy_raw` / `anarchy_engine` (the unrest block, no renewal; extra cards optional), `fallen_engine` (in Anarchy), `revolted_engine` (a revolution's Anarchy), `second_turn_engine` (Anarchy's second turn), `ruling`, `raw_config_errors` (a raw config's errors) |
| `keywords()` | Keyword ids the `TEST_CARDS` territories use; pass to `parse_cards` |
| `raw_config(deck, overrides)` | Config dictionary for loader tests |
| `fixture_load(extra, sets, resource_list, resource_keywords)` | `TEST_CARDS`, then each fixture set in `sets` (`[TEST_GOVS, TEST_CIVS]`, `[TECHS]`, …), then `extra`, parsed: `{cards, errors, warnings}`; for loader tests (170) |
| `fixture_db(extra, sets, resource_list)` | `fixture_load`'s cards, failing the test on a load error (170) |
| `cards_of(r, errors, warnings)` | A `fixture_load` result's cards, appending its errors and warnings to the out arrays (the `*_db` helpers) |
| `config_errors_for(cards, overrides, deck)` | The errors from parsing a config against the parsed card db `cards`; `overrides` replace keys after `raw_config`'s defaults (a `population` block is used as given) |
| `config_errors(overrides, sets, deck)` | `config_errors_for` on `fixture_db([], sets)`; the only `config_errors` (170: per-file variants are named for what they take, e.g. `population_errors`, `raw_config_errors`) |
| `explore_engine()` / `over_engine()` | A `make_engine` game with an explore choice open (Hills and Grassland revealed, Jungle below); a finished game (turn_limit 1) |
| `card_with(type, effect)` / `set_home_pop(engine, n)` / `capital_land(engine)` | A card "x" with one effect; the home territory's pop; the territory the Capital stands on |
| `card_ids(zone)` / `first_in_hand(engine)` / `home_uid(engine)` | Inspection helpers; `home_uid` is the config's starting territory (fixed in 087: it used to find only `homeland`) |
| `uid_of(zone, id)` / `sorted(array)` | First uid with that id (or -1); a sorted copy for order-free comparisons |
| `arrange(zone, ids_top_first)` | Puts those cards on top of the zone, top first; the rest stay below |
| `settle(engine, ids)` / `to_frontier(engine, ids)` | Moves those territory copies from `territory_deck` to the tableau / frontier |
| `wait_frames(n)` | `await wait_frames()` lets containers lay out before a UI test measures sizes or positions (088); headless starts at 1920×1920, so set the window size first if the test depends on it |
| `put_in_hand(engine, id)` | Puts a new copy in the hand (via `create_card`) and returns its uid |
| `put_in(engine, id, zone)` | Same, into any zone; a government is placed directly, as `create_card` sends it to the government deck (154) |
| `build_on(engine, territory_uid, ids)` | Puts new copies of those buildings straight on a territory, in order (no cost or slot check; the last go idle first) |
| `check_cases(cases, load)` | Table-driven loader validation: rows `[label, input, fragment(s), kind]`, kind `errors` / `one_error` / `warnings` / `warning_only` |
| `TEST_CIVS` / `civ_db()` / `civ_engine(civ, deck, overrides)` | Fixture civilizations (Tribe, Nomads; backlog 062), kept out of `TEST_CARDS`; `civ_engine` starts a game with `starting.civilization` civ (`""` for none) |
| `TEST_GOVS` / `gov_db()` / `gov_engine(gov, deck, overrides)` | Fixture governments (Council, Kingdom; backlog 065), kept out of `TEST_CARDS`; `gov_engine` starts a game with `starting.government` gov (`""` for none) |
| `TEST_EVENTS` / `event_db()` | Fixture events (Windfall, Trade Winds, Omen, Harvest; backlog 039), kept out of `TEST_CARDS`; `event_db` parses both |
| `with_event_engine(body, event_deck, overrides)` | UI tests: runs `body` with `Game.engine` swapped for a game on `TEST_CARDS` + `TEST_EVENTS`, then puts the real engine back (moved from `test_event_panel` in 079) |
| `open_main()` / `close_main(main)` / `play_seed_1(main, after_turn)` | UI tests: add and free the real main scene; play seed 1 to the end with `ScriptedBot`, calling `after_turn(main)` each turn. A real-data game is cut to `SEED_1_TURNS` (20) turns, and `close_main` restores the limit (066: 100 turns through the UI is too slow). A fixture main deck must not loop the bot (TEST_CARDS' `scout` only draws) |
| `with_temp_settings(body, path)` | Runs `body` with the Settings autoload saving to a temp file (Day mode and Reduce motion off), then puts the player's settings and palette back; `Settings.store.path` is the temp file inside `body` |
| `mid_game()` / `each_screen(visit)` / `visible_controls(root)` | UI tests: main on a seed-1 game at turn 3; `visit(main, name)` on the board and every screen and modal (193, 194); the visible controls under a node |
| `with_main(engine, body)` / `with_territories_main(body, deck, overrides)` / `with_game(calm, body)` | UI tests: run `body(main)` on the real main scene started on seed 1: on `engine`; on a `make_engine` game with Grassland and Hills to explore; on the real game with Reduce motion `calm` |
| `state_dump(v)` / `state_equal(a, b)` / `state_diff(a, b)` | Deep state as text (script objects by their variables, a CardDef by id, an RNG by seed and state), equality on it, and the variables of two objects that differ (171) |
| `script_vars(o)` / `shared_refs(a, b)` / `scribble(v)` | An object's script variables; the paths where a value and its copy share an array, dictionary or object; change everything reachable in place (171) |
| `press_key(main, keycode)` | UI tests: presses and releases a key through main's viewport, as the keyboard would |

Add a helper to `test_case.gd` once two test files need it, and check there (and in `tech_case.gd`) before
writing one. Helpers take and return `GameEngine`; a test types an engine `Object` only in its red phase. Two files'
helpers with the same name must do the same thing. Tests never call engine members that start with `_`: if setup needs one, add a public method.

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
