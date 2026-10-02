---
id: 199
title: Settled territory cards in the Realm hide their keywords
type: feature
status: ready
branch: feat/199-realm-territory-cards-hide-keywords
---

## Goal
The Realm's territory cards stay short and scannable: name, band, stats. The keywords ("Marsh · Fresh Water · Flood")
show in the territory view, where there is room for them.

## Acceptance criteria
- [ ] AC1: Given a settled territory in the Realm (seed 5, Sumer: Delta Marsh), then its card face shows no keyword
  line: no visible Label or RichTextLabel on the face contains any of its keywords' names.
- [ ] AC2: Given the same territory's view is opened, then the box's info line shows its keywords (including rolled
  resources, "+ Gold"), as today.
- [ ] AC3: Given a frontier (explored, unsettled) territory in the Realm and the Explore choice's revealed territories,
  then their faces still show their keywords (they have no territory view, and the keywords decide where to settle).
- [ ] AC4: Given a settled territory gains a rolled resource keyword, then its Realm card still shows none, and its
  view shows the new one.

## Out of scope
- Hand cards' needs text ("Needs Forest"); the valid targets stay lit while dragging.

## Design notes
- `CardFace.show_settled(keywords, live)` stops adding the "Keywords" line (or the board passes ""); the view's info
  line keeps `CardFace.keyword_line`.

## Test plan
| AC | Test |
|---|---|

## Manual check
- [ ] Seed 5: Delta Marsh in the Realm shows name, band and stats only; opening it shows its keywords.

## Log
- Specced 2026-10-02 from the notes list. Assumed "minimized territory card" means a settled territory's Realm card;
  frontier and explore-choice cards keep their keywords (AC3) since they have no expanded view.
