---
id: 092
title: Research card name from the engine; content tests assert invariants only
type: feature
status: ready
branch: feat/092-content-invariants
---

## Goal
The side panel and the tech tree say "Play an Insight card", hard-coding a card name from `data/cards.json`, and
`test_content.gd` pins that name so a rename can't silently break the hint. About a dozen other content tests
pin single cards (Barter, Storyteller, Winnow, "6 techs in each era", …), against the rule that content tests
assert invariants only: a balance edit breaks them. Ask the engine for the name, turn the pinned tests into
invariants over the whole data set, and delete the rest (their facts stay in their done items).

## Acceptance criteria
- [ ] AC1: `research_card_name()` returns the name of the first card, in config `deck` order then `supply` order,
  with a `research` effect, or "" when there is none. Given `TEST_CARDS` with `{"farm": 5, "study": 1}` as the
  deck, it is "Research"; with `{"farm": 5}` and no supply, "".
- [ ] AC2: In the real `main.tscn`, the Knowledge button's tooltip and the tech tree header name
  `research_card_name()` ("Play a Research card …" on fixture data whose card is named "Research"), and with no
  research card the hint sentence is left out. `ui/` holds no card name from `data/cards.json` as a string
  literal: a check in `test_ui_structure.gd` reads every card name in the real data and fails naming the file and
  line of any quoted match.
- [ ] AC3: New invariants on the real data, each failing with the offending card or era named:
  - every building's `requires` is met by the starting territory or some territory in `territory_deck`;
  - the starting territory can take a building from the starting deck or an unlocked supply pile (extends
    `test_every_territory_can_take_a_building_from_the_start`);
  - every era with techs in `research_deck` has at least 2 of them (one reveal shows 2), and every era above 1
    is added by an `add_era` effect of a lower-era tech in `research_deck` or by `era_unlocks`;
  - every `add_era` effect and every `era_unlocks` key names an era with techs in `research_deck`;
  - every keyword a `gain_per_keyword` effect counts is printed on a territory in `territory_deck` or rolled by
    `territory_resources`.
- [ ] AC4: These tests are deleted (the invariants above or existing ones cover what isn't a per-card fact):
  `test_forage_and_harvest_festival_are_events`, `test_research_card_is_named_insight`,
  `test_research_deck_has_6_techs_in_each_of_eras_1_and_2`, `test_a_tech_unlocks_the_library`,
  `test_no_era_3_tech_is_researchable_or_added`, `test_era_3_techs_are_defined_but_not_in_the_research_deck`,
  `test_starting_territory_has_fresh_water`, `test_farm_requires_fresh_water_and_the_deck_has_it`,
  `test_farm_can_target_the_capitals_territory`, `test_caravan_trades_between_at_least_2_cities`,
  `test_barter_trades_food_for_wealth`, `test_storyteller_draws_cards_for_food`,
  `test_fishing_huts_quarry_and_shrine_are_early_buildings`, `test_early_cards_start_in_the_deck_or_an_open_supply_pile`,
  `test_hunt_gains_food_per_keyword_and_is_available_from_the_start`, `test_winnow_trashes_and_is_on_sale`.
- [ ] AC5: Apart from `real_engine`'s use of the config's own starting ids, no remaining test in `test_content.gd`
  names a card id from `data/` (checked by grep, noted in the Log). The real data still passes every invariant.

## Out of scope
- `test_real_events_are_neutral_or_beneficial`: it is an invariant today and 074 changes it on purpose.
- Changing any number in `data/`.

## Design notes
- New engine query `research_card_name() -> String` next to the research queries; the loop over effects checks
  `op == "research"` (as `_check_unlocks` does for `unlock`).
- The structural check in AC2 matches whole quoted strings or a name followed by " card", so words like "Market"
  in unrelated UI text don't trip it; tune at the red checkpoint if the real names collide with UI words.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->

## Manual check
- [ ] Hover Knowledge and open the tech tree (T): the hint names Insight, as before.

## Log
- 2026-09-30: Specced from the project review (UI names content; content tests pin cards). Per the review
  decision, pinned tests become invariants or are deleted.
