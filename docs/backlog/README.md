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
Everything planned so far is done (through 412: Anarchy and the honeymoon, the test probe, the theme sections, engine
areas, the top-bar breakdowns, sim speed, card faces, veteran pips, abandoning buildings, building upkeep and the
food rebalance). The order of closed items is in [done/HISTORY.md](done/HISTORY.md).

Sumer and the farms (407 ships right after 406, so Sumer never plays long on 406's numbers):
1. 407 Sumer as the breadbasket (content)
2. 414 Irrigation Canals and Salt Pans boost the farms and huts on their own territory (`gain_per_tag` learns
   `where: here`; after 407, which also counts farms)

Rival claimants (a `spike/rival-claimants` may come first):
3. 400 the `strength` modifier
4. 401 claimants dealt at the fall, backed each Anarchy turn; the best-backed takes the court
5. 413 the court's passive, once per rank, rising every 10 turns
6. 403 claimant eras and the incumbent: successors per era, loyal wins keep rank
7. 404 the claimants: five factions for wide, tall, research, coastal and military play (content; art after)
