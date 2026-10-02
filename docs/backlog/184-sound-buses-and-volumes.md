---
id: 184
title: Sound buses and volume settings
type: feature
status: ready
branch: feat/184-sound-buses-and-volumes
---

## Goal
The game gets the audio plumbing the style guide's sound system needs ([docs/design/mcm-style-guide.md](../design/mcm-style-guide.md)
§16.9, §12 rules 11–16): an Interface bus for clicks and panels and a Game bus for events, each behind its own
volume and limiter, and settings that remember the player's levels and whether interface sounds are on. Nothing makes
a sound yet (186 onward); this item makes sure that when something does, it is at the right level and the player can
turn it down or off.

## Acceptance criteria
- [ ] AC1: The settings file keeps a `[sound]` section: `master`, `game` and `interface` (whole numbers 0–100) and
  `interface_sounds` (true or false). With no file, or no `[sound]` section, they are 80, 80, 70 and true. They save
  and load like `reduce_motion`.
- [ ] AC2: A bad value falls back to its default with a warning naming the file, section and key, for example
  "settings file '<path>': [sound] 'game' must be a whole number from 0 to 100, got 140; using 80" and
  "settings file '<path>': [sound] 'interface_sounds' must be true or false, got \"yes\"; using true".
- [ ] AC3: `Settings.set_volume(bus, percent)` for `Settings.MASTER`, `Settings.GAME` or `Settings.INTERFACE` clamps
  percent to 0–100, saves, emits `changed` and returns true; for any other bus name it returns false and changes and
  saves nothing. `Settings.set_interface_sounds(on)` saves and emits `changed`. `Settings.volume(bus)` and
  `Settings.interface_sounds` read them back.
- [ ] AC4: The bus layout has `Game` and `Interface`, both sending to `Master`. Each of the three ends in an
  `AudioEffectHardLimiter` with ceiling −1 dB (Master), −10 dB (Game) and −18 dB (Interface); Interface also has a
  high-pass filter at 150 Hz and a high-shelf filter at 6 kHz, −6 dB, before its limiter.
- [ ] AC5: At start and on every change, each bus's volume is `linear_to_db(percent / 100)` (given game 50, the Game
  bus is −6.02 dB ± 0.01) and a bus at 0% is muted. `interface_sounds` false mutes the Interface bus and leaves its
  saved volume and the Game bus alone; turning it back on unmutes it at its saved volume.
- [ ] AC6: `Settings.set_in_background(true)` mutes Interface and Game (the window lost focus) and `false` restores
  them as the settings say (Interface stays muted if `interface_sounds` is false). The autoload calls it on
  `NOTIFICATION_APPLICATION_FOCUS_OUT` / `FOCUS_IN`.

## Out of scope
- A Music bus and its volume (there is no music yet); the settings rows (185); playing anything (186).
- A setting to keep sound in the background (the guide's default, mute, is the only behaviour for now).

## Design notes
- `SettingsStore` reads a second section, `SOUND_SECTION := "sound"`; the existing `[ui]` keys don't move.
- `default_bus_layout.tres` at the project root (Godot loads it by default); bus names are constants on `Settings`
  (`MASTER := &"Master"`, `GAME := &"Game"`, `INTERFACE := &"Interface"`) and never written as strings elsewhere.
- Applying volumes lives in the autoload (it already owns the settings); this is `autoload/` work, so test-first.
- The guide's Level 3 ducking of music (§16.9) waits for music.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|

## Manual check
- [ ] Delete `user://settings.cfg`, launch: the file written on the first change has the `[sound]` defaults.

## Log
- 2026-10-02: Specced from the style guide's sound system (§16, merged from `spike/mcm-sound`). Decided 2026-10-02:
  sounds are on by default at the guide's levels (Master 80, Game 80, Interface 70).
