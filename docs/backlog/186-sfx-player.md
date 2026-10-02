---
id: 186
title: The sound player, its tokens and placeholder sounds
type: feature
status: ready
branch: feat/186-sfx-player
---

## Goal
Everything that makes a sound goes through one player that knows the style guide's sound tokens
([docs/design/mcm-style-guide.md](../design/mcm-style-guide.md) §14.1, §16.4–16.5, §16.8) and enforces their rules:
which bus each plays on, how quiet the frequent ones are, how fast ticks may repeat, that an event is never talked over
by routine clicks, and that a sound starts at its motion's contact point. The first sounds are placeholders rendered
from the specimen's synthesis, so the rest of the sound items have something real to play.

## Acceptance criteria
- [ ] AC1: `Sfx` has a constant for every token in the guide's §14.1 tables (`Sfx.BUTTON_PRESS == &"ui.button.press"`,
  …, `Sfx.MILESTONE_VICTORY`; the notification's three patterns as `NOTIFICATION_INFO`, `_CAUTION`, `_URGENT`) and
  `Sfx.level(token)` gives its level: 1 for `BUTTON_PRESS` and `COUNTER_TICK`, 2 for `PANEL_OPEN` and
  `ENDTURN_COMMIT`, 3 for `MILESTONE_ERA`. Levels 1–2 play on `Settings.INTERFACE`, level 3 on `Settings.GAME`.
- [ ] AC2: Every token has its sounds under `assets/sounds/`: four variants for a Level 1 token
  (`ui/ui_button_press_a.wav` … `_d.wav`), two for Level 2, one for Level 3 (`events/ui_milestone_era.wav`), and each
  loads as an `AudioStreamWAV`. Level 1 tokens play through an `AudioStreamRandomizer` with
  `PLAYBACK_RANDOM_NO_REPEATS`, `random_pitch` 1.015 (±25 cents) and `random_volume_offset_db` 1.0; Level 2 and 3
  through their files with no pitch change. (A content test in the spirit of `test_content`.)
- [ ] AC3: `Sfx.play(token, delay := 0.0, input := false)` returns true when the sound will play and records it in
  `Sfx.played()` as `{token, bus, at}` (`at` = now + delay, in seconds of `Sfx.clock()`); an unknown token returns
  false and pushes an error naming it.
- [ ] AC4: Rate rules: a `COUNTER_TICK` due within 0.035 s of the previous tick returns false; a notification due
  within 0.4 s of the previous one is moved to 0.4 s after it (its `at` says so) and still returns true; with six
  Interface sounds playing, a further Level 1 returns false, and a Level 2 plays, stopping the oldest Level 1.
- [ ] AC5: While a Level 3 is playing (from its `at` to its end), a Level 1 or 2 with `input` false returns false; one
  with `input` true plays 6 dB quieter than it would otherwise.
- [ ] AC6: `Anim.contact(duration, curve)` is the time a motion reaches 90% of its travel (§16.5), for the curves
  `Anim.SNAP`, `MACHINED`, `LATCH` and `RELEASE`: `contact(0.07, SNAP)` 0.038, `contact(0.12, MACHINED)` 0.065,
  `contact(0.26, LATCH)` 0.164, `contact(0.2, RELEASE)` 0.187 (each ± 0.002). `Sfx.lead(token)` is 0.014 for
  `BUTTON_PRESS` and `ENDTURN_PRESS`, 0.018 for `BUTTON_RELEASE` and `TOGGLE_OFF`, 0 otherwise, and
  `Sfx.at_contact(token, duration, curve)` plays the token at `contact(...) − lead(token)` (never below 0), or at 0
  with Reduce motion.

## Out of scope
- Hooking any control, counter, card, sheet or event to a sound (187–191). The shared reverb room (§16.6): the
  placeholder files are dry and Level 2/3 files carry their own short tail for now.

## Design notes
- `ui/sfx.gd` (`Sfx`), a `Node` owned by main like `ModalStack`, holding a small pool of `AudioStreamPlayer`s per bus.
  Tokens and their levels, files and leads are one table in `Sfx`; nothing else names a sound file.
- `Sfx.clock()` is the player's time source, so tests can step it instead of waiting; `played()` is for tests and the
  repetition test, like `Toasts.texts()`.
- Placeholders: an exporter page beside the specimen (`docs/design/sound-export.html`) renders each token with the
  specimen's synthesis through an `OfflineAudioContext`, normalised to its level (Level 1's four variants by the
  specimen's variant pitch factors), and saves 48 kHz 16-bit mono WAVs named by token (§16.10). The key click is
  option G from `click-options.html`, as adopted. Recorded sounds replace the files later under the same names.
- `Anim.contact` solves the guide's cubic-bezier curves (§9.3) numerically; the four curves are constants on `Anim`.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|

## Manual check
- [ ] Every placeholder file plays and sounds like its token in the specimen's audition board.

## Log
- 2026-10-02: Specced from the style guide's sound system. Decided 2026-10-02: ship synthesized placeholders rendered
  from the specimen, replaced by recordings later under the same names.
