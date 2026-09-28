---
id: 027
title: Tech eras (add_era) and extra research charges (Library)
type: feature
status: red-review
branch: feat/027-tech-eras
---

## Goal
Techs come in eras, and the player chooses when to move forward: some techs or buildings add the next
era's techs to the research deck. An empty research deck adds the next era by itself, and a tech that
adds an era can never be lost, so no era is ever out of reach. A Library gives a second research each
turn. Depends on 025 and 026.

## Acceptance criteria
Fixtures from 025 and 026, plus:
- `philosophy`: "Philosophy", tech, era 1, cost 3 wealth, play: `add_era` 2
- `optics`: "Optics", tech, era 2, cost 4 wealth
- `astronomy`: "Astronomy", tech, era 2, cost 5 wealth
- `academy`: "Academy", building, cost 1 food, play: `add_era` 2
- `library`: "Library", building, cost 1 food, ⟳ +1 research (`research` op)

Unless stated otherwise, the config has
`research_deck: {pottery: 1, philosophy: 1, optics: 1, astronomy: 1}` and starting resources
`{food: 5, wealth: 20}`.

- [ ] AC1 (loader):
  - Card field `era` is an integer ≥ 1 and defaults to 1. On a card that isn't a tech it is a warning
    (ignored).
  - The `add_era` op needs `era`, an integer ≥ 2; anything else is a load error that names the card,
    the effect and `era`.
  - The `research` op takes `amount`, an integer ≥ 1 (default 1).
  - Short texts: "Adds era 2 techs" and "⟳ +1 research".
- [ ] AC2 (setup): In a new game, only era-1 techs are in the research deck (Pottery and Philosophy).
  Optics and Astronomy wait in `future_techs`. `era()` is 1.
- [ ] AC3 (add an era once): Buying Philosophy shuffles Optics and Astronomy into the research deck,
  and `era()` is 2. Then playing an Academy (`add_era` 2 again) changes nothing: the research deck
  size stays the same and `era()` stays 2. The effect works the same on a building: an Academy played
  first adds era 2.
- [ ] AC4 (empty deck adds the next era): Given an empty research deck, era 1, and era-2 techs still in
  `future_techs`, `research_error()` is "". `research()` adds era 2, then reveals 2 of its techs, and
  `era()` is 2. With an empty research deck and no eras left to add, `research_error()` is "The research
  deck is empty."
- [ ] AC5 (era techs can't be lost): When Philosophy is passed a third time, it goes back to the
  research deck instead of `lost_techs`, with passes still 2 and cost 1.
- [ ] AC6 (Library): Given a Library on a territory with a free worker, the next turn starts with
  `research_left()` 2, and I can research, buy or decline, and research again. An idle Library
  (not enough pop) adds nothing: `research_left()` is 1. A Library built this turn adds nothing until
  the next upkeep. Unused charges don't carry over: a turn with 2 unused is followed by a turn with 2,
  not 4.
- [ ] AC7 (research op outside upkeep): A play effect `research` 1 (fixture action `study`: "Study",
  no cost) adds a charge at once. With 0 charges left, playing Study makes `research_left()` 1.

## Out of scope
- An era affecting the event/threat deck. That waits for the threat design.
- A UI era track beyond showing `era()`.
- Real content (028).

## Design notes
- Card field `era` (techs). Config stays one flat `research_deck`; each tech's `era` decides when it
  enters.
- New zone `future_techs`: techs from eras not yet added.
- New ops (follow the `add-effect` skill):
  - `add_era` {era}: if that era hasn't been added, shuffle its techs from `future_techs` into the
    research deck
  - `research` {amount}: add charges.
- Engine API: `era() -> int` (the highest era added; 1 at start), and `add_era(n, source)` as the
  helper the op calls.
- The engine records which eras have been added, so the effect only works once per era. An `add_era`
  of 3 before 2 adds only era 3's techs; `era()` is then 3. Rare in content, and allowed.
- Automatic next era: `research()` with an empty research deck adds the lowest era not yet added.
- A tech with any `add_era` effect is never moved to `lost_techs`. Once it has 2 passes, further
  passes change nothing.
- Charges: `_start_turn` resets them to 1 and then runs upkeep, so staffed Libraries add to them. Idle
  buildings already skip upkeep.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_tech_eras::test_era_defaults_to_1_and_loads`, `test_era_below_1_is_an_error`, `test_era_on_a_card_that_is_not_a_tech_is_a_warning`, `test_add_era_loads`, `test_add_era_needs_an_era`, `test_add_era_1_is_an_error`, `test_research_op_loads_with_a_default_amount`, `test_research_amount_below_1_is_an_error`, `test_era_and_research_card_text` |
| AC2 | `test_only_era_1_techs_start_in_the_research_deck` |
| AC3 | `test_buying_an_era_tech_adds_the_next_era`, `test_an_era_is_only_added_once`, `test_a_building_can_add_an_era` |
| AC4 | `test_an_empty_research_deck_adds_the_next_era`, `test_an_empty_research_deck_with_no_eras_left_is_an_error` (already passes: guards 025) |
| AC5 | `test_an_era_tech_is_never_lost` |
| AC6 | `test_a_staffed_library_gives_a_second_research`, `test_an_idle_library_gives_nothing`, `test_a_library_adds_nothing_until_the_next_upkeep`, `test_extra_research_does_not_carry_over` |
| AC7 | `test_a_played_research_card_adds_a_charge_at_once`, `test_a_research_card_adds_to_the_charges_left` |

## Manual check
- [ ] Buying an era tech shows the research deck count jump and the era change.
- [ ] With a staffed Library, the Research button shows 2 charges.

## Log
