---
id: 202
title: A right sidebar with the civilization and government
type: feature
status: ready
branch: feat/202-civilization-sidebar
---

## Goal
The board gets the mock's rail (`docs/design/transitions.html`, `.rail`) on the right: the civilization's name and its
government, which open the civilization modal. It replaces the top bar's "Sumer · Chiefdom" button and gives End turn
(203) a home.

## Acceptance criteria
- [ ] AC1: Given a game in progress, then a sidebar is shown at the board's right edge, full height under the top
  strip, with the Realm and the hand to its left: a "CIVILIZATION" heading, the civilization's name (Title variation,
  e.g. "Sumer") and the government as a link button ("Chiefdom ›").
- [ ] AC2: When the civilization's name or the government link is clicked (or focused and Enter pressed), then the
  civilization modal (`IdentityModal`) opens, as the top bar's button does today; it grows out of / plays from the
  clicked control's position where the old button's did.
- [ ] AC3: Given the government changes (Anarchy falls, a new government is chosen), then the sidebar's government
  updates on the next refresh; under Anarchy it reads "Anarchy ›".
- [ ] AC4: The top bar no longer has the civilization button (`TopBar.identity_button()` goes; its callers use the
  sidebar's).
- [ ] AC5: The sidebar's controls are in the board's focus order, after the top strip's buttons.
- [ ] AC6: Given the title screen or the new game screen is showing, the sidebar is hidden with the board.

## Out of scope
- End turn's move (203); Revolt (205).

## Design notes
- New `ui/sidebar.gd` (`Sidebar`), built by `BoardLayout`, `DarkPanel`-style sheet with a top rule like the mock's.
  Width is a token step (e.g. `Tokens.SPACE_9 * 3`); judge at the manual check.

## Test plan
| AC | Test |
|---|---|

## Manual check
- [ ] Seed 5: the rail reads like the mock's (rule, caps heading, name, "Chiefdom ›") in both palettes; the Realm and
  hand reflow to its left without overlap at 1280×720 and 1920×1080.

## Log
- Specced 2026-10-02 from the notes list.
