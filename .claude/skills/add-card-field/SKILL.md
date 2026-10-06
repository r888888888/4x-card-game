---
name: add-card-field
description: Recipe for adding a new field to card data (a key on a card in data/cards.json, such as defense, training, tier or administers) test-first. Covers DataLoader.TYPE_FIELDS and INT_FIELDS, the CardDef var, the type's parse function in CardTypeFields, the card text and details term, loader tests, a content invariant, and PLAN.md's card data format. Use when a backlog item needs a card to carry a value no existing field holds. Not for a new effect op (add-effect) or a config field.
---

# Add a card field

Use this inside the `tdd` skill's phases: step 1 belongs to Red, steps 2–5 to Green, step 6 to closing the item.
Fields to copy from: an integer (`training`, 164; `administers`, 319), a string naming another card (`upgrade_of`, 300),
an object (`raid`, 162; `cost_per_territory`, 320).

## Red

1. **Loader tests**, in the feature's test file (`tests/test_<area>.gd`; fixtures go in a const there, or a
   `tests/lib/` case if a second file needs them):
   - the field loads on each type it applies to, and its default when left out: a `check_loads` row each (340);
   - each bad value is an error naming the card and the field, and the field on another type is the warning
     "'<field>' only applies to <types> (ignored)": `check_cases` rows (`"warning_only"` for the warning);
   - an integer field needs no rows of its own for its minimum and default: adding it to `INT_FIELDS` puts it in
     `test_data_loader::test_every_int_field_on_every_type_has_its_minimum_and_default`, whose `INT_FIELD_CASES`
     gets a row `[field, type, min, default]` per type;
   - if it refers to another card (an id), an unknown or wrong-type card is an error from the cross-card pass;
   - its card text: `rules_text(cards)` and `rules_tooltip(cards)` equal the expected strings.

## Green

2. **The table**, `engine/data_loader.gd`: add the field to `TYPE_FIELDS` with the types that take it, the type it is
   for first (that one names the warning). An integer field also goes in `INT_FIELDS`, `{"min": …, "default": …}`
   (a default by type when it differs, `REQUIRED` when it must be given): `_read_int_fields` reads it, so it needs no
   code of its own.
3. **The var**, `engine/card_def.gd`: `var <field>: <type> = <default>  # <types>: what it means (<item id>)`, the
   same name as the JSON key (`_read_int_fields` sets it by name). CardDef is shared data, never copied per game:
   don't put game state on it.
4. **Its parse**, `engine/card_type_fields.gd` (not an integer): read it in the type's function (`_building`, `_event`,
   …), with `Fields.read_string` / `Fields.read_int` or a `_<field>(raw, errs)` helper for an object; errors name the
   field. A check across cards (an id that must exist) goes in `DataLoader.parse_cards`' second pass.
5. **Its text**: a `<field>_text()` on CardDef, added to `rules_text` and `rules_tooltip` where the type's lines go.
   UI text never names content: the UI shows what CardDef returns. If the field is a mechanic the player needs
   explained, add its term to `Glossary.TERMS` and to `CardDetails._terms` for the type.

## Close

6. **Docs and content**: PLAN.md's card data format (the field, its types, range and default, the item id). If the real
   data uses the field, add an invariant to `tests/test_content.gd` (every Barracks-like card has it, in range), never
   an exact number from `data/`; per-card facts go under the item's Manual check.
