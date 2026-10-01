# Testing

Dependency-free runner: no addon, just Godot headless.

## Running

```bash
scripts/test.sh              # everything
scripts/test.sh rules        # files/tests whose "file::method" contains "rules"
scripts/test.sh test_create  # a single test (or group) by name
```

The script re-imports the project first when a `.gd` file changed, so a new `class_name` resolves
in the same run. Output is quiet: one `FAIL` line per problem, then `N tests, M failures`.
Exit code 0 means green.

A test fails when:
- an assertion fails (`eq`, `check`, `has_msg`);
- it makes no assertions (empty, or crashed before the first one);
- any engine or script error is logged while it runs (null access, missing method, `push_error`);

and the whole run fails if a test file doesn't parse or the filter matches nothing.

## Writing tests

Put tests in `tests/test_<area>.gd`. Current areas:

| File | Covers |
|---|---|
| `tests/test_content.gd` | The real data: invariants over the whole data set, never a single card (every keyword used, every cost has a source, every building's requires met in play, eras reachable with 2+ techs, techs and supply consistent) and a 20-seed `ScriptedBot` sweep |
| `tests/test_ui_smoke.gd` | The real `main.tscn` follows a whole `ScriptedBot` game: no script errors, hand views match the hand, game-over text; uses main's test hooks (`start_game`, `hand_view_count`, `game_over_text`) |
| `tests/test_event_modal.gd` | `event_drawn`, `outcome_summary`, and the drawn-event modal in the real `main.tscn` (079): what it shows, closing it, hand-limit and last-turn order |
| `tests/test_event_panel.gd` | The event panel in the real `main.tscn`: event views match `active_events`, turns left, the event pile counts, hidden without an event deck; runs main on fixture data with `with_event_engine` and the `event_panel()` hook |
| `tests/test_ui_structure.gd` | The shape of `ui/`: one script per component (and `CardView`'s content and motion in `CardFace` and `CardMotion`), no engine internals (`pending_choice`, `state`, …) read in `ui/` |
| `tests/test_board_labels.gd` | The board's section order (Realm, Frontier, Known, Hand) and game words in the real `main.tscn`: no "tableau" on screen, no seed in the top bar, Buy Cards, Knowledge; uses the `section_headings()` hook |
| `tests/test_card_slots.gd` | Card slots in the real `main.tscn` start at the height their card rests at (frontier and Known cards while still flying; hand slots) |
| `tests/test_start_screen.gd` | The title, new game and settings screens in the real `main.tscn` (063, 099): the title screen on launch with no game started and three buttons, New game → Start with a seed or a random one, Settings with the shared Reduce motion setting (saved to a temp file), Back and Esc to the title, Exit, the menu's New game to the new game screen, Restart and Replay skipping the screens, keyboard focus and wrapping; the civilization cards (064: listed, preselected, selecting saves, Restart keeps, named in the menu and at game over); uses `main.start_screen`, `main.new_game_screen`, `main.settings_screen` and `main.board_shown()` |
| `tests/test_button_widths.gd` | Button widths in the real `main.tscn` at 1920×1080 (100): buttons fit their text; the title, settings, new game, menu and game-over buttons share one width in a centred column; tech tiles and seed fields still fill (the top bar: `test_board_layout`) |
| `tests/test_territory_view.gd` | The territory view in the real `main.tscn` (101) on a TEST_CARDS game: a click on a territory opens it in place of the Realm (a city's click still shows details), stats and Grow, Back / Esc / new game / game over close it, drops and double-clicks play onto it, targeting wins over opening, ↑/↓ and Enter from the hand; uses `main.territory_view` (`is_open`, `uid`, `card_uids`, `stats_text`, `target_at`, `back_button`, `grow_button`); 105: the territory as the framed box (its name and info as the title, stats and Grow above the cards, its card left in the Realm), free-slot outlines after the cards, no pop-in or fly-off when opening or closing (`frame`, `title_text()`, `outlines()`, `free_slot_count()`) |
| `tests/test_theme.gd` | The UI theme (106): today's look recorded through the real `main.tscn` (labels, panels, buttons in every state, the field, the focus ring, card type colours; a guard that must not change), no colour literals in `ui/` outside `palette.gd`, the palette's names, `GameTheme.build()`'s controls and variations, UIKit labels and overlay panels using them |
| `tests/test_navigator.gd` | `Navigator` (103) on plain Controls: push hides the screen below, back and Esc return to it (never past the root), focus given and given back, `set_root` / `clear`, one `changed` per step; the title, new game and settings screens on `main.nav`; 104: titles, `ScreenHeader`, and an animated navigator's transitions (grow from a rect, fade, Reduce motion, back reverses with the screen below live at once, a new step finishes the running one) |
| `tests/test_screen_header.gd` | The header on the new game and settings screens and the territory view in the real `main.tscn` (104), and a territory's view growing out of its card and shrinking back; uses `with_reduce_motion` and `wait_screen_transition` |
| `tests/test_resource_tokens.gd` | Resource tokens in the real `main.tscn` (114): costs float up from just below their counter (top bar and supply screen), staggered, fading in place with Reduce motion; gains still fly to their counter; steps tweens by hand to read the path |
| `tests/test_board_layout.gd` | The board without a sidebar in the real `main.tscn` at 1920×1080 (115): no `SidePanel`, the Realm and the hand row reach the right edge, the top bar's order and fit, End turn in the top bar between Log and Menu (E, the discard text, disabled with its reason; 120), keys in the tooltips, the bar fitting with its longest texts |
| `tests/test_log_drawer.gd` | The log drawer in the real `main.tscn` (115): closed at the start, L / the Log button open it sliding in from the right (fading with Reduce motion), L / Esc / the button / a click outside close it, lines append while closed, a new game clears it; uses `main.log_drawer` (`is_open()`, `text()`) |
| `tests/test_toasts.gd` | Toasts and the unread marker in the real `main.tscn` (116): a notice's toast under the top bar for `Anim.TOAST_TIME`, at most 3 newest on top, fading in place with Reduce motion, the targeting hint until targeting ends, refusals not toasted, "Log •" for unseen lines, toasts ignoring mouse and focus and hiding under the menu and tech tree; uses `main.toasts` (`shown()`, `texts()`). Engine notices are tested beside each scenario with `record_messages` / `check_noticed` (test_case.gd) |
| `tests/test_card_landing.gd` | How a card lands (117): a dealt card settles with no squash but still flies and fades in; other flights still squash; a rejected card still shakes. CardViews in a plain Control tree, stepped by frames |
| `tests/test_menu.gd` | The menu in the real `main.tscn`: Exit is last, pressing it or Enter on it calls `quit_hook` once, Tab wraps through it, no Exit at game over; uses the `menu_buttons()` / `game_over_buttons()` hooks |
| `tests/test_script_size.gd` | Script size limits (`tests/lib/script_sizes.gd`): no script in `engine/` or `ui/` over 700 lines; each one over 500 prints a `WARN` line in `scripts/test.sh` output |
| `tests/test_sim.gd` | The simulator: `ScriptedBot` policy, `SimStats.run` metrics, `SimStats.run_files` (what `scripts/sim.sh` prints) |
| `tests/test_card_details.gd` | `def_details` / `card_details`: rules, live state (pop, slots, idle, tech price now), terms and generated keyword terms |
| `tests/test_details_modal.gd` | The details modal in the real `main.tscn`: I opens it for the focused card, Esc closes it, board keys blocked, supply piles; uses `main.details.shown()` |
| `tests/test_tech_tree.gd` | `tech_tree()` (states, cost now, passes, `gives`) and `era_name` / config `era_names` |
| `tests/test_tech_tree_modal.gd` | The Knowledge modal in the real `main.tscn`: T and the Knowledge button open it, one column per era by name, T/Esc close; uses `main.tech_tree.shown()` |
| `tests/test_card_text.gd` | Card text: short `rules_text` (⟳, merged keyword bonuses) and full `rules_tooltip` |
| `tests/test_data_loader.gd` | JSON parsing, validation errors and warnings |
| `tests/test_action_errors.gd` | `discard_error`, `choose_error`, `decline_research_error`, and the main scene showing their reasons (093) |
| `tests/test_changed.gd` | The `changed` signal: once per successful action, none when refused |
| `tests/test_ui_queries.gd` | Engine queries the UI relies on: `playable_error`, `end_turn_error`, `supply_error`, `upcoming_era_unlocks`, `territory_groups`, `territory_summary`, `needs_target_choice`, `tech_eras`, `open_supply_piles` (094) |
| `tests/test_pending.gd` | `pending()` for each decision kind (explore, research, discard) and the one blocking rule every action follows |
| `tests/test_game_state.gd` | `GameState.copy` and `GameEngine.fork`: deep copies, independent RNG, pending choice, no signals or log on the original; the forecast not disturbing the next hand |
| `tests/test_rules.gd` | `GameEngine`: setup, actions, turn loop, scoring, game end |
| `tests/test_keywords.gd` | Keywords: building `requires`, keyword-conditioned effects, validation, card text |
| `tests/test_play_outcome.gd` | `GameEngine.card_played`: the outcome reported for each play |
| `tests/test_explore.gd` | The `explore` op: loading, reveal, `pending_choice`, `choose`, blocking play and end turn |
| `tests/test_settle.gd` | The `settle` op (loading and play) and card targets: `valid_targets`, `needs_target`, target checks, outcome `target` |
| `tests/test_slots.gd` | Building slots: `total_slots`, `free_slots`, city slot bonus, building targets and placement |
| `tests/test_food_upkeep.gd` | Pop eating food at upkeep, and a first shortfall's one death |
| `tests/test_famine.gd` | The Famine (083): arrives, escalates to max_counters, one at a time, ends when fed and leaves the game, blocks growth, guards, forecast, `event_counters`, config |
| `tests/test_famine_guard.gd` | Building `housing` and `famine_guard` (060): loading, housing cap, saving starving pop, forecast, card text; uses the Silo fixture and `build_on` |
| `tests/test_forecast.gd` | `upkeep_forecast`: next upkeep's net food and wealth, idle buildings, upkeep growth, `starve` |
| `tests/test_gain_per_keyword.gd` | The `gain_per_keyword` op (081): count per settled territory with any keyword (once each, frontier excluded, rolled keywords), `count_territories_with`, upkeep and forecast, loading, card text |
| `tests/test_identity_lines.gd` | The civilization and government in the real `main.tscn` (088, 115, 119): one top-bar button naming both, the modal showing the civilization then the government (flavor, quote, rules; "No bonus."), Esc / Close, above the log drawer, one or neither, a new government, no empty lines; End turn on screen at 1920×1080; uses `identity_button()` and `identity_modal` (`shown()`, `body_text()`, `close_button`) |
| `tests/test_territory_cards.gd` | Territories as plain cards in the Realm (102) on a TEST_CARDS game: one card per territory then cards on no territory (`main.tableau.row`), no city or building card outside the territory view, the stats line, drag targets (`drag.target_at`) and targeting, no collapse or Grow in the Realm, a settled territory's card, many cards wrap (078) |
| `tests/test_harmful_ops.gd` | The `lose` and `lose_pop` ops (072): never below 0, the largest territory (ties in tableau order), a drawn event, upkeep and forecast, loading, card text, log |
| `tests/test_trash.gd` | The `trash` op (082): hand targets (never the card played), errors, auto-pick, `trashed` never reshuffled, fork, loading, card text |
| `tests/test_trash_targeting.gd` | Trash targeting in the real `main.tscn`: a double-clicked Winnow lights the other hand cards as pickable; picking one trashes it; uses `main.drag` and `main.views` |
| `tests/test_trade.gd` | The `trade` op: loading, the `min_cities` block, √cities + pop payout, card text |
| `tests/test_growth_cards.gd` | The `grow` op: loading, Granary (`here`), Festival (`each`), housing cap |
| `tests/test_growth.gd` | Buying growth: `grow`, `grow_error`, `grow_cost` |
| `tests/test_population.gd` | Population: territory `housing`, the config `population` block, starting and settled pop, pop VP |
| `tests/test_workers.gd` | Workers: `free_workers`, placement needing a worker, idle buildings at upkeep |
| `tests/test_settings.gd` | `SettingsStore`: saving and loading `reduce_motion` and `civilization`, `civilization_in` fallback, bad or missing files |
| `tests/test_wealth.gd` | Wealth, the second resource: mixed costs, gaining wealth, carry over, wealth never used as food |
| `tests/test_hand_limit.gd` | Keeping the hand, draw up to `hand_size`, `hand_limit`, `discard_needed` / `discard_card`, voluntary discards |
| `tests/test_events.gd` | The event deck: the `event` type and `discard`, `event_deck` config, one draw per end turn, active events' upkeep and discard, reshuffling |
| `tests/test_civilization.gd` | Civilization cards (062): the type, the `start` trigger, `starting.civilization`, setup, upkeep, forecast, score, fork, card text; uses `TEST_CIVS` / `civ_engine` |
| `tests/test_government.gd` | Government cards (065): the type, `starting.government`, `government()`, playing one to replace the ruling one (to `removed`), upkeep, forecast, score, the same-government error, fork; uses `TEST_GOVS` / `gov_engine` |
| `tests/test_choose_civilization.gd` | Choosing a civilization (064): config `civilizations`, `civilizations()`, `new_game(seed, civ_id)`, `new_game_error`, the same seed dealing the same game for any civilization |
| `tests/test_research.gd` | Techs: the `tech` card type, `research_deck` config, playing Research (`play_research` helper) / `buy_tech` / `decline_research`, blocking, no charges |
| `tests/test_tech_passes.gd` | Tech passes, stacking discount, removal to `lost_techs`, `prereq` discount, cost floor, prerequisite card text |
| `tests/test_tech_eras.gd` | `era`, the `add_era` and `research` ops, `future_techs`, the empty deck adding the next era, era techs never lost, Library |
| `tests/test_supply.gd` | The card supply: `supply` config, `supply` / `supply_left` / `buy_price` / `buy_error` / `buy`, blocking; locked piles, `supply_locked` and the `unlock` op (057) |
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

### Available in every test (`tests/lib/test_case.gd`)

| Name | Use |
|---|---|
| `eq(actual, expected, what)` | Equality. Always pass `what` so failures say which value was wrong |
| `check(cond, message)` | Boolean assertion |
| `has_msg(messages, fragment)` | Some loader error/warning contains `fragment` |
| `make_engine(deck, overrides, seed)` | New game from `TEST_CARDS`; `deck` is `{id: count}`; `overrides` replace config keys. The Capital starts on `homeland` (5 slots) |
| `TEST_CARDS` | Small, stable card set (includes territories `grassland` and `hills`). Add cards here when a test needs a new shape |
| `tests/lib/tech_case.gd` | Base class for tech tests: fixture `TECHS`, `tech_db`, `tech_engine` (20 wealth), `pass_tech`, `research_engine()` (Pottery and Writing revealed by Research) |
| `keywords()` | Keyword ids the `TEST_CARDS` territories use; pass to `parse_cards` |
| `raw_config(deck, overrides)` | Config dictionary for loader tests |
| `load_with(extra, resource_keywords)` | `TEST_CARDS` plus `extra` cards, parsed: `{cards, errors, warnings}` |
| `config_errors_for(cards, overrides, deck)` | The errors from parsing a config against the parsed card db `cards`; `overrides` replace keys after `raw_config`'s defaults (a `population` block is used as given) |
| `card_ids(zone)` / `first_in_hand(engine)` / `home_uid(engine)` | Inspection helpers; `home_uid` is the config's starting territory (fixed in 087: it used to find only `homeland`) |
| `uid_of(zone, id)` / `sorted(array)` | First uid with that id (or -1); a sorted copy for order-free comparisons |
| `arrange(zone, ids_top_first)` | Puts those cards on top of the zone, top first; the rest stay below |
| `settle(engine, ids)` / `to_frontier(engine, ids)` | Moves those territory copies from `territory_deck` to the tableau / frontier |
| `wait_frames(n)` | `await wait_frames()` lets containers lay out before a UI test measures sizes or positions (088); headless starts at 1920×1920, so set the window size first if the test depends on it |
| `put_in_hand(engine, id)` | Puts a new copy in the hand (via `create_card`) and returns its uid |
| `build_on(engine, territory_uid, ids)` | Puts new copies of those buildings straight on a territory, in order (no cost or slot check; the last go idle first) |
| `check_cases(cases, load)` | Table-driven loader validation: rows `[label, input, fragment(s), kind]`, kind `errors` / `one_error` / `warnings` / `warning_only` |
| `play_research(engine)` | Puts a Research card (`study`) in hand and plays it, revealing techs (backlog 034) |
| `TEST_CIVS` / `civ_db()` / `civ_engine(civ, deck, overrides)` | Fixture civilizations (Tribe, Nomads; backlog 062), kept out of `TEST_CARDS`; `civ_engine` starts a game with `starting.civilization` civ (`""` for none) |
| `TEST_GOVS` / `gov_db()` / `gov_engine(gov, deck, overrides)` | Fixture governments (Council, Kingdom; backlog 065), kept out of `TEST_CARDS`; `gov_engine` starts a game with `starting.government` gov (`""` for none) |
| `TEST_EVENTS` / `event_db()` | Fixture events (Windfall, Trade Winds, Omen, Harvest; backlog 039), kept out of `TEST_CARDS`; `event_db` parses both |
| `with_event_engine(body, event_deck, overrides)` | UI tests: runs `body` with `Game.engine` swapped for a game on `TEST_CARDS` + `TEST_EVENTS`, then puts the real engine back (moved from `test_event_panel` in 079) |
| `open_main()` / `close_main(main)` / `play_seed_1(main, after_turn)` | UI tests: add and free the real main scene; play seed 1 to the end with `ScriptedBot`, calling `after_turn(main)` each turn. A real-data game is cut to `SEED_1_TURNS` (20) turns, and `close_main` restores the limit (066: 100 turns through the UI is too slow); `test_content`'s sweep plays full games. A fixture main deck must not loop the bot (TEST_CARDS' `scout` only draws) |
| `press_key(main, keycode)` | UI tests: presses and releases a key through main's viewport, as the keyboard would |

Add a helper to `test_case.gd` once two test files need it, and check there (and in `tech_case.gd`) before
writing one. Tests never call engine members that start with `_`: if setup needs one, add a public method.

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
