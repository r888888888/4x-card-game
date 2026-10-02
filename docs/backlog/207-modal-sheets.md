---
id: 207
title: Modals as the specimen's drafting sheets, laid down and lifted off
type: feature
status: ready
branch: feat/207-modal-sheets
---

## Goal
Every modal looks and moves like the specimen's sheet (guide §15.11, `docs/design/mcm-specimen.html` "Turn", and
`transitions.html` "Buy cards"): a title block with a 4 px bar, title left and context caps right, the body, a footer
rule with the buttons right (primary rightmost), a hard 8 px shadow; it rises into place, and a stacked one sits
+8,+8 on the one below.

## Acceptance criteria
- [ ] AC1: `Modal` builds the sheet: a panel on `RAISED` with a 2 px `TEXT` border, `RADIUS_0`, an 8,8 `SHADOW`
  shadow; a title block (4 px `TEXT` bar on top, the title in the Title variation at left, an optional context in
  caps at right); a body at most 640 px wide; an optional footer above which a 1 px `CONTROL_DISABLED_BORDER` rule
  runs, buttons right-aligned. Subclasses set `title`, `context` and footer buttons through `Modal`'s API instead of
  building their own headers.
- [ ] AC2: Every modal uses it: card details, the civilization modal, the event modal, the Settings modal (206), and
  the game menu and the game-over sheet, which become `Modal`s on `main.modals` (today they build their own scrims), each with its title (and context where it has one: the event modal "Turn N",
  card details the card type) and its Close or primary button in the footer.
- [ ] AC3: Opening a modal (Reduce motion off): its panel starts 24 px below its place at opacity 0 and reaches its
  place in 0.24 s (`Anim.MACHINED`), opacity 1 by 0.12 s; its scrim fades in over 0.16 s. With Reduce motion: a 0.12 s
  fade, no movement.
- [ ] AC4: A modal opened over another sits +8,+8 from the one below (replacing `Modal.cascade`'s offset if it differs),
  and opens with AC3's motion without a second scrim fade.
- [ ] AC5: Closing: the panel moves to +12 px below and to opacity 0 in 0.16 s (`Anim.RELEASE`) with its scrim; it
  takes no clicks or keys while closing, and the modal below takes them at once. Closing several at once (ModalStack
  closing above a lower one) runs them together.
- [ ] AC6: The existing sounds (189: sheet open/close, stacked quieter, under a bell quieter) play as today.

## Out of scope
- The tech tree (it becomes a screen in 208). Choice overlays (explore, renewal, government; 209 does government).

## Design notes
- `GameMenu` and `GameOverOverlay` are `RefCounted` builders with their own scrim and keys today; moving them onto
  `Modal` is part of AC2 (their tests' hooks may move; behaviours stay).
- Timings are the guide's tokens (`Anim`, `Tokens`); tests read the tween's targets at its end and the positions at
  t = 0, as 104's navigator tests do.

## Test plan
| AC | Test |
|---|---|

## Manual check
- [ ] Civilization modal → a card's details (or Revolt…, 205): the second sheet lands +8,+8 like paper on paper; compare with the specimen in both
  palettes and at ¼ speed in `transitions.html`.

## Log
- Specced 2026-10-02 from the notes list. Decided 2026-10-02: the sheet's rise and stack transition are part of this
  item.
