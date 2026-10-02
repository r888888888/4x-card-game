---
id: 204
title: "In Hand" heading with the actions count on its line
type: feature
status: ready
branch: feat/204-in-hand-header
---

## Goal
The hand's heading is the mock's short "IN HAND" (`docs/design/transitions.html`); the long how-to moves into a
tooltip, and the actions count sits right-aligned on the same line as "2 / 2".

## Acceptance criteria
- [ ] AC1: Given a game in progress, then the hand's heading reads "In Hand" (shown in capitals by the Heading
  variation), and its tooltip is the current how-to text ("Drag a card into the realm, double-click it, or ←/→ then
  Enter. Right-click or D discards.").
- [ ] AC2: Given 2 actions left of 2, then on the heading's line, right-aligned to the hand's width, a label reads
  "2 / 2"; after playing one card it reads "1 / 2"; its tooltip reads "Actions left this turn".
- [ ] AC3: Given unlimited actions (no government action count, 127), the count label is hidden, as today.
- [ ] AC4: The old "Actions: N / M" label beside the heading is gone (`main.actions_label` shows the new text).

## Out of scope
- The Realm's heading.

## Test plan
| AC | Test |
|---|---|

## Manual check
- [ ] The count lines up with the hand's right edge (left of the sidebar) at 1280×720 and 1920×1080.

## Log
- Specced 2026-10-02 from the notes list. Decided 2026-10-02: the count is actions left / per turn, as today.
