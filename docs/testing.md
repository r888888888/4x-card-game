# Testing

Dependency-free runner: Godot headless, no addon.

## Running

```bash
scripts/test.sh              # everything but tests/balance/
scripts/test.sh rules        # files/tests whose "file::method" contains "rules"
scripts/test.sh test_create  # a single test (or group) by name
scripts/test.sh --balance    # only tests/balance/ (filter as above)
```

**The balance suite** (`tests/balance/`): tests that play GenericBot games on the real data (`data/*.json`): the
sim's report, its options and the parallel run. The main suite and the Stop hook leave them out; only the user runs
it (or asks for a run). Bot rules and `SimStats` stay in the main suite,
tested on fixture games of a few turns.

**The Python tools' tests** (`scripts/tests/`, stdlib `unittest`): `scripts/test.sh` runs them after the Godot shards
(not with `--balance`), passes the filter as `-k`, and adds them to the count. `test_card_art.py` covers
`scripts/card_art.py` against a temporary art folder and a fake image API (397).

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
  A test checking an animation part-way should wait frames or game seconds, never wall-clock time.
  `Sfx.clock()` is the wall clock, so a test that checks when a sound is due freezes it first (`main.sfx.set_clock`),
  then compares against that time (236).
- The engine isn't the cost (a `make_engine` game builds in 0.5 ms); the main scene is (~18 ms per UI test).

A test fails when:
- an assertion fails (`eq`, `check`, `has_msg`);
- it makes no assertions (empty, or crashed before the first one);
- any engine or script error is logged while it runs (null access, missing method, `push_error`), unless the test
  expected it with `expect_error(fragment)` (then the test fails if no such error is logged);

and the whole run fails if a test file doesn't parse or the filter matches nothing.

## Writing tests

