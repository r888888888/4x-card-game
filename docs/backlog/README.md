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
Everything planned so far is done (through 367: military, settlement tiers, the build menu, building upgrades, the
generic sim bot, the 2026-10-06 review cleanup and the coast). The order of closed items is in
[done/HISTORY.md](done/HISTORY.md).

In progress on a branch (not on `main` yet):
- 324 day-mode load-error text (`fix/324-day-mode-load-error-text`, red-review)
- 384 simpler Anarchy (`feat/384-simpler-anarchy`, red-review); 385 and 386 follow from it
- 395 text colours follow Day mode (`fix/395-text-colours-follow-day-mode`, in progress)
- 379 resource breakdown popover (`feat/379-resource-breakdown-popover`, branch started; item still `ready`)

Not yet prioritized (all `ready`; pick an order before building):
- Top bar: 379 click a resource counter for its next-upkeep change by source, 380 click Score or Pop for what makes it up
- Card faces: 382 one Unlocks line, a ledger of figures and gates as fine print; 383 overflowing text cuts at a whole
  rule, hover shows the rest
- Government: 385 Renewal is a free action during Anarchy, 386 a fifth Anarchy turn that doesn't end it loses the game
- Military UI: 387 upgrade a building from its details modal, 388 veteran pips on unit cards
- Refactors: 392 main.gd's test hooks move to a test-side probe, 393 GameTheme split into one file per component,
  394 engine areas (military actions and queries move to `engine.military`)
