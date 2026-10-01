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
44. 090 upkeep-rule rationale, add-effect skill, review rules in CLAUDE.md (docs first: the items below follow them)
45. 091 shared test helpers, one test per Famine behavior (test infrastructure before the items that add tests)
46. 092 research card name from the engine, content tests as invariants (uses 091's helpers)
47. 093 error queries for `choose`, `decline_research`, `discard_card` (logic out of the UI, before engine restructuring)
48. 094 engine queries for the UI's targeting choice, tech eras, open supply piles (same reason as 093)
49. 095 split `ConfigLoader` out of `DataLoader` (677/700 lines; before 084 and 074, which add config)
50. 096 Famine module (before 084, which adds Famine rules)
51. 084 relieve a Famine with wealth (after 095 and 096: its rules and config land in the new files)
52. 074 event decks escalate by era (uses 072; after 095: adds config)
53. 070 event tooltip says how long it lasts (before 079, whose modal shows the event text)
54. 079 modal when a new event is drawn (after 072, so its summary covers losses as well as gains)
55. 071 icons for the tech and event type marks
56. 077 Market earns wealth per city (data only; just before the balance pass)
57. 066 100-turn games, balance pass (last: everything above changes balance)
58. 103 navigation stack for screens (done; before 101, which pushes the territory view on it)
59. 101 territory view (click a territory: its city, buildings and Grow in place of the Realm)
60. 102 territories as plain cards in the Realm (after 101, which gives the buildings somewhere to show)
61. 106 theme cleanup: one palette, theme type variations (the in-house alternative to 097; before 104 and 105,
    which add colours)
62. 104 screen header and transitions for navigated screens (the pattern; after 103)
63. 105 territory view layout (uses 104's header)
64. 107 ancient civilizations: Egypt, Sumer, Phoenicia, Babylon, Greece, Persia (content only, existing ops)
65. 112 drop the basic terms (Upkeep, Slots, Pop) from card details
66. 113 capital slots +4 → +3 (balance; revisit after 111)
67. 125 split effect hooks and internals out of `GameEngine` (694/700 lines; before everything below, which adds
    engine queries)
68. 127 actions per turn: playing a hand card uses 1; the government sets the count (Chiefdom 2, Kingship and
    Theocracy 3)
69. 128 `gain_actions` op: Scout and Barter give +1 action (after 127)
70. 129 standing `modifiers` on permanent cards, first key `actions` (after 127)
71. 108 civilization discounts (Babylon techs, Phoenicia supply, Egypt wonders; after 107 and 125)
72. 109 hand size as a `modifiers` key (Greece; after 129)
73. 110 housing as a `modifiers` key (Sumer; after 129)
74. 111 civilization home territory (after 107; last, since it shifts every civ's start)
75. Balance pass for the action economy (to spec: 127–129 shift the game from resources to tempo)
76. 139 Insight resource: techs cost Insight (research redesign, from `spike/research-insight`)
77. 140 open tech tree: learn any tech whose prereq you have; reveal-2 and passes go (after 139)
78. 141 eurekas (after 140)
79. 142 diffusion: earlier-era techs get cheaper (after 140; independent of 141)
80. 143 Iron Age techs in the deck, research pacing (after 139–142)

Not scheduled: 073 event discard conditions (draft: a behavior question is still open).
