---
id: 189
title: Sheet, screen and notice sounds
type: feature
status: done
branch: feat/189-sheet-screen-and-notice-sounds
---

## Goal
The structural moves of the interface get their Level 2 sounds ([docs/design/mcm-style-guide.md](../design/mcm-style-guide.md)
§10.2, §10.7, §15.9, §15.11): a modal is a drafting sheet laid on the desk and lifted off, a screen is a sheet run
along a rail, and a notice rings the rail lamp's small bell. Sub-navigation, the scrim and hints stay silent.

## Acceptance criteria
- [x] AC1: `ModalStack.push` plays `Sfx.SHEET_OPEN` as the modal opens; a modal pushed over another plays it 1 dB
  quieter. Closing the top modal (Esc, Close, a click outside, an action) plays `Sfx.SHEET_CLOSE` once; `close_all`
  with three modals open plays it once, not three times.
- [x] AC2: `Navigator.push` plays `Sfx.NAV_FORWARD` as the screen starts to enter and `Navigator.back` plays
  `Sfx.NAV_BACK`; `back()` at the root, `set_root` and `clear` play nothing.
- [x] AC3: `Toasts.notice` plays `Sfx.NOTIFICATION_INFO` when its toast appears, once per notice; three notices from
  one action play three bells, each at least 0.4 s after the one before (`Sfx`'s rule). A notice dropped because the
  toast stack is full still plays. `Toasts.hint` plays nothing.
- [x] AC4: A modal that opens in the same refresh as a notice (an event card's modal with its notice) plays its
  `SHEET_OPEN` 3 dB quieter, so the bell leads.
- [x] AC5: These are system sounds except a sheet or screen opened or closed by the player's own press or key, which
  plays with `input` true. With Reduce motion on, the same sounds play at the change.

## Out of scope
- The notice's three patterns (info, caution, urgent): every notice rings the info bell until 190. Drawers and
  cabinet doors (`ui.panel.*`, `ui.cabinet.*`): the board has none yet; the log drawer gets them when it becomes the
  guide's drawer.

## Design notes
- `ModalStack`, `Navigator` and `Toasts` each play their own token where the change happens, so every caller gets the
  sound. "Same refresh as a notice" is `Sfx` knowing a notification was played this frame; no component asks another.
- The sheet tokens' internal timing (the open's peak at about 130 ms, the screen's stop at about 172 ms) is shaped for
  the guide's motion durations; the navigator's current 0.22 s transition is close enough until the restyle moves it
  to the guide's wipe.
- Builds on 186; independent of 187 and 188.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_sheet_sounds::test_a_modal_lays_a_sheet_down_and_a_stacked_one_is_quieter`, `test_closing_the_top_modal_lifts_its_sheet_once`, `test_close_all_lifts_once_however_many_are_open` |
| AC2 | `test_a_screen_runs_in_and_back_and_the_root_and_clear_are_silent` |
| AC3 | `test_each_notice_rings_once_400_ms_apart_and_hints_are_silent` |
| AC4 | `test_a_modal_opened_with_a_notice_is_3_db_quieter` |
| AC5 | `test_a_sheet_the_player_opens_or_closes_is_their_input`, `test_a_screen_the_player_opens_is_their_input`, `test_with_reduce_motion_sheets_and_screens_sound_at_the_change` |

## Manual check
- [ ] Seed 5, Egypt: opening a card's details lays a sheet down with a soft paper sound; Esc lifts it off.
  Knowledge and Buy cards run in on paper; Back runs them out.
- [ ] A turn with several notices rings them one after another, never on top of each other.

## Log
- 2026-10-02: Specced from the style guide's sound system.
- 2026-10-02: Built. `ModalStack.push` / `close` / `close_all` (`STACKED_DB`, `UNDER_BELL_DB`), `Navigator.push` / `back`, and `Toasts.notice` play their tokens through `Sfx.find`. `Sfx.notified()` (a notification this frame) and `Sfx.player_acted()` (a key or mouse button this frame, noted in `Sfx._input`; `Modal._input` calls `Sfx.note_input()` because the top modal takes its keys first). Pushing a modal that is already open (bringing it back to the top) lifts the sheets above it.
- Changed for this item: two `test_key_sounds` tests now ignore the sheets that modals lay down during them (the details modal; the turn's event modal).
