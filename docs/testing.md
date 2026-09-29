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
| `tests/test_content.gd` | The real data: invariants (every keyword used, every cost has a source, techs and supply consistent) and a 20-seed `ScriptedBot` sweep |
| `tests/test_ui_smoke.gd` | The real `main.tscn` follows a whole `ScriptedBot` game: no script errors, hand views match the hand, game-over text; uses main's test hooks (`start_game`, `hand_view_count`, `game_over_text`) |
| `tests/test_sim.gd` | The simulator: `ScriptedBot` policy, `SimStats.run` metrics, `SimStats.run_files` (what `scripts/sim.sh` prints) |
| `tests/test_card_text.gd` | Card text: short `rules_text` (⟳, merged keyword bonuses) and full `rules_tooltip` |
| `tests/test_data_loader.gd` | JSON parsing, validation errors and warnings |
| `tests/test_changed.gd` | The `changed` signal: once per successful action, none when refused |
| `tests/test_ui_queries.gd` | Engine queries the UI relies on: `playable_error`, `end_turn_error`, `supply_error`, `upcoming_era_unlocks`, `territory_groups` |
| `tests/test_pending.gd` | `pending()` for each decision kind (explore, research, discard) and the one blocking rule every action follows |
| `tests/test_rules.gd` | `GameEngine`: setup, actions, turn loop, scoring, game end |
| `tests/test_keywords.gd` | Keywords: building `requires`, keyword-conditioned effects, validation, card text |
| `tests/test_play_outcome.gd` | `GameEngine.card_played`: the outcome reported for each play |
| `tests/test_explore.gd` | The `explore` op: loading, reveal, `pending_choice`, `choose`, blocking play and end turn |
| `tests/test_settle.gd` | The `settle` op (loading and play) and card targets: `valid_targets`, `needs_target`, target checks, outcome `target` |
| `tests/test_slots.gd` | Building slots: `total_slots`, `free_slots`, city slot bonus, building targets and placement |
| `tests/test_food_upkeep.gd` | Pop eating food at upkeep and starvation |
| `tests/test_forecast.gd` | `upkeep_forecast`: next upkeep's net food and wealth, idle buildings, upkeep growth, `starve` |
| `tests/test_growth_cards.gd` | The `grow` op: loading, Granary (`here`), Festival (`each`), housing cap |
| `tests/test_growth.gd` | Buying growth: `grow`, `grow_error`, `grow_cost` |
| `tests/test_population.gd` | Population: territory `housing`, the config `population` block, starting and settled pop, pop VP |
| `tests/test_workers.gd` | Workers: `free_workers`, placement needing a worker, idle buildings at upkeep |
| `tests/test_settings.gd` | `SettingsStore`: saving and loading `reduce_motion`, bad or missing files |
| `tests/test_wealth.gd` | Wealth, the second resource: mixed costs, gaining wealth, carry over, wealth never used as food |
| `tests/test_hand_limit.gd` | Keeping the hand, draw up to `hand_size`, `hand_limit`, `discard_needed` / `discard_card`, voluntary discards |
| `tests/test_research.gd` | Techs: the `tech` card type, `research_deck` config, playing Research (`play_research` helper) / `buy_tech` / `decline_research`, blocking, no charges |
| `tests/test_tech_passes.gd` | Tech passes, stacking discount, removal to `lost_techs`, `prereq` discount, cost floor, prerequisite card text |
| `tests/test_tech_eras.gd` | `era`, the `add_era` and `research` ops, `future_techs`, the empty deck adding the next era, era techs never lost, Library |
| `tests/test_supply.gd` | The card supply: `supply` config, `supply` / `supply_left` / `buy_price` / `buy_error` / `buy`, blocking |
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
before the first test so the `Game` and `Settings` autoloads are in the tree and ready; no other frames run, so
UI tests see structure (views, labels, overlays), never finished animations.

### Available in every test (`tests/lib/test_case.gd`)

| Name | Use |
|---|---|
| `eq(actual, expected, what)` | Equality. Always pass `what` so failures say which value was wrong |
| `check(cond, message)` | Boolean assertion |
| `has_msg(messages, fragment)` | Some loader error/warning contains `fragment` |
| `make_engine(deck, overrides, seed)` | New game from `TEST_CARDS`; `deck` is `{id: count}`; `overrides` replace config keys. The Capital starts on `homeland` (5 slots) |
| `TEST_CARDS` | Small, stable card set (includes territories `grassland` and `hills`). Add cards here when a test needs a new shape |
| `tests/lib/tech_case.gd` | Base class for tech tests: fixture `TECHS`, `tech_db`, `tech_engine` (20 wealth), `pass_tech` |
| `keywords()` | Keyword ids the `TEST_CARDS` territories use; pass to `parse_cards` |
| `raw_config(deck, overrides)` | Config dictionary for loader tests |
| `card_ids(zone)` / `first_in_hand(engine)` / `home_uid(engine)` | Inspection helpers |
| `uid_of(zone, id)` / `sorted(array)` | First uid with that id (or -1); a sorted copy for order-free comparisons |
| `arrange(zone, ids_top_first)` | Puts those cards on top of the zone, top first; the rest stay below |
| `settle(engine, ids)` / `to_frontier(engine, ids)` | Moves those territory copies from `territory_deck` to the tableau / frontier |
| `put_in_hand(engine, id)` | Puts a new copy in the hand (via `create_card`) and returns its uid |
| `check_cases(cases, load)` | Table-driven loader validation: rows `[label, input, fragment(s), kind]`, kind `errors` / `one_error` / `warnings` / `warning_only` |
| `play_research(engine)` | Puts a Research card (`study`) in hand and plays it, revealing techs (backlog 034) |

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
- **Balance** is not tested: run `scripts/sim.sh` (or the `balance` skill) and compare with `main`.
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
