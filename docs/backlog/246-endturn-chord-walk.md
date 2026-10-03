---
id: 246
title: End turn sounds a vibraphone chord that walks D, Bm, G, A from turn to turn
type: feature
status: review
branch: feat/246-endturn-chord-walk
---

## Goal
Ending a turn sounds like a small musical step instead of a mechanical drum advance: after the key press and the
relay, a Dmaj9 vibraphone chord with a ~2 s tail, and successive turns walk I–vi–IV–V (D, Bm, G, A) so a run of turns
forms a phrase instead of repeating one sound. Chosen by ear on `spike/endturn-chords`
(`docs/design/endturn-chord-options.html`, option A, "Full sequence", "Instead of the drum advance", "Walk I–vi–IV–V").

## Acceptance criteria
- [x] AC1: Given `Sfx.ENDTURN_TURN`, then `Sfx.files` lists four variants, `ui/ui_endturn_turn_a.wav … _d.wav` (a = D,
  b = Bm, c = G, d = A), and every other Level 2 token still has two; each of the four files exists.
- [x] AC2: Given main on turn 1, when the player presses and releases End turn and the turn ends, then the sounds are
  `ui.endturn.press`, `ui.endturn.commit` and `ui.endturn.turn` at the same times as today (the turn 0.12 s after the
  commit), and the turn sound plays variant 0 (a, D).
- [x] AC3: Given the turn that ends is T, then `ui.endturn.turn` plays variant (T − 1) mod 4: ending turns 1, 2, 3, 4,
  5 plays a, b, c, d, a. The walk follows the game's turn, so a new game or a loaded one starts from its own turn,
  not from where the last game left off.
- [x] AC4: Given `Sfx.play(token, …)` with a variant for a token that has variants, then that file plays and
  `played()` records the variant; with no variant given, Level 1 and 2 tokens keep their random, no-repeat choice.
  A variant outside the token's range is an error (`push_error` naming the token and the variant) and nothing plays.
- [x] AC5: Given Reduce motion, when the turn ends, then `ui.endturn.turn` plays at once with the commit (as today)
  and still plays variant (T − 1) mod 4.
- [x] AC6: Given a press that doesn't end the turn (blocked, or dragged off the key), then no `ui.endturn.turn` plays
  and the walk doesn't advance: the next turn that ends plays the variant for its own T.

## Out of scope
- The other end-turn sounds (`ui.endturn.press`, `ui.endturn.commit`) and the choreography's timing are unchanged.
- No new setting: the Interface sounds toggle mutes it like every Level 2 sound.
- Balance, bot and sim: unaffected (UI only).
- Moving the token to the Game bus or changing voice limits: only if the manual check finds clicks dropped (Log it).

## Design notes
- **Sfx API**: `play(token, delay := 0.0, input := false, gain_db := 0.0, variant := -1)`; `-1` keeps the randomizer.
  A chosen variant plays that file's stream directly (load and cache per file like `stream()`). The `played()`
  record gains `variant` (-1 when random). `end_turn_key.gd` passes `(turn - 1) % 4` using the turn it ended
  (`_end_turn` already records `turn` before `e.end_turn()`). The variant count lives in `Sfx`
  (an override of `VARIANTS` for `ENDTURN_TURN`, e.g. `_VARIANT_OVERRIDES := {ENDTURN_TURN: "abcd"}`), not in the key.
- **Files**: rendered by `docs/design/sound-export.html`: replace its `ui.endturn.turn` token with the spike's
  vibraphone (partials 1:4:10, motor tremolo 5.2 Hz, depth 0.35), voicing D3 D4 F♯4 A4 C♯5 E5 shifted diatonically by
  0, −2, −4, −3 degrees, decay ×1.0, room 1.2 s at 18 %, and let `paths()` give it four files whose variants are the
  four chords (not the L2 pitch variants). Copy the synthesis from `spike/endturn-chords`
  (`docs/design/endturn-chord-options.html`: `INST.vib`, `shiftDia`, `WALK`). The spike's files peak at about
  −17 dBFS (the level that sounded right next to the press); set the token's `level` in the export page to match.
- **Style guide**: amend §15.12's TURN row and the §16 token table row for `ui.endturn.turn` (a vibraphone chord
  walking I–vi–IV–V, ≈ 2.2 s, `tonal`), and note under §16.8 that this is the one every-turn sound allowed a tail and
  a melody, kept below the milestone chords. The "short drum-advance" wording and its "250–400 ms" duration go.
- **Tests that change**: `test_sfx::test_every_token_has_its_files` (2 → 4 for this token, AC1); the end-turn timing
  tests in `test_key_sounds.gd` keep their times and gain the variant check.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_sfx::test_the_end_turn_chord_has_four_files_one_per_chord`, `test_sfx::test_every_token_has_its_files` (changed: 4 for this token) |
| AC2 | `test_key_sounds::test_end_turn_plays_the_chord_for_the_turn_it_ends` (turn 1, D, at 0.185 s), `test_key_sounds::test_end_turn_presses_heavy_and_closes_a_relay_when_the_turn_ends` |
| AC3 | `test_sfx::test_the_turn_that_ends_picks_its_chord`, `test_key_sounds::test_end_turn_plays_the_chord_for_the_turn_it_ends` (turns 1, 3, 5) |
| AC4 | `test_sfx::test_a_chosen_variant_plays_that_file_and_is_recorded`, `test_sfx::test_without_a_variant_the_choice_stays_random`, `test_sfx::test_a_variant_out_of_range_plays_nothing` |
| AC5 | `test_key_sounds::test_with_reduce_motion_the_chord_still_follows_the_turn` |
| AC6 | `test_key_sounds::test_end_turn_that_owes_a_discard_comes_up_like_any_key` (no turn sound); the walk can't advance because the variant comes from the turn (AC3) |

## Manual check
- [ ] End five turns in a row: the chords go D, Bm, G, A, D after the key and the relay; no drum advance.
- [ ] Level: the chord sits under the milestone chords (found a city or finish a tech on the same game) and doesn't
  feel loud on the twentieth turn. If it does, lower the export page's level 3–6 dB and re-render.
- [ ] Click a hand card or a button right after End turn, within the chord's tail: its press still sounds.
- [ ] Start a new game after ending three turns: its first End turn plays D again.

## Log
- Explored on `spike/endturn-chords` (12 options on `docs/design/endturn-chord-options.html`); the user picked the
  Dmaj9 vibraphone walk. Assumption made without asking: the walk follows the turn number (AC3) rather than a
  counter that carries across games, so every game opens on D.
- AC4's out-of-range test first missed the criterion's "push_error naming the token and the variant"; added
  `expect_error` for both cases at green (stricter, not weaker).
- The turn → chord mapping (`Sfx.turn_variant`) lives in `Sfx`: it's which sound file plays, not a game rule.
- Files rendered by `docs/design/sound-export.html` (its `ui.endturn.turn` now walks; `walk: 4`, room 1.2 s): each
  peaks at −17 dBFS, about 2.2 s. Style guide amended in §15.12, the Level 2 table, the families table, §16.7, §16.8.
- Each chord holds an Interface voice for ≈ 2.2 s (6 voices); watch for dropped Level 1 clicks right after End turn
  (Manual check). If they drop, a follow-up could move the token to the Game bus.
