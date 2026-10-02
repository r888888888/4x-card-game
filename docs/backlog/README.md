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

Design tokens (from the design-system review; 192 and 193 are done):
1. 194 type scale tokens

Sound (the guide's §16 and §14.1 tokens; the restyle items they name, 177–183, are done):
1. 184 sound buses and volume settings
2. 185 sound rows in Settings and the game menu (needs 182)
3. 186 the sound player, its tokens and placeholder sounds
4. 187 key sounds: buttons, the legend key and End turn (needs 178, 182)
5. 188 counter and card sounds (needs 179, 181)
6. 189 sheet, screen and notice sounds
7. 190 notice priorities, heard as a pattern and seen as a hue bar (engine)
8. 191 event sounds for techs, cities, eras and the end of the game (engine)

Not scheduled: 149 balance pass for the action economy, Insight and Unrest (draft: its scope questions are open).
