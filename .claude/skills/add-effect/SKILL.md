---
name: add-effect
description: Recipe for adding a new card effect op (an "op" in data/cards.json effects, such as gain, draw, create) to the engine test-first. Covers the loader validation tests, rules tests, the effect script, registry entry, and generated card text. Use when a backlog item or request needs a card to do something no existing op supports.
---

# Add a card effect op

Use this inside the `tdd` skill's phases: steps 1–2 belong to Red, steps 3–5 to Green.
Existing ops to copy from: `engine/effects/` (`gain`, `gain_per_tag`, `draw`, `create`, `score`).

## Red

1. **Loader tests** in `tests/test_data_loader.gd`:
   - a card using the op with valid fields loads with no errors or warnings;
   - each missing or invalid field gives an error that names the card and field
     (e.g. `card 'x': effects[0]: 'amount' must be an integer >= 1`);
   - if the op refers to cards, resources, or zones, unknown names are errors.
2. **Rules tests** in `tests/test_rules.gd` (or `tests/test_effects.gd` if you're adding several):
   - add a card that uses the op to `TEST_CARDS` in `tests/lib/test_case.gd`;
   - test the effect on `play` and, if it makes sense, on `upkeep`;
   - test edge cases: zero or empty sources, not enough cards, interaction with reshuffle;
   - test the generated text: `cards[id].rules_text(cards)` equals the expected string.

## Green

3. Create `engine/effects/<op>_effect.gd` extending `Effect`:
   - `##` header comment showing the JSON shape, as in the existing files;
   - `fields()` lists every accepted key besides `op` and `trigger` (anything else becomes an
     "unknown field" warning);
   - `configure()` reads fields with `read_int` / `read_string`, validating against
     `ctx.resources` / `ctx.zones` where relevant;
   - `apply(engine, source)` calls a **public helper on `GameEngine`**. Don't manipulate zones or
     resources directly from the effect, so that logging and signals stay in one place. Add the
     helper to `game_engine.gd` under "Helpers called by effects" if none fits;
   - `describe()` returns short rules text, without the trigger prefix;
   - `referenced_cards()` if the op names other cards.
4. Register the op in `EffectRegistry.OPS` (`engine/effect_registry.gd`).
5. Run `scripts/test.sh`. It re-imports automatically, so the new script is picked up.

## Afterwards

- Add the op to the card data format section of `PLAN.md` if it introduces a new field shape.
- If a new trigger is needed (beyond `play` / `upkeep`), that's a turn-loop change. Add it to
  `Effect.TRIGGERS`, test where in the turn it fires, and update the turn loop section of `PLAN.md`.
