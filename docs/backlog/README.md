# Backlog

One Markdown file per feature or bug: `NNN-short-slug.md` (e.g. `004-market-zone.md`).
Open items live here; `done` and `wontfix` items move to [done/](done/) (same filename) when they close.
IDs are sequential across features and bugs and span both folders: the next id is the highest in either, plus 1. Copy a template from `_templates/`, or ask
Claude to create the item (the `spec` skill).

## Status flow

| Status | Meaning | Who moves it on |
|---|---|---|
| `draft` | Idea captured; a behavior question is still open | You answer it → `ready` |
| `ready` | Criteria written; can be picked up (you review them at `red-review`) | Claude starts → `in-progress` |
| `in-progress` | Branch exists; work underway | Claude writes failing tests → `red-review` |
| `red-review` | Failing tests written; waiting for your review | You approve → `in-progress` (green phase) |
| `review` | Green, refactored, verified; waiting for your final look (and manual UI check, if any) | You accept → `done` |
| `done` | Merged to `main` | — |

Other statuses: `blocked` (say why in the Log) and `wontfix`.

## See the board

```bash
grep -H '^status:' docs/backlog/[0-9]*.md
```

That lists open items only. Add `docs/backlog/done/[0-9]*.md` to include closed ones.

## Writing good acceptance criteria

Each criterion should become one or more tests. Write it as Given / When / Then with
concrete numbers from the rules:

- Good: *Given 3 food and a Farm (cost 2) in hand, when I play it, then food is 1 and the Farm is on the tableau.*
- Too vague: *Farms should cost food.*

Put anything you can only judge by eye (layout, feel, animation) under **Manual check**.

## Planned order

Build in this order; IDs are creation order, not build order. Each item assumes the ones before it are done.
The order of the 100+ items already closed is in [done/HISTORY.md](done/HISTORY.md).

Barbarians and military (units are homed on a territory, using a worker there, and stationed where they defend):
1. 160 unit cards garrisoned on a home territory
2. 161 territory defence from units, walls, cities and terrain
3. 162 barbarian raids, announced a turn ahead
4. 163 move and disband units
5. ~~168 the sim bot meets raids~~: superseded by 314 (the generic bot defends through its value)
6. 164 Barracks training, then 165 veterans, then 166 upgrades
7. 167 era units and era 2–3 raids


Settlement tiers (pop sets a territory's tier, which adds slots; governments tolerate tiers up to one):
1. 281 settlement tiers add building slots, and buildings past the slots go idle
2. 282 governments tolerate territories up to a tier; bigger ones add unrest
3. 283 growth "where needed most" prefers a territory one pop short of its next tier

Build menu (buildings and units leave the deck: techs unlock them, you build them onto a territory):
1. 295 buildings are built from a build menu instead of bought
2. 296 units are recruited from the build menu
3. 299 preview what building an entry on a territory would change
4. 297 Build… on a territory's view: the list-and-forecast modal, and "+ Build" on empty slots
5. ~~298 the sim bot builds, recruits and keeps Settlers~~: superseded by 314 (`build` joins `legal_actions`); then a
   balance item for costs and wealth

Building upgrades (upgrades build onto a building, add to it, and may need a settlement tier; makes tall worth it):
1. 300 upgrades built onto buildings: no slot or worker, they add to their base, stack and chain
2. 301 a building or upgrade may need a tier, and falls back below it (returns by itself)
3. 304 the `gain_per_pop` op (independent; needed by 306)
4. 302 ribbons on the territory view, "+ Upgrade", the Build modal's Upgrades heading (after 297)
5. ~~303 the sim bot builds upgrades~~: superseded by 314
6. 305 rural upgrades and realism fixes, 306 Temple and Library become urban upgrades, 307 new urban chains, 308 gap
   buildings (then a balance item for the whole roster)

Generic sim bot (from `spike/generic-bot`: one value function over every legal action instead of a rule per mechanic):
1. 309 `turn_forecast`, 310 targets from any zone, 311 sample fork (independent engine queries)
2. 312 `legal_actions` with a coverage check
3. 313 `GenericBot` plays as the strategy `generic`
4. 314 it replaces ScriptedBot (generic, wide, tall; rollouts in cheap mode; raids), closing 168, 298 and 303
5. 315 forecast cache (then a balance item re-baselines the sim)
