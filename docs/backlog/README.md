# Backlog

One Markdown file per feature or bug: `NNN-short-slug.md` (e.g. `004-market-zone.md`).
IDs are sequential across features and bugs. Copy a template from `_templates/`, or ask
Claude to create the item (the `spec` skill).

## Status flow

| Status | Meaning | Who moves it on |
|---|---|---|
| `draft` | Idea captured; acceptance criteria incomplete or unapproved | You approve the spec → `ready` |
| `ready` | Criteria agreed; can be picked up | Claude starts → `in-progress` |
| `in-progress` | Branch exists; work underway | Claude writes failing tests → `red-review` |
| `red-review` | Failing tests written; waiting for your review | You approve → `in-progress` (green phase) |
| `review` | Green, refactored, verified; waiting for your final look (and manual UI check, if any) | You accept → `done` |
| `done` | Merged to `main` | — |

Other statuses: `blocked` (say why in the Log) and `wontfix`.

## See the board

```bash
grep -H '^status:' docs/backlog/[0-9]*.md
```

## Writing good acceptance criteria

Each criterion should become one or more tests. Write it as Given / When / Then with
concrete numbers from the rules:

- Good: *Given 3 food and a Farm (cost 2) in hand, when I play it, then food is 1 and the Farm is on the tableau.*
- Too vague: *Farms should cost food.*

Put anything you can only judge by eye (layout, feel, animation) under **Manual check**.

## Planned order

Build in this order; IDs are creation order, not build order. Each item assumes the ones before it are done.

1. 044 repo housekeeping
2. 040 reshuffle test bug
3. 041 shared test helpers, content invariants
4. 042 balance simulator
5. 045 UI smoke test
6. 043 only forecast-safe ops on upkeep
7. 046 table-driven loader tests
8. 047 field readers and constants
9. 048 `create` zones, `changed` once
10. 049 engine queries for UI rules
11. 050 pending-decision model
12. 051 GameState split
13. 039 event deck (after 051: uses the type schema, the upkeep guard and the forecast on a copy)
14. 052 split `ui/main.gd`
