---
id: 205
title: Revolt from the civilization modal, after a confirmation that says what follows
type: feature
status: ready
branch: feat/205-revolt-in-civilization-modal
---

## Goal
Revolution is a big, rare decision, so it moves off the board into the civilization modal, beside the government it
overthrows, and asks first: a confirmation sheet explains what Anarchy will do to this realm (with this game's
numbers) under a line of flavor, so nobody revolts by a stray click.

## Acceptance criteria
- [ ] AC1 (engine): Given a game where revolt is legal (Chiefdom, unrest 3 of limit 5, food 6, wealth 3), when
  `revolt_summary()` is called, then it returns the lines that describe the coming Anarchy with live numbers, in order:
  when it falls ("Anarchy falls at the start of next turn."), how long (`revolt_forecast()` turns: "It lasts up to N
  turns; calming shortens it."), the actions it allows ("1 action each turn; only order cards can be played."), what
  stops ("Nothing can be grown, bought or researched."), the drain ("Each turn it eats 20% of stored food and wealth."
  from `unrest.drain_pct`), renewal (from `unrest.renewal`) and the end ("When it ends, choose a government from your
  government deck."). With a config block missing (no drain, no renewal), its line is left out.
- [ ] AC2 (engine): Given revolt is not legal (`revolt_error()` non-empty), `revolt_summary()` returns [].
- [ ] AC3 (loader): A government card may have `flavor` (paragraph and quote, as civilizations, 107); the shipped
  Anarchy card has one. Flavor on any other non-civilization type is still a load error naming file, card and field.
- [ ] AC4: Given the civilization modal is open and revolt is legal, then the government section ends with a "Revolt…"
  button; given `revolt_error()` is non-empty, the button is disabled with the error as its tooltip. The board no
  longer has a Revolt button (`BoardLayout.revolt` goes; Relieve famine and Restore order stay).
- [ ] AC5: When "Revolt…" is pressed, then a confirmation modal opens stacked on the civilization modal: title
  "Revolution", context caps "Turn N · <government>", the Anarchy card's flavor (italic, quote attributed), then
  `revolt_summary()`'s lines as a list, and a footer with "Keep <government>" (closes it, nothing changes) and
  "Revolt" (primary, rightmost).
- [ ] AC6: When "Revolt" is pressed, then `revolt()` runs once (state `revolt_pending` true), the confirmation closes,
  and the civilization modal stays open showing the revolution under way (its Revolt… button disabled with "A
  revolution is already under way."). Esc or a click outside the confirmation closes it without revolting.

## Out of scope
- The bot (it calls `revolt()` directly; no change). Balance of Anarchy.

## Design notes
- New engine API `revolt_summary() -> Array[String]` (in `anarchy.gd`, exposed on `GameEngine`), generated from the
  config like the Anarchy card's text; the UI never writes the numbers.
- Data: `flavor` joins `TYPE_FIELDS` for `CardDef.GOVERNMENT`; add a flavor paragraph and quote to `anarchy` in
  `data/cards.json` (content: reviewed at the manual check).
- New `RevoltModal` (extends `Modal`); its look follows 207's sheet (title block, footer rule). Build after 207, or
  restyle it in 207.

## Test plan
| AC | Test |
|---|---|

## Manual check
- [ ] Seed 5: open Sumer · Chiefdom, press Revolt…: the sheet reads well (flavor, list, two buttons), in both palettes.
- [ ] Review the Anarchy flavor text and quote.

## Log
- Specced 2026-10-02 from the notes list. Decided 2026-10-02: the engine writes the summary; the flavor is the Anarchy
  card's (it has none yet, so this item adds it).
