---
id: 016
title: Reduce motion setting, saved between launches
type: feature
status: ready
branch: feat/016-reduce-motion
---

## Goal
Players who are bothered by motion can turn off the decorative animation, and the game remembers
the choice. Every movement effect (shake, tilt, pulse, squash, looping highlight, flying cards)
currently always runs.

## Acceptance criteria
- [ ] AC1: Given no settings file, when settings are loaded, then `reduce_motion` is false.
- [ ] AC2: Given `reduce_motion` is set to true and saved, when settings are loaded again (new
  instance, same file), then `reduce_motion` is true. Setting it back to false and saving makes the
  next load return false.
- [ ] AC3: Given a settings file that is corrupt or has a non-bool `reduce_motion`, when it is
  loaded, then `reduce_motion` is false and a warning names the file and the key. There is no crash.
- [ ] AC4 (UI): Given the "Reduce motion" checkbox in the top bar, when I tick it, then it takes effect
  straight away and is ticked on the next launch.
- [ ] AC5 (UI): Given reduce motion is on, then there is no shake, drag tilt, hover lift or scale,
  landing squash, counter pulse, pop-in bounce or pulsing drop highlight. Cards that change zone
  and resource tokens reach their destination within 0.15s (fade or short slide), and a refused play
  still shows its reason.

## Out of scope
- Reading the OS reduced-motion preference.
- Any other settings (volume, UI scale).

## Design notes
- New autoload `Settings` (`autoload/settings.gd`), backed by `ConfigFile` at
  `user://settings.cfg`, section `ui`, key `reduce_motion`. The path can be injected so tests use a
  temp file. AC1–AC3 are autoload behaviour, so TDD applies (`tests/test_settings.gd`).
- UI: `Anim` constants stay the same. `CardView` and `main.gd` check `Settings.reduce_motion` where
  they start an effect. Keep that branch in one helper per file rather than scattered ifs.

## Test plan
| AC | Test |
|---|---|
| AC1–AC3 | `test_settings::…` (filled in at the red checkpoint) |
| AC4–AC5 | Manual |

## Manual check
- [ ] **AC4:** tick "Reduce motion", quit and relaunch: it is still ticked.
- [ ] **AC5:** with it on, drag, drop, refuse a play, end the turn and explore. Nothing bounces, shakes,
  tilts or pulses. Cards still clearly get where they are going, and the refused reason still shows.

## Log
