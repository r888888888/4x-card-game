---
id: 325
title: Show which techs I can afford on the tech tree
type: feature
status: review
branch: feat/325-tech-tree-affordability
---

## Goal
On the Knowledge screen every available tech shows its cost, but nothing tells the player at a glance which
of them their insight covers right now. After this, an available tech they can pay for looks different from
one they can't, so they can see what to research without comparing each number to their insight.

## Acceptance criteria
- [x] AC1: Given 3 insight and an available tech (prereq met, in the research deck) whose `tech_cost` is 3, when
  `tech_tree()` is read, then its entry has `affordable` true.
- [x] AC2: Given 2 insight and the same tech (cost 3), when `tech_tree()` is read, then its entry has `affordable`
  false; after gaining 1 insight it is true.
- [x] AC3: Given a tech with a met eureka (or diffusion) that lowers its cost from 4 to 3 and 3 insight, when
  `tech_tree()` is read, then `affordable` is true: it compares the cost now, not the printed cost.
- [x] AC4: Given enough insight for every tech, when `tech_tree()` is read, then a researched tech, a locked tech
  (prereq not researched) and a later era's tech each have `affordable` false.
- [x] AC5: Given an affordable available tech and a pending choice (e.g. explore), when `tech_tree()` is read, then
  `affordable` is still true: it is about insight only; `buy_tech_error` still refuses the purchase.
- [x] AC6: Given the Knowledge screen open with one affordable and one unaffordable available tech, then the
  affordable tile uses the `TechTile` look and the unaffordable one the `TechTileShort` look, and the
  unaffordable tile's tooltip names the insight shortfall (from `buy_tech_error`); after gaining enough insight
  and the screen refreshing, the second tile uses `TechTile`.

## Out of scope
- Showing affordability for locked techs (they already look locked).
- Any change to costs, eurekas or diffusion.
- Affordability anywhere outside the Knowledge screen (the tech details modal's Research button already
  disables via `buy_tech_error`).

## Design notes
- New `tech_tree()` field `affordable: bool` (set in `Research._tree_entry`): `state == TECH_AVAILABLE` and the
  player's insight ≥ that entry's `cost`. Document it in the `tech_tree` doc comment.
- New `GameTheme` variation `TechTileShort` (and `TechTileTextShort`): the sheet like `TechTile` but with its
  text and cost marker in a muted colour (`Palette` token, e.g. `TEXT_DISABLED`), distinct from `TechTileLocked`'s
  well fill so "can't afford yet" reads differently from "locked". The hover-link mark (278) appends `Linked`, so
  add `TechTileShortLinked` too.
- `KnowledgeScreen._tile` picks the look from `tech.affordable`; it doesn't compare insight itself.
- The sim bot is unaffected (no new action).

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_tech_tree::test_an_available_tech_the_insight_covers_is_affordable` |
| AC2 | `test_tech_tree::test_an_available_tech_short_of_insight_isnt_affordable_until_the_insight_comes` |
| AC3 | `test_eurekas::test_a_eureka_makes_a_tech_affordable_at_its_cost_now` |
| AC4 | `test_tech_tree::test_researched_locked_and_later_era_techs_are_never_affordable` |
| AC5 | `test_tech_tree::test_affordable_is_about_insight_only_while_a_choice_is_owed` |
| AC6 | `test_knowledge_screen::test_an_available_tile_the_insight_doesnt_cover_looks_short_until_it_does` |

## Manual check
- [ ] `godot --path . -- --civ sumer --seed 5`, press T at the start (low insight): the dear era-1 techs' tiles are
  muted, any you can pay for read normally; muted tiles stay unlike locked ones (the grey well), in night and day mode.
- [ ] Gain insight (end a turn), reopen: the tile turns normal.

## Log
- `affordable` ignores pending choices and game over (AC5): it's about insight, `buy_tech_error` still refuses.
- The look is `TechTileShort` (sheet fill, ink border, `TEXT_DISABLED` text); its `Linked` twin comes from the theme's loop.
