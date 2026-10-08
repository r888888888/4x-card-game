---
id: 415
title: Ploughed Fields frees its Farm's worker instead of making food
type: feature
status: in-progress
branch: feat/415-plough-frees-a-worker
---

## Goal
Ploughed Fields (The Plough) is a +2 food upgrade with no slot, worker or upkeep, so it belongs on every Farm as soon
as there is wealth for it: a click per Farm, not a choice. Since 406, food is no longer the scarce resource either.
After this, Ploughed Fields makes no food. It frees its Farm's worker: a ploughed Farm works with no pop, and that pop can
staff another building. The Plough becomes a labour tech, as its flavor already says ("The village must find other
work"). You plough when a territory is short of workers, not when you have spare wealth, and it pairs with 414's
specialised farm territories: Farm and Irrigation Canals with a workshop still staffed beside them.

## Acceptance criteria
Fixtures: `TEST_CARDS` Farm (tag `farm`, ⟳ +1 food) plus Yoke: `{"id": "yoke", "name": "Yoke", "type": "building",
"cost": {"wealth": 1}, "upgrade_of": "farm", "frees_worker": true}`, in the build menu. Population on.

- [ ] AC1 (frees the worker): Given Homeland with pop 2 and 3 slots holding a Farm and one other building, both
  working, when Yoke is built on the Farm, then `free_workers(homeland)` goes from 0 to 1, a third building can be built
  there, and all three work. `is_idle` is false for each of them.
- [ ] AC2 (works with no pop): Given Homeland holding a Farm with a Yoke, when Homeland's pop falls to 0, then the Farm
  is not idle, Yoke's `fallen_back_reason` is "", and the next upkeep gains the Farm's 1 food. A Farm without a Yoke on
  the same territory, built after it, is idle. Workers still go to the other worker-using cards in tableau order, with
  the ploughed Farm skipped.
- [ ] AC3 (still takes a slot): Given a Farm with a Yoke that is past its territory's slots (a slot was lost), then it
  is idle as today, and Yoke falls back ("Its Farm is idle."). A Yoke never makes room for a building past the slots.
- [ ] AC4 (taking it away): Given AC1 after the third building, when the Yoke is abandoned (`abandon`, 412), then the
  Farm uses a worker again, `free_workers` is 0, and the last of the three in tableau order is idle. `upkeep_forecast`
  agrees with the upkeep that follows, before and after.
- [ ] AC5 (loader): `frees_worker` is an optional boolean on buildings (`DataLoader.TYPE_FIELDS`), default false;
  another type is warned about as for any building field. Load errors naming the file, card and field: `frees_worker`
  on a building with no `upgrade_of` ("frees_worker: only an upgrade can free its base's worker"), or with a `tier`
  ("frees_worker: an upgrade that frees a worker can't need a tier"), or whose `upgrade_of` names an upgrade, which
  uses no worker of its own ("frees_worker: 'x' is an upgrade and uses no worker").
- [ ] AC6 (card text): Yoke's generated rules include the line "Frees its Farm's worker." (so its face reads "Also
  frees its Farm's worker."), and its details explain it: "Its Farm needs no worker: it works with no pop there, and
  that pop can work another building." A building without the field reads as today.

## Out of scope
- Other labour-saving upgrades (a Harbor or Timber Camp freeing a worker). Later content items can use the field.
- The bot: it already lists upgrade builds (303). See the Design notes for what it can and can't see.
- Balance tuning beyond the numbers below; a sim run belongs to the user (Manual check).

## Design notes
- **Data format.** New building field `frees_worker` (bool) in `DataLoader.TYPE_FIELDS` for `CardDef.BUILDING`, parsed
  in `CardTypeFields` into `CardDef.frees_worker` (follow the `add-card-field` skill). No new effect op.
- **The rule.** A building uses a worker unless an upgrade with `frees_worker` is built on it. This depends on the
  upgrade being in the tableau, not on it working, so there is no loop (the upgrade only works while its base works).
  That makes `uses_worker` a question about the instance, not the def: `Territories.workers_on`, `Population.idle_uids`
  and `is_idle`, `Fallback.reason`, `CardDetails` and `CardPlay` all call `def.uses_worker()` today. A per-card check
  (for example `Population.uses_worker(e, card)`) replaces them, and `CardDef.uses_worker()` stays the "could ever use
  one" answer. The ploughed Farm still takes its slot, so the slot half of `idle_uids` is unchanged.
- **Why no tier, and no upgrade base.** A tier would let the upgrade fall back while its base still works, and the
  worker would then depend on the territory's tier. An upgrade base uses no worker, so freeing one means nothing. The
  loader refuses both rather than give them a rule.
- **Data (`data/cards.json`), agreed 2026-10-08:** Ploughed Fields costs 3 wealth (no food:
  `test_only_food_buildings_cost_food_and_at_most_1`), has no effects and no tags (it drops `farm`, since it makes no
  food: Sumer's and the eurekas' farm counts stop counting it), and has `"frees_worker": true`. The Plough keeps its
  eureka (2 Pastures: the oxen come from the herd, and Irrigation, Pottery, Fermentation and Calendar already count
  farms). Flavor stays; it already says this.
- **The bot.** GenericBot values a position by its `turn_forecast`, so it sees a Yoke that un-idles a building there
  now (pop lost, or more buildings than pop). It does not see "plough, then build another building here" as one plan,
  so it may build Ploughed Fields less often than a player would. That's acceptable for now; note what the sim shows.
- **Text.** `CardDef.face()` adds the rules line "Frees its %s's worker." (the base's name) and the details term above.
  The UI's "Also" prefix (302) does the rest.
- PLAN.md: 305's Rural upgrades line (Ploughed Fields), 406's food line ("Ploughed Fields +2"), and the card data
  format (the new field). `docs/design/card-art.md`'s Ploughed Fields brief if it mentions food.

## Test plan
All in `tests/test_frees_worker.gd`.

| AC | Test |
|---|---|
| AC1 | `test_a_yoke_frees_its_farms_worker_for_another_building` |
| AC2 | `test_a_ploughed_farm_works_with_no_pop`, `test_workers_skip_the_ploughed_farm` |
| AC3 | `test_a_ploughed_farm_past_the_slots_is_idle_and_its_yoke_falls_back` |
| AC4 | `test_abandoning_the_yoke_takes_the_worker_back` |
| AC5 | `test_frees_worker_loads_on_an_upgrade`, `test_bad_frees_worker_fields_are_load_errors` |
| AC6 | `test_a_yoke_says_it_frees_its_farms_worker` |

## Manual check
- [ ] `data/cards.json`: Ploughed Fields costs `{ "wealth": 3 }`, has `"frees_worker": true`, no effects and no tags.
  The Plough still unlocks it, with its eureka at 2 Pastures.
- [ ] New game with a fresh-water home: build a Farm and a second building until the pop is all at work. A Farm's
  details offer Ploughed Fields under Upgrades, reading "Frees its Farm's worker."; build it, and the territory shows
  a free worker and the Build menu offers another building there.
- [ ] A ploughed Farm keeps working (and feeding) after a Famine takes its territory's last pop.
- [ ] Balance (the user runs it): `scripts/sim.sh --level 3 --compare <main checkout>`. Watch how often the bot builds
  Ploughed Fields, food per civ (it loses +2 per ploughed Farm) and buildings per territory.

## Log
- 2026-10-08: specced from a design discussion (option A of: labour saving, mixed farming, new land, a deck card, a
  tech passive). Agreed with the user: no food left on it, a ploughed Farm works with 0 pop, eureka stays 2 Pastures.
  Assumed, not asked: it drops the `farm` tag; the loader refuses `frees_worker` with a tier or on an upgrade's
  upgrade; the cost is 3 wealth.
- 2026-10-08: red tests written (this item was specced in another session; the file was uncommitted on main and
  is committed here). The AC3 slot test passes already: a building past its slots is idle today, and the test keeps it
  so once the worker rule changes. `term_names` and `term_text` moved from `test_card_details.gd` to
  `tests/lib/test_case.gd`. AC6's details text is a generated term named "Frees a worker" (it names the base). The
  real data change (Ploughed Fields) has no test of its own beyond the loader and content suite; its numbers are
  under Manual check.
