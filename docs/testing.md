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
| `tests/test_data_loader.gd` | JSON parsing, validation errors and warnings |
| `tests/test_rules.gd` | `GameEngine`: setup, actions, turn loop, scoring, game end |
| `tests/test_play_outcome.gd` | `GameEngine.card_played`: the outcome reported for each play |
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

The runner creates a fresh instance for every `test_*` method, so tests don't share state.

### Available in every test (`tests/lib/test_case.gd`)

| Name | Use |
|---|---|
| `eq(actual, expected, what)` | Equality. Always pass `what` so failures say which value was wrong |
| `check(cond, message)` | Boolean assertion |
| `has_msg(messages, fragment)` | Some loader error/warning contains `fragment` |
| `make_engine(deck, overrides, seed)` | New game from `TEST_CARDS`; `deck` is `{id: count}`; `overrides` replace config keys |
| `TEST_CARDS` | Small, stable card set (includes territories `grassland` and `hills`). Add cards here when a test needs a new shape |
| `keywords()` | Keyword ids the `TEST_CARDS` territories use; pass to `parse_cards` |
| `raw_config(deck, overrides)` | Config dictionary for loader tests |
| `card_ids(zone)` / `first_in_hand(engine)` | Inspection helpers |

Add a helper to `test_case.gd` once two test files need it.

### Guidelines

- **One behavior per test**, named for the behavior: `test_cannot_afford`, not `test_play_card_2`.
- **Concrete numbers** that match the acceptance criterion, with the arithmetic in the `what`
  string (`"food carries over + capital 2 + farm 1"`).
- **Deterministic**: use `make_engine`'s seed (default 1). To reproduce a bug from the UI, use
  that game's seed.
- **Test through the public API** (`play_card`, `end_turn`, `play_error`, `score`, zones,
  signals). Setting state directly (`e.resources.food = 1`) is fine for setup.
- **Real data** is only checked by `test_real_data_loads`. Don't assert on balance numbers from
  `data/cards.json`.
- **Signals**: connect a lambda that appends to an array, then assert on the array
  (see `test_game_ends_at_turn_limit`).
- **Loader errors**: assert the message names the file, card and field, since that is the
  user-facing contract.
