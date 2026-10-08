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

Order chosen to minimize churn: finish what has red tests, then the three refactors that every later item would
otherwise write against the old shape and then rewrite, then the features in the order their shared pieces appear.

Finish first (red tests already written; 392 renames their calls when it lands):
1. 324 day-mode load-error text (`fix/324-day-mode-load-error-text`, red-review)
2. 384 Interregnum: Anarchy lasts a fixed 3 turns (`feat/384-simpler-anarchy`; redesigned 2026-10-07, so its red
   tests are rewritten before the next red-review)

Refactors (before the features, which would add to what they move):
3. 392 main.gd's test hooks move to a test-side probe. First: 379's red tests already add three hooks to main
   (`breakdown_key`, `breakdown_rows`, `counter`), and every UI item below adds more.
4. 393 GameTheme split into one file per component. Before 379 (the Popover look), 382 (Ledger, FinePrint), 383 (the
   sheet and meter) and 388 (pips) add looks to `game_theme.gd`, already past 500 lines.
5. 394 engine areas, military first. Before 388 adds `unit_veteran_pips` to `Military` (a forward 394 would remove),
   before 400 changes `Military.strength`, and before 385 and 401 add entries to `legal_actions`, whose dispatch 394
   changes.

Anarchy (builds on 384 while its code is fresh):
6. 385 Renewal is a free action during Anarchy (flat count, no unrest)
7. 399 a new government's honeymoon: 3 turns where unrest can't rise and no revolution

Top bar (379 brings the `Popover` that 380 and 383 reuse):
8. 379 click a resource counter for its next-upkeep change by source (`feat/379-resource-breakdown-popover` has its red
   tests; move their main calls to the probe)
9. 380 click Score or Pop for what makes it up

Food and building upkeep (prioritised 2026-10-08, ahead of the claimants):
10. 405 buildings cost wealth upkeep; a shortfall adds unrest (engine)
11. 406 Farm 4 food, Fishing Huts 3, Irrigation Canals and Salt Pans stand alone, the design pass on every building
    (content, after 405)
12. 407 Sumer as the breadbasket (content; ships with 406)

Rival claimants (after 379, so the court's passive joins its breakdown; a `spike/rival-claimants` may come first):
13. 400 the `strength` modifier (after 394)
14. 401 claimants dealt at the fall, backed each Anarchy turn; the best-backed takes the court
15. 402 the court's passive, once per rank, rising every 10 turns
16. 403 claimant eras and the incumbent: successors per era, loyal wins keep rank
17. 404 the claimants: five factions for wide, tall, research, coastal and military play (content; art after)

Card faces and details:
18. 382 one Unlocks line, a ledger of figures and gates as fine print (changes `rules_text` and `upgrade_rules_text`)
19. 383 overflowing text cuts at a whole rule, hover shows the rest (after 381, 382's face and 379's Popover)
20. 387 upgrade a building from its details modal (its rows read `upgrade_rules_text`, which 382 changes)

Military UI:
21. 388 veteran pips on unit cards (after 394, so the query goes on `engine.military`)
