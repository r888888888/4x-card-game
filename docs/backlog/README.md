# Backlog

One Markdown file per feature or bug: `NNN-short-slug.md` (e.g. `004-market-zone.md`).
IDs are sequential across features and bugs. Copy a template from `_templates/`, or ask
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
14. 068 event panel (uses 039)
15. 069 starter event deck (uses 039, 068)
16. 052 split `ui/main.gd`
17. 053 board tidy (Realm, Buy Cards, Knowledge wording, seed in menu)
18. 067 Exit button in the menu (after 053, which also edits the menu)
19. 075 Frontier and Known rows keep their height
20. 076 buildings cost mostly wealth
21. 054 fresh-water start, Farm needs Fresh Water
22. 055 Caravan `trade` op
23. 056 card details modal (the tech tree reuses it)
24. 057 locked supply piles, `unlock` op
25. 058 Stone/Bronze Age tech content (uses 057)
26. 059 tech tree modal (after 058's content, uses 056)
27. 060 Granary famine guard
28. ~~061 weighted explore~~ (wontfix)
29. 062 civilization cards
30. 085 script size limits
31. 086 split `ui/card_view.gd` (after 085)
32. 063 start screen
33. 064 choose civilization (uses 062, 063)
34. 065 government cards (content from 058's techs)
35. 080 five early-game cards (data only)
36. 081 `gain_per_keyword` op, Hunt
37. 082 `trash` op, Winnow
38. 078 wide territory row pushes the side panel off screen (bug: End turn goes off screen in longer games)
39. 088 civilization and government as side-panel lines (fixes End turn off screen at 1080p since 065)
40. 087 collapse territory groups (after 078: both rework `TerritoryGroup` in `ui/tableau_view.gd`)
41. ~~089 unique cards have no supply pile~~ (wontfix)
42. 072 harmful event ops (`lose`, `lose_pop`)
43. 083 Famine replaces starvation (uses 072, 060; the first harm players feel)
44. 084 relieve a Famine with wealth
45. 074 event decks escalate by era (uses 072)
46. 070 event tooltip says how long it lasts (before 079, whose modal shows the event text)
47. 079 modal when a new event is drawn (after 072, so its summary covers losses as well as gains)
48. 071 icons for the tech and event type marks
49. 077 Market earns wealth per city (data only; just before the balance pass)
50. 066 100-turn games, balance pass (last: everything above changes balance)

Not scheduled: 073 event discard conditions (draft: a behavior question is still open).
