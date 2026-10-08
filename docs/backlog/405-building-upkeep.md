---
id: 405
title: Buildings cost wealth upkeep - a shortfall adds unrest
type: feature
status: review
branch: feat/405-building-upkeep
---

## Goal
Buildings have a running cost, so a bigger tableau drains wealth each turn and a stronger food economy (406) has
something to pay for. Each working base building pays its upkeep in wealth after all upkeep production, the way pop
eats food. A wealth shortfall brings unrest, just as a food shortfall brings Famine.

## Acceptance criteria
Fixtures: `TEST_CARDS` buildings with no upkeep effects (Hut, Shed), one with ⟳ +2 wealth (Mint Hut), one with
`upkeep: 2` (Big Hall), one with `upkeep: 0` (Free Shed), an upgrade on Hut and a 10-wealth project. The config has
`building_upkeep: 1`, unless a criterion says otherwise.

- [x] AC1 (default upkeep): Given Hut and Shed working and 5 wealth, when upkeep runs, then wealth is 3 and unrest is
  unchanged.
- [x] AC2 (per-card upkeep): Given Hut, Big Hall and Free Shed working and 5 wealth, when upkeep runs, then wealth is 2
  (1 + 2 + 0).
- [x] AC3 (who doesn't pay): Given Hut working with an upgrade built on it, a second Hut idle (its territory short of a
  worker), an unfinished project site, a completed project and the Capital, all with 5 wealth, when upkeep runs, then
  wealth is 4: only the working Hut pays. Without `building_upkeep` in the config (rules off) nothing pays, and every
  existing test's numbers stay the same.
- [x] AC4 (production first): Given Mint Hut working and 0 wealth, when upkeep runs, then wealth is 1 (+2, then −1)
  and unrest is unchanged.
- [x] AC5 (shortfall): Given Hut, Shed and Big Hall working (upkeep 4), 1 wealth and unrest 0 with limit 8, when upkeep
  runs, then wealth is 0 and unrest is 3. With unrest 7, unrest stops at the limit, 8.
- [x] AC6 (forecast): In AC1's and AC5's setups, `upkeep_forecast()` reports wealth −2 (AC1), and wealth −1 with unrest
  +3 (AC5), before upkeep. The game state is unchanged, and the forecast matches what upkeep then does.
- [x] AC7 (loader): A building's `upkeep` must be an int ≥ 0. A negative or non-int value, `upkeep` on a non-building, or
  `upkeep` on an upgrade or a project is a load error naming the file, card and field. The config's `building_upkeep`
  must be an int ≥ 0 (error names `config.json` and the field). Absent, it is 0.
- [x] AC8 (card text): Hut's rules text ends with an upkeep line, "⟳ Upkeep 1 wealth". Big Hall's reads "⟳ Upkeep 2
  wealth". Free Shed, an upgrade and a project have no upkeep line.

## Out of scope
- The shipped numbers: farm and fishing food, upkeep on the real data, and the design pass on every building (406).
- Selling or disbanding a building to save upkeep.
- Upkeep in any resource but wealth.

## Design notes
- Data: config `building_upkeep` (int ≥ 0, wealth, default 0). Building field `upkeep` (int ≥ 0) overrides it per
  card. It goes in `DataLoader.TYPE_FIELDS` and `INT_FIELDS` (follow the `add-card-field` skill). The loader resolves
  each base building's effective upkeep into `CardDef.upkeep` (config default unless the card sets its own), so card
  text and queries read one number. Upgrades and projects are always 0.
- Engine: a new upkeep step after pop eats food (PLAN's turn loop step 1). The working base buildings' upkeep is summed
  and paid from wealth through `lose` (never below 0). The unpaid remainder is added to unrest through `set_unrest`, so
  the limit caps it, and a capped shortfall can then set off the Anarchy check. Idle buildings and fallen-back ones pay
  nothing, decided at the same point as idleness (before pop eats). A query, `building_upkeep_due()`, gives the total
  owed for the UI and the forecast. Log: "Buildings' upkeep: −3 wealth." and, when short, "Upkeep short 2 wealth:
  +2 unrest."
- The forecast runs upkeep on a fork, so it picks up the new step. GenericBot weighs forecast wealth and the unrest
  coming in (321), so it sees the drain and the shortfall risk with no bot change.
- Order relative to Famine: food feeding stays first. The wealth step comes after it, before era unlocks.
- PLAN.md: the Resources row, turn loop step 1 and the Population section get the new step.

## Test plan
All in `tests/test_building_upkeep.gd` unless named.

| AC | Test |
|---|---|
| AC1 | `test_each_working_building_pays_the_default_upkeep_in_wealth` |
| AC2 | `test_a_cards_own_upkeep_replaces_the_default` |
| AC3 | `test_upgrades_projects_idle_buildings_and_the_capital_pay_nothing`, `test_without_building_upkeep_in_the_config_nothing_pays` |
| AC4 | `test_upkeep_production_pays_before_the_buildings_upkeep` |
| AC5 | `test_an_upkeep_shortfall_adds_the_unpaid_wealth_as_unrest`, `test_shortfall_unrest_stops_at_the_limit` |
| AC6 | `test_the_forecast_includes_the_buildings_upkeep`, `test_the_forecast_includes_a_shortfalls_unrest` |
| AC7 | `test_the_config_resolves_each_base_buildings_upkeep`, `test_bad_upkeep_fields_are_load_errors`, `test_a_bad_building_upkeep_in_the_config_is_a_load_error`, `test_data_loader::test_every_int_field_on_every_type_has_its_minimum_and_default` (an `upkeep` row) |
| AC8 | `test_a_paying_buildings_text_ends_with_its_upkeep_line`, `test_buildings_that_pay_nothing_have_no_upkeep_line` |

## Manual check
The real data sets no `building_upkeep` yet (406 does), so these need a config with `"building_upkeep": 1` added to
`data/config.json` locally (don't commit it), then `godot --path . -- --seed 5`.
- [ ] The top bar's wealth forecast includes the buildings' upkeep. Build a second building and the "(+n)" drops by 1.
- [ ] A building's card face and details show "⟳ Upkeep 1 wealth"; an upgrade's ribbon shows none.
- [ ] Run broke with buildings: the turn's log shows the shortfall and the unrest forecast shows it a turn ahead.

## Log
- 2026-10-08: red tests written. Resolved at red: a card's own `upkeep` pays even with no `building_upkeep` in the
  config (AC3's "rules off" is the config default); `upkeep` on a non-building is the usual loader warning ("only
  applies to buildings (ignored)"), not an error; a building's `upkeep` reads -1 (the config's) until `parse_config`
  resolves it.
- 2026-10-08: green. `upkeep` is in `TYPE_FIELDS` / `INT_FIELDS` (default -1); `CardTypeFields.resolve_upkeep`, called
  from `ConfigLoader.parse_config`, fills it in (it lives there because `config_loader.gd` is at its 450-line cap). The
  step is `TurnLoop.building_upkeep_due` / `pay_building_upkeep`, run from `_settle_in` and from
  `UpkeepBreakdown.ledger` (rows "Buildings' upkeep" for wealth and "Upkeep short" for unrest), so `upkeep_forecast`,
  the counters' popover and `turn_forecast` (GenericBot) all see it. Follow-up: the glossary's "Upkeep" term still says
  only "every card with an upkeep effect resolves it"; worth a line on building upkeep when 406 turns it on. Balance:
  none of this changes the real game until 406 sets `building_upkeep`; check it there with
  `scripts/sim.sh --level 2 --compare <main checkout>`.
