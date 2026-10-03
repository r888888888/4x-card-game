---
id: 245
title: Play a quiet tick when the mouse hovers an interactable button or card
type: feature
status: red-review
branch: feat/245-hover-sound
---

## Goal
The cursor moving onto something you can click gets a small, subtle acknowledgement, so the board feels responsive.
This reverses the style guide's "hover is silent" rule (§16.8, §13 anti-pattern table, the component notes that say
"Sound: None"); the guide is amended in the same item.

## Acceptance criteria
- [ ] AC1: Given main with sound on, when the mouse enters an enabled, visible `BaseButton`, then `sfx` plays
  `Sfx.HOVER` once (a Level 1 token on the Interface bus).
- [ ] AC2: Given a card the player can act on (hand card, supply card, or other card tile that `CardView` makes
  hoverable), when the mouse enters it, then `Sfx.HOVER` plays once; a card that is only displayed (a modal's detail
  face, a card on a pile, a disabled tile) is silent.
- [ ] AC3: Given a disabled button, when the mouse enters it, then nothing plays (its press still gives the dead tap).
- [ ] AC4: Given the mouse stays on a control, moves within it, or leaves it, then no further hover sound plays; it
  plays again only on a fresh entry. Hovering the same control again within `Sfx.HOVER_GAP` (0.08 s) of its last
  tick is dropped, so sweeping across a row of keys doesn't machine-gun.
- [ ] AC5: Given a button pressed and held (mouse down), when the cursor re-enters it, or a drag is in progress,
  then no hover sound plays.
- [ ] AC6: Given a button added to the tree after main opens (a modal's, a rebuilt row), when the mouse enters it,
  then it ticks like any other (hooked in `KeySounds` like the press sounds).
- [ ] AC7: Given Interface sounds are off in Settings, then hover is silent like every Level 1 sound; hover is quieter
  than `ui.button.press` and gives way to any other sound the same frame (it never talks over a press, selection or
  event sound).
- [ ] AC8: Given `Sfx.HOVER`, then `Sfx.TOKENS` lists it at Level 1 and it has its four variant files under
  `assets/sounds/ui/ui_hover_a.wav … _d.wav` (existing token-file test covers this).

## Out of scope
- Keyboard focus moving stays silent.
- Tooltips, links, the scrim, lamps and every other "silent by design" item stay silent.
- A separate hover-sounds setting: the existing Interface sounds toggle mutes it.
- Bot / sim: unaffected (UI only).

## Design notes
- New token `ui.hover` (`Sfx.HOVER`) in `ui/sfx.gd`, Level 1, plus the §14.1 row and amended §16.8 / §13 /
  component "Sound: None" lines in `docs/design/mcm-style-guide.md`. Character: a soft, dry, short (~15–25 ms)
  felt-on-wood tick, well under `ui.button.press`, ≈ −8 dB relative; high enough not to thud.
- Four .wav variants generated with a small script (not committed unless it's reusable); Godot imports them.
- `KeySounds._hook` already sees every `BaseButton`; add `mouse_entered` there. Cards: `CardView` already has
  `mouse_entered` → `_set_hover`; it plays through `Sfx.find(self)`.
- Gating (disabled, mouse held, drag in progress, minimum gap) is logic: put the gap in `Sfx.play` like `TICK_GAP`
  (`HOVER_GAP`), the rest at the call sites.
- Engine untouched; this is `ui/` + audio assets + guide, so UI tests only (like `test_key_sounds.gd`).

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_hover_sound::test_entering_an_enabled_button_ticks_once_and_quietly` |
| AC2 | `test_hover_sound::test_entering_a_hand_card_ticks`, `test_a_display_only_card_is_silent` |
| AC3 | `test_hover_sound::test_a_disabled_button_is_silent_on_hover` |
| AC4 | `test_hover_sound::test_moving_within_and_leaving_do_not_tick_again_and_a_fresh_entry_does`, `test_a_re_entry_inside_the_gap_is_dropped` |
| AC5 | `test_hover_sound::test_entering_a_button_with_the_mouse_held_is_silent` |
| AC6 | `test_hover_sound::test_a_button_added_later_ticks` |
| AC7 | `test_hover_sound::test_hover_gives_way_to_a_level_3_event` (quieter: in the AC1 test; Interface-off muting is the bus, already tested) |
| AC8 | `test_hover_sound::test_the_hover_token_is_a_level_1_sound`; `test_sfx::test_every_token_has_its_files` |

## Manual check
- [ ] Sweep the cursor over the menu buttons, the End turn key, hand and supply cards: a faint tick on each, never
  louder than a click.
- [ ] Sweep quickly across a row of keys: ticks stay light, not a buzz.
- [ ] Turn Interface sounds off: hover is silent.
- [ ] Hover a disabled key: silent; click it: the dead tap still sounds.

## Log
