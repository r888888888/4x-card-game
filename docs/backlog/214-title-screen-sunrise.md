---
id: 214
title: The title screen's sun over a hill, rising and setting with the keys
type: feature
status: review
branch: feat/214-title-screen-sunrise
---

## Goal
The title screen's right half (213's `Art`) shows the chosen art: a banded sun rising over one bare green hill
([title-screen-ledger-hill.html](../design/title-screen-ledger-hill.html)). It rises into place when the screen opens, then
rests. Hovering or focusing New game brings on the day, and Exit lets the sun sink into a sunset: the sun reddens, the sky
warms in bands, the hill deepens.

## Acceptance criteria
- [x] AC1: `SunriseArt` (a `Control` that draws itself) draws, in a 600 × 675 design space scaled to fill its rect
  (cropped, centred, as SVG `slice`): four sky bands, the sun (a disc of radius 150 centred at x 300, with five
  horizontal gaps across its lower half, each thicker than the one above), and the hill (an elliptical dome 720 wide
  whose crown is 150 above the horizon at y 520, filled down to the bottom edge). The gaps are true gaps: the sky
  shows through them.
- [x] AC2: `SunriseArt.warmth(height)` (static) gives how low the sun is from its centre's height above the horizon:
  0.0 at 200 or more, 1.0 at 10 or less, smoothstep between (`warmth(105)` is 0.5). It drives the low sun: the sun is
  drawn as `SUN` blended toward `SUN_LOW` by 0.85 × warmth; each sky band's alpha is its base (0.55, 0.32, 0.22, 0.12
  from the horizon up) × warmth; the hill is `HILL` blended toward `HILL_LOW` by 0.6 × warmth, then toward `SHADOW` by
  0.25 × warmth. Given warmth 0, no band is drawn and the sun and hill are their plain colours.
- [x] AC3: Entrance, when the title screen opens (launch, or back from a game): the sun's centre rises from 170 below
  the horizon to 220 above it in 2.6 s (`Anim.MACHINED`); the hill rises 120 px into place in 0.9 s, starting at 0.15 s.
  Then nothing moves: once settled, `SunriseArt` stops processing (`is_processing()` false) and draws nothing new while
  the player is idle (guide rule 4).
- [x] AC4: Given the screen at rest, when New game is hovered or focused, the sun eases up 70 px (a critically damped
  spring, no overshoot); when Exit is hovered or focused, it sinks 190 px, which carries it into the low-sun warmth of
  AC2; when the pointer and focus leave (or go to Settings), it eases back to rest. It processes only while moving.
- [x] AC5: With Reduce motion: the screen opens with the art at rest (no rise), and the keys' changes jump to their end
  state at once; no tween or processing runs.
- [x] AC6: The art's colours are `Palette` roles named for it (`SUN`, `SUN_LOW`, `SKY_LOW`, `SKY_HIGH`, `HILL`,
  `HILL_LOW`) with Night and Day values, and Day mode redraws it at once (183).

## Out of scope
- An idle loop (the title screen follows rule 4 like everything else). Sounds for the art.

## Design notes
- Needs 213 (the `Art` slot and the keys it listens to).
- Colours, from the mock: `SUN` = the ochre plane (d9a441 both modes), `SUN_LOW` = `ACCENT`'s value, `SKY_LOW` = the
  brick plane (Night e07a63, Day c9705c), `SKY_HIGH` = ochre, `HILL` = the sage plane (`TERRITORY`'s values),
  `HILL_LOW` = the teal plane (`TECH`'s values). New roles rather than borrowing card-type names, so the art can drift
  from the cards.
- The art's geometry is in its own design space (600 × 675), not spacing, so its numbers aren't `Tokens` steps; keep
  them as named constants in `ui/sunrise_art.gd`.
- Band rects (y, height from the horizon up): 474/46, 416/58, 346/70, 260/86. Gaps across the sun at 0.15, 0.33,
  0.51, 0.69, 0.86 of the radius below its centre, heights (4 + 3.5 i) × r / 150.
- Tests drive time with the art's own clock (as `Sfx.set_clock` or the navigator's tween tests), not real frames.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_sunrise_art::test_the_art_fills_its_rect_from_a_600_by_675_design_like_svg_slice`, `test_the_suns_lower_half_has_five_gaps_each_thicker_than_the_one_above` |
| AC2 | `test_warmth_is_a_smoothstep_from_200_down_to_10`, `test_warmth_drives_the_sun_the_sky_bands_and_the_hill` |
| AC3 | `test_the_sun_rises_and_the_hill_comes_up_then_nothing_moves` |
| AC4 | `test_new_game_brings_on_the_day_and_exit_a_sunset_and_leaving_rests` |
| AC5 | `test_with_reduce_motion_the_art_rests_and_jumps` |
| AC6 | `test_the_arts_colours_are_palette_roles_in_night_and_day`, `test_day_mode_redraws_the_art` |

Hooks the tests imply: `StartScreen.sunrise` (a `SunriseArt` in `art`), `use_manual_clock()`, `advance(seconds)`,
`sun_height()`, `hill_offset()`; static `warmth`, `sun_color`, `band_alpha`, `hill_color`, `slice_scale`, `gap_rects`;
constants `DESIGN`, `SUN_X`, `SUN_RADIUS`, `HORIZON`, `HILL_WIDTH`, `HILL_CROWN`. Whether the gaps are true gaps (the
sky through them) and the look itself are the manual check: the drawing isn't read back.

## Manual check
- [ ] Launch in Night and Day at 1280×720 and 1920×1080: compare with `title-screen-ledger-hill.html` B1.1 at 1× and ¼×.
- [ ] Hover Exit: a sunset (red sun, warm bands, a deeper hill), not a dimmed scene; hover New game: full day.
- [ ] In Night, the sky bands don't read as muddy brown (if they do, raise Night's band alphas).

## Log
- Specced 2026-10-02, split from 213 after the user chose B1.1 (one hill) in `title-screen-ledger-hill.html`.
- 2026-10-02: Built. `ui/sunrise_art.gd` (`SunriseArt`, `StartScreen.sunrise` in `art`): bands, a sun drawn as disc slices
  (the gaps are empty, so the sky shows through), the dome hill; `enter()` (from `StartScreen.opened()`, which main calls
  as the title screen opens) and `aim(offset)` on the exact critically damped step; `Palette` roles `SUN`, `SUN_LOW`,
  `SKY_LOW`, `SKY_HIGH`, `HILL`, `HILL_LOW`. The key focused by default doesn't move the sun until the focus moves.
  Changed: 213's `test_the_title_screen_is_a_ledger_left_and_an_empty_art_half_right` now expects the art in `Art`.
