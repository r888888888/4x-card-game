---
id: 016
title: Reduce motion setting, saved between launches
type: feature
status: done
branch: feat/016-reduce-motion
---

## Goal
Players who are bothered by motion can turn off the decorative animation, and the game remembers
the choice. Every movement effect (shake, tilt, pulse, squash, looping highlight, flying cards)
currently always runs.

## Acceptance criteria
- [x] AC1: Given no settings file, when settings are loaded, then `reduce_motion` is false.
- [x] AC2: Given `reduce_motion` is set to true and saved, when settings are loaded again (new
  instance, same file), then `reduce_motion` is true. Setting it back to false and saving makes the
  next load return false.
- [x] AC3: Given a settings file that is corrupt or has a non-bool `reduce_motion`, when it is
  loaded, then `reduce_motion` is false and a warning names the file and the key. There is no crash.
- [x] AC4 (UI): Given the "Reduce motion" toggle in the top bar, when I tick it, then it takes effect
  straight away and is ticked on the next launch.
- [x] AC5 (UI): Given reduce motion is on, then there is no shake, drag tilt, hover lift or scale,
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
| AC1 | `test_settings::test_missing_file_means_reduce_motion_off` |
| AC2 | `test_settings::test_reduce_motion_survives_save_and_load` |
| AC3 | `test_settings::test_corrupt_file_falls_back_to_off_with_warning`, `test_settings::test_non_bool_reduce_motion_falls_back_to_off_with_warning` |
| AC4–AC5 | Manual |

## Manual check
Run `godot --path .`.
- [ ] **AC4:** the top bar shows "Reduce motion: off". Click it: it reads "Reduce motion: on", and
  takes effect straight away. Quit and relaunch: it is still on.
- [ ] **AC5:** with it on, hover a hand card: the border turns white but the card doesn't lift or grow.
  Drag a card: it sits under the cursor with no lag, tilt or growth, and the drop zone is lit
  without pulsing. Drop a playable card: it jumps to its slot and fades in, with no squash. "+2 food"
  appears at the Food counter and fades, and the counter doesn't pulse. Drop one you can't afford: no
  shake, and the reason still shows (without drifting up). End the turn: the hand fades out, and the
  new hand appears all at once and fades in. Play Scout and Settler: the new City fades in with no bounce.
- [ ] Turn it off again: all the animation is back.

## Log
- `SettingsStore` (RefCounted, `autoload/settings_store.gd`) holds the file logic, so tests can point it at
  a temp file. The `Settings` autoload owns one for `user://settings.cfg`, pushes its load warnings,
  and emits `changed` when the toggle saves.
- `ConfigFile.parse` logs its own engine error on bad syntax, which the test runner counts as a failure.
  `load()` turns off `Engine.print_error_messages` around the parse, and reports its own warning,
  which names the file.
- The spec said "checkbox". It's a toggle button labelled "Reduce motion: on/off" instead, because the
  default checkbox's unchecked box is almost invisible on the dark bar.
- One `_calm()` helper each in `card_view.gd` and `main.gd`. It must not be `static`: GDScript can't
  reach autoloads from a static function.
- With reduce motion on, the deal stagger (0.06s per card) is dropped too. Otherwise the fifth card of a new
  hand took about 0.39s to arrive, which breaks the 0.15s in AC5.
- Checked with a scratch driver (not committed): with reduce motion on, it played cards and ended turns
  over 4 turns. 0.2s after each step, every card view was at rest, at scale 1 and rotation 0, with
  nothing left on the effects layer. The driver restores the saved value.
- Tests 155 → 159.
