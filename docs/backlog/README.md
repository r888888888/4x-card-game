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

Project review cleanup (2026-10-01), before the rework, which builds on this code:
1. 169 docs, skills and the review scan in line with the code (first: later items have less to keep in sync)
2. 170 shared test fixtures, engines typed `GameEngine` (test helpers before the items that add tests)
3. 171 guard tests for state copies and the pending-decision block (guards before the refactors they guard)
4. 172 one pending-decision model (155 adds a decision and moves the government choice; written once, on this model)
5. 173 one way to check and pay a price, and to add unrest (before 155's and 156's new prices)
6. 174 prerequisite cycles a load error; the renewal modifier key on `Modifiers` (small loader fix, any time here)
7. 175 the last small rules leave the UI; one action-button class (rules leave `ui/` before it's split)
8. 176 split `main.gd` (694/700 lines: before 155 and the military items need room in it)

Trade-off: the rework and the military items wait for eight small items; done after them instead, each refactor would
also have to rework 155's and the military items' new state, decisions and prices.

Government and Anarchy rework (from `spike/revolution`; 155 also retires playing a government from hand):
1. 155 revolt any time; Anarchy's length follows unrest (154 government deck is done)
2. 156 Anarchy eats into stored food and wealth
3. 157 Theocracy slows research: an insight-per-gain modifier
4. 158 sim metrics for Anarchy, governments and famine
5. 159 the bot chooses governments and revolts by looking ahead

Then 149's balance pass can cover the reworked unrest.

Barbarians and military (units are homed on a territory, using a worker there, and stationed where they defend):
1. 160 unit cards garrisoned on a home territory
2. 161 territory defence from units, walls, cities and terrain
3. 162 barbarian raids, announced a turn ahead
4. 163 move and disband units
5. 168 the sim bot meets raids (before more military, so the sim stays meaningful)
6. 164 Barracks training, then 165 veterans, then 166 upgrades
7. 167 era units and era 2–3 raids

Not scheduled: 149 balance pass for the action economy, Insight and Unrest (draft: its scope questions are open).
