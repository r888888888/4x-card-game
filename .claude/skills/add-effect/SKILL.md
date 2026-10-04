---
name: add-effect
description: Recipe for adding a new card effect op (an "op" in data/cards.json effects, such as gain, draw, create) to the engine test-first. Covers the loader validation tests, rules tests, the effect script, registry entry, and generated card text. Use when a backlog item or request needs a card to do something no existing op supports.
---

# Add a card effect op

Use this inside the `tdd` skill's phases: steps 1–2 belong to Red, steps 3–5 to Green.
Existing ops to copy from: `engine/effects/` (`gain`, `gain_per_tag`, `draw`, `create`, `score`), and their test
files (`tests/test_harmful_ops.gd`, `tests/test_gain_per_keyword.gd`, `tests/test_trash.gd`).

## Red

Put all of the op's tests in a new `tests/test_<op>.gd` (as 072, 081 and 082 did): loader rows and rules tests
together, so the op's behavior reads in one place.

1. **Loader tests** in `tests/test_<op>.gd`:
   - a card using the op with valid fields loads with no errors or warnings (a named test);
   - each missing or invalid field gives an error that names the card and field
     (e.g. `card 'x': effects[0]: 'amount' must be an integer >= 1`): one `test_<op>_validation` with a
     `check_cases` row per case (see `test_grow_validation`);
   - if the op refers to cards, resources, or zones, unknown names are errors.
2. **Rules tests** in the same `tests/test_<op>.gd`:
   - add a card that uses the op to `TEST_CARDS` in `tests/lib/test_case.gd`;
   - test the effect on `play`; if it may trigger on `upkeep`, test that too, and add it to `UPKEEP_SAFE`
     in `tests/test_forecast.gd` (otherwise to `UPKEEP_UNSAFE`, which expects the "only works on play" error);
   - test edge cases: zero or empty sources, not enough cards, interaction with reshuffle;
   - test the generated text: `cards[id].rules_text(cards)` (short, on the card) and
     `cards[id].rules_tooltip(cards)` (full wording, on hover) equal the expected strings.

## Green

3. Create `engine/effects/<op>_effect.gd` extending `Effect`:
   - `##` header comment showing the JSON shape, as in the existing files;
   - `fields()` lists every accepted key besides `op` and `trigger` (anything else becomes an
     "unknown field" warning);
   - `configure()` reads fields with `Fields.read_int` / `Fields.read_string`, validating against
     `ctx.resources` / `ctx.zones` where relevant;
   - `apply(engine, source)` calls a **public helper on the engine**. Don't manipulate zones or
     resources directly from the effect, so that logging, signals and the play outcome stay in one place.
     Add the helper to `engine/engine_core.gd` (`EngineCore`, at the root of `GameEngine`'s chain since 125) under
     "Helpers called by effects" if none fits; if the op changes
     something the `card_played` outcome reports (gained, vp, drawn, created, trashed), the helper records it
     there (`if not _outcome.is_empty(): …`, as `gain` and `create_card` do);
   - `describe()` returns short rules text, without the trigger prefix; override `describe_long()`
     if the tooltip needs fuller wording (it defaults to `describe()`);
   - `referenced_cards()` if the op names other cards, and `check_references(card_db, errors)` to check them once
     every card is loaded (e.g. their type);
   - `upkeep_ok()` returns `true` only if the op changes nothing but resources, bonus score and pop:
     nobody can choose or target during upkeep, and `upkeep_forecast` reports only resources and `starve`.
     Ops that move or make cards, use the RNG or open a choice keep the default `false`, and the loader
     rejects them on `upkeep`.
   - Consider each of the other `Effect` hooks (`engine/effect.gd`), and override the ones that apply:
     - `target_zone()`: the zone the player picks a target card from ("" if none);
     - `no_target_error()` / `choose_target_error()`: the `play_error` text when there is no valid target,
       or several and none was given;
     - `opens_choice()`: true if the op may leave a `pending()` decision (the loader then keeps it off
       `start`);
     - `needs_a_turn()`: true if the op only means something during the player's turn (`gain_actions`): the
       loader keeps it off `start` and off events, which resolve after the player's plays;
     - `needs_own_territory()`: true if the op acts on its own card's territory; the loader rejects it on
       techs, events and governments, which have none (and `start` triggers check targets and choices);
     - `play_block_error(engine, card)`: why the card can't be played right now (e.g. nothing to research);
     - `terms()`: glossary terms the op uses, listed in the card details.
4. Register the op in `EffectRegistry.OPS` (`engine/effect_registry.gd`).
5. Run `scripts/test.sh`. It re-imports automatically, so the new script is picked up.

## Afterwards

- Add the op to the card data format section of `PLAN.md` if it introduces a new field shape. If `upkeep_ok()` is
  true, add it to that section's list of ops that may use `upkeep`.
- Triggers are `play`, `upkeep` and `start` (062: civilizations only, once at `new_game`; no op that needs a target,
  opens a choice or needs a turn). If a new trigger is needed, that's a turn-loop change. Add it to
  `Effect.TRIGGERS`, test where in the turn it fires, and update the turn loop section of `PLAN.md`.
