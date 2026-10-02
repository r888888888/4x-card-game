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

149's balance pass can cover the reworked unrest (155–159 are done).

Barbarians and military (units are homed on a territory, using a worker there, and stationed where they defend):
1. 160 unit cards garrisoned on a home territory
2. 161 territory defence from units, walls, cities and terrain
3. 162 barbarian raids, announced a turn ahead
4. 163 move and disband units
5. 168 the sim bot meets raids (before more military, so the sim stays meaningful)
6. 164 Barracks training, then 165 veterans, then 166 upgrades
7. 167 era units and era 2–3 raids

Board and screens redesign (from `docs/design/transitions.html` and `mcm-specimen.html`; specced 2026-10-02):
1. 197 Day-mode card text fix, 198 bold card names, 199 Realm territory cards without keywords, 200 click outside
   closes the territory view (small and independent)
2. 207 modals as the specimen's sheets (before 205 and 206, which add modals)
3. 206 Settings modal, then 205 Revolt in the civilization modal with its confirmation
4. 202 the right sidebar, then 203 End turn at its foot, then 201 the resource strip, and 204 the In Hand heading
5. 208 Knowledge screen (after 202, so the Realm's shift includes the sidebar's layout)
6. 209 cabinet doors, 210 vellum targeting, 211 era ceremony (any order)
7. 212 civilization list and detail; 213 title screen ledger and large keys, then 214 its sunrise art

Not scheduled: 149 balance pass for the action economy, Insight and Unrest (draft: its scope questions are open).