Put tests in `tests/test_<area>.gd`. Each file opens with a `##` header saying what it covers (the suite checks):
that header is the source. [testing-index.md](testing-index.md) gives each file one short row; a new test file adds
its row there (the suite checks it lists every file, in rows of at most 160 characters).

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
| `make_engine(deck, overrides, seed, extra_cards)` | New game from `TEST_CARDS` (+ `extra_cards`) |
| `TEST_CARDS` | Small, stable card set (includes territories `grassland` and `hills`) |
| `tests/lib/tech_case.gd` | Base class for tech tests: `TECHS`, `tech_db`, `tech_engine` |
| `tests/lib/raid_case.gd` | Base class for raid tests: `RAID_CARDS`, `raid_load`, `raid_engine` |
| `tests/lib/anarchy_case.gd` | Anarchy tests' base (145–148): fixture governments, `anarchy_engine` |
| `keywords()` | Keyword ids the `TEST_CARDS` territories use; pass to `parse_cards` |
| `raw_config(deck, overrides)` | Config dictionary for loader tests |
| `fixture_load(extra, sets, resource_list, resource_keywords)` | `TEST_CARDS`, fixture sets, then `extra`, parsed |
| `fixture_db(extra, sets, resource_list)` | `fixture_load`'s cards, failing the test on a load error (170) |
| `cards_of(r, errors, warnings)` | A `fixture_load` result's cards; its messages appended to the out arrays |
| `config_errors_for(cards, o, deck)` / `config_errors(o, sets, deck)` | A config's errors on `cards` / `fixture_db([], sets)` |
| `card_load(card, sets)` / `config_load(o, sets)` / `config_load_on(r, o)` | One card's `fixture_load`; a config on one (340) |
| `explore_engine()` / `over_engine()` | A game with an explore choice open; a finished game |
| `card_with(type, effect)` / `set_home_pop(engine, n)` / `capital_land(engine)` | Card "x" with one effect; home pop; Capital's land |
| `card_ids(zone)` / `first_in_hand(engine)` / `home_uid(engine)` | Inspection; `home_uid`: the starting territory |
| `uid_of(zone, id)` / `sorted(array)` | First uid with that id (or -1); a sorted copy |
| `arrange(zone, ids_top_first)` | Puts those cards on top of the zone, top first; the rest stay below |
| `settle(engine, ids)` / `to_frontier(engine, ids)` | Moves territories from the deck to the tableau / frontier |
| `wait_frames(n)` / `settle_motion()` | Containers lay out (088); cards land |
| `check_wheel_step(main, scroll, what)` / `with_window_size(size, body)` | UI: a notch's scroll (362) |
| `put_in_hand(engine, id)` | Puts a new copy in the hand (via `create_card`) and returns its uid |
| `put_in(engine, id, zone)` | Same, into any zone (a government placed directly) |
| `build_on(engine, territory_uid, ids)` | Puts new copies of those buildings straight on a territory, in order |
| `check_cases(cases, load)` / `check_loads(rows, load)` | Loader tables: rejected input / accepted input (340) |
| `TEST_CIVS` / `civ_db()` / `civ_engine(civ, deck, overrides)` | Fixture civilizations and a game as one (062) |
| `TEST_GOVS` / `gov_db()` / `gov_engine(gov, deck, overrides)` | Fixture governments and a game under one (065) |
| `TEST_EVENTS` / `event_db()` | Fixture events (039) and their card db |
| `with_event_engine(body, event_deck, overrides)` | UI tests: `body` with `Game.engine` on `TEST_CARDS` + `TEST_EVENTS` |
| `open_main()` / `close_main(main)` / `play_seed_1(main, after_turn)` | UI: add / free main; play seed 1 out |
| `with_temp_settings(body, path)` | Runs `body` with the settings saved to a temp file, then restores them |
| `shown_state(key)` | The state a toggle key shows, "ON" or "OFF" (219) |
| `close_event(main)` | UI tests: closes the drawn-event modal if one is up |
| `mid_game()` / `each_screen(visit)` / `visible_controls(root)` | UI: seed 1 turn 3; each screen and modal; visible controls |
| `with_main(engine, body)` / `with_territories_main(body, deck, overrides)` / `with_game(calm, body)` | UI: `body(main)` on main, seed 1 |
| `state_dump(v)` / `state_equal(a, b)` / `state_diff(a, b)` | Deep state as text, equality on it, and what differs |
| `script_vars(o)` / `shared_refs(a, b)` / `scribble(v)` | Script variables; shared references; change all in place |
| `accent_footer(modal)` | UI tests: a modal's footer buttons in the primary look (251) |
| `press_key(main, keycode)` | UI tests: presses and releases a key through main's viewport |
| `reason_text(view)` | UI: the text of a card's reason strip (why it can't be played; 383) |
| `open_game(big, freeze_sfx)` / `close_game(main)` | UI: main on seed 1 (1920 × 1080, sound frozen if asked) (334) |
| `click_control` / `click_point` / `move_mouse` / `away` / `centre` / `hovers` / `open_details` | UI: real clicks, moves, hovers |
| `shown_button(root, prefix)` / `wait_seconds(s)` / `hills_of(engine)` | Button by text; seconds; Hills' uid |
| `MainProbe` (`tests/lib/main_probe.gd`) | UI: controls and readings inside main's components, `MainProbe.event_modal(main)` (392) |

A helper a second test file needs moves to `tests/lib/` (the suite checks copies, 334); look there before writing one.
A UI test that needs a control inside one of main's components adds a `MainProbe` function, never a method on
`main.gd` (the suite fails on a test hook there, 392).
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
- **Balance** is not tested, and not checked per change: it's a separate, manual step (only when the user asks),
  using `scripts/sim.sh` / the `balance` skill.
- **Helper names** must not start with `test_`: the runner calls every `test_*` method with no arguments.
- **Real data** is only checked by `test_real_data_loads` and `tests/test_content.gd` (invariants and a
  smoke test). Don't assert exact numbers from `data/` (slots, costs, deck sizes): a balance edit must not
  break a test. Warnings in the real data are checked once, in `test_real_data_loads_without_warnings`.
- **Signals**: connect a lambda that appends to an array, then assert on the array
  (see `test_game_ends_at_turn_limit`).
- **Loader tests** are tables, a case per row (a failing row names its label). Rejected input:
  `check_cases([[label, input, fragment, kind?], ...], load)`; messages name file, card and field. Accepted input:
  `check_loads([[label, input, {"cards.x.era": 2}], ...], load)`: no messages, each path equal (340). Bind `load`
  (`fixture_load.bind([TEST_GOVS])`) rather than wrap it.
