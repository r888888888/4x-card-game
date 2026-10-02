---
id: 187
title: Key sounds: buttons, the legend key and End turn
type: feature
status: review
branch: feat/187-key-sounds
---

## Goal
Every key on the desk sounds like the clicky key switch the guide chose ([docs/design/mcm-style-guide.md](../design/mcm-style-guide.md)
§10.1, §15.1, §15.4, §15.12; option G in [click-options.html](../design/click-options.html)): the jacket's snap and
the bottom-out as a button sinks into its shadow, a quieter snap and top-out as it comes back, a latch for the legend
key, and a heavier key and a relay for End turn. A press is felt as well as seen, and hover stays silent.

## Acceptance criteria
- [x] AC1: Pressing any `Button` on the board, the menus, screens or modals (mouse or Space/Enter) plays
  `Sfx.BUTTON_PRESS` at `Sfx.at_contact(BUTTON_PRESS, 0.07, Anim.SNAP)` (0.024 s after the press), and releasing it
  plays `Sfx.BUTTON_RELEASE` at 0.047 s after the release, both with `input` true. Hovering, focusing or tabbing onto
  a button plays nothing.
- [x] AC2: A press that is dragged off the button before release plays both sounds and the button's action doesn't
  run; a press on a disabled button plays `Sfx.REJECT_LOCKED` at once and nothing else, and its tooltip shows
  without the hover delay.
- [x] AC3: The End turn button plays `Sfx.ENDTURN_PRESS` (0.024 s) instead of the button press; when its release ends
  the turn, `Sfx.ENDTURN_COMMIT` plays 0.065 s after the release and `Sfx.ENDTURN_TURN` 0.12 s after that. When the
  release doesn't end the turn (a discard is owed), it plays `Sfx.BUTTON_RELEASE` as any button. Pressing it while
  disabled plays `Sfx.REJECT_LOCKED`.
- [x] AC4: A `LegendKey` (182) plays `Sfx.BUTTON_PRESS` on press; latching it ON plays `Sfx.TOGGLE_ON` 0.038 s after
  the release, with its lamp; releasing it OFF plays `Sfx.TOGGLE_OFF` 0.047 s after the release. Neither plays
  `BUTTON_RELEASE`.
- [x] AC5: Turning the Interface sounds key OFF (185) still plays its `TOGGLE_OFF` before the Interface bus mutes; the
  next button press plays nothing on that bus.
- [x] AC6: With Reduce motion on, the same tokens play at the press and release themselves (no contact delay).

## Out of scope
- Tabs (the game has none yet; the guide's tab is `BUTTON_PRESS` at −3 dB when one is added); cards (188); a primary
  button pitched 2 semitones lower (the only signal-filled key today is End turn, which has its own sounds).

## Design notes
- One hook for all buttons: main connects `button_down` / `button_up` on every `BaseButton` that enters its tree
  (`get_tree().node_added`), skipping `LegendKey` and the End turn button, which make their own sounds. No component
  has to remember to add sound.
- "The release ends the turn" is the engine's answer, not the UI's: the UI compares the turn before and after
  `end_turn()`.
- The tooltip-at-once on a disabled press is the visual twin of the locked tap (§12 rule 10).
- Builds on 178 (press travel), 182 (`LegendKey`), 185 and 186.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_key_sounds::test_a_button_clicks_at_contact_going_down_and_coming_up`, `test_space_and_enter_on_a_button_click_too`, `test_hover_focus_and_tab_are_silent`, `test_a_modals_buttons_click_too` |
| AC2 | `test_a_press_dragged_off_sounds_both_and_does_nothing`, `test_a_disabled_button_gives_a_dead_tap_and_shows_its_reason_at_once` |
| AC3 | `test_end_turn_presses_heavy_and_closes_a_relay_when_the_turn_ends`, `test_end_turn_that_owes_a_discard_comes_up_like_any_key`, `test_a_disabled_end_turn_gives_a_dead_tap` |
| AC4 | `test_the_legend_key_latches_on_and_lets_go_with_its_own_sounds` |
| AC5 | `test_turning_interface_sounds_off_is_heard_before_the_bus_mutes`, `test_settings_can_mute_interface_sounds_after_a_grace` |
| AC6 | `test_with_reduce_motion_keys_sound_at_the_press_and_release` |

## Manual check
- [ ] Seed 5, Egypt: menu buttons, Buy cards and the modal buttons all click on the way down and tick on the way up;
  hovering is silent.
- [ ] End turn sounds heavier than other keys and a relay closes as it comes back up; a disabled End turn gives one
  dead tap and shows its reason.
- [ ] Repetition (§16.8): 1 press a second for two minutes, then bursts of 5 at 6 a second; the click stops being
  noticed after a minute and never grates.

## Log
- 2026-10-02: Specced from the style guide's sound system; the key switch is option G, chosen by ear in
  `spike/mcm-sound`.
- 2026-10-02: Built. `KeySounds` (`ui/key_sounds.gd`, a Node under main) hooks every `BaseButton` entering main's tree; buttons in `KeySounds.OWN_SOUNDS` (`LegendKey`, End turn) make their own press and release sounds, and every disabled key's dead tap and locked tip (`main.locked_tip()`, the theme's tooltip look, for `Anim.ERROR_SHOW_TIME` or until the mouse leaves) is made there. `Sfx.find(node)` (the `sfx` group) lets a component reach the player. `Anim.KEY_PRESS_TIME`, `KEY_RELEASE_TIME`, `ENDTURN_TURN_DELAY`, `SOUND_OFF_GRACE`. `Settings.set_interface_sounds(on, mute_after := 0.0)`: the Interface sounds key mutes the bus after `SOUND_OFF_GRACE`, so its OFF is heard (AC5). `Sfx.played()` records `input` too.
- Found: a mouse release sends a plain `Button`'s `button_up` before `pressed` (a toggle's the other way round), so End turn's release sounds wait for both; a release with no action by the end of the frame (dragged off) only comes back up.
- Only a mouse press on a disabled key taps: a disabled key doesn't take the focus, so Space can't reach it. The E shortcut ends the turn without the key's sounds (it isn't a press of the key).
