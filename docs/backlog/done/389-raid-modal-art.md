---
id: 389
title: A drawing and a display verdict in the raid modal
type: feature
status: done
branch: feat/389-raid-modal-art
---

## Goal
The raid modal (271) reads as a moment, not a ledger line: a drawing of how the raid ended sits in its body, and the
verdict ("Repelled" or "Pillaged") is a headline in its own display style instead of a small caps heading. The
drawings are placeholders for now; the user replaces the two image files with custom art later.

## Acceptance criteria
- [x] AC1 (drawing): When a raid is repelled, the raid modal shows `assets/art/raid_repelled.svg` above its verdict;
  when one pillages, `assets/art/raid_pillaged.svg`. The test hook's `art` names the shown file.
- [x] AC2 (verdict): The verdict label uses the `Verdict` theme variation (Barlow SemiCondensed SemiBold at
  `type.display`, tracked capitals), not `Heading`.

## Out of scope
- The final art: the placeholders are drawn to be replaced file for file (same names; any size, shown at 16:9, cover).
- Sound, motion or colour by outcome.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_raid_modal::test_a_pillaging_raid_opens_its_modal`, `test_a_repelled_raid_opens_its_modal` (the `art` key) |
| AC2 | `test_raid_modal::test_the_verdict_is_a_display_headline` |

## Manual check
- `godot --path . -- --turns 20 --seed 5`: let a raid strike with and without a garrison; the drawing fills the body's
  width above "REPELLED" / "PILLAGED", which reads clearly apart from the sheet's Jost title.
- Replace either SVG (or swap in a PNG by changing `RaidModal.ART`) and check it still fits.

## Log
- 2026-10-06: Built. The placeholders are ink-on-paper SVGs in a dashed frame (Godot's SVG import draws no `<text>`,
  so they carry no "placeholder" label). The verdict reuses Barlow SemiCondensed SemiBold, so the modal's title
  (Jost) and verdict read as two faces without a new font file.
