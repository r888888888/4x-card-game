---
id: 104
title: Screen header and transitions for every navigated screen
type: feature
status: review
branch: feat/104-screen-header-and-transitions
---

## Goal
Opening the territory view (101) gives no sign that you went somewhere: nothing names the place, the Back button sits
mid-row, and the view just appears. Make "where am I, how do I get back" a pattern of the navigation stack (103), so
every screen pushed on a `Navigator` gets it for free: a shared header (a back button naming the screen below, and a
breadcrumb naming where you are) and a transition in and out.

## Acceptance criteria
<!-- Navigator unit tests on plain Controls (tests/test_navigator.gd), then the real main scene. -->
- [x] AC1: Titles. `set_root(screen, focus, title)` and `push(screen, focus, title)` take a title; `titles()` returns
  the stack's titles bottom first, e.g. `["Realm", "River Meadow"]` after pushing River Meadow's view over the Realm.
  `back()` drops the top title.
- [x] AC2: The header. `ScreenHeader` (a Control built with a `Navigator`) shows, for the top screen, a back button
  reading "← <title of the screen below>" and a breadcrumb reading the titles joined by " › " (e.g.
  "Realm › River Meadow"). Pressing the back button calls `back()`. At the root it shows the root's title and no
  back button. It updates on the navigator's `changed`.
- [x] AC3: Used by every navigated screen. The new game and settings screens show a header over "Main menu" (the
  title screen's title): back button "← Main menu", breadcrumbs "Main menu › New game" and "Main menu › Settings".
  The territory view shows "← Realm" and "Realm › <territory name>". Their old Back buttons are these header back
  buttons (`back_button` still names them, so Enter, Tab and Esc behave as in 099 and 101).
- [x] AC4: Transition in. `push(..., from: Rect2)` with Reduce motion off starts the new screen scaled down over
  `from` (the clicked card's rect) and grows it to its full rect in `Anim.SCREEN_TIME`; without `from` it fades in over
  `Anim.SCREEN_TIME`. With Reduce motion on it only fades in. After `Anim.SCREEN_TIME` the screen's scale is 1 and its
  alpha 1 in every case.
- [x] AC5: Transition out. `back()` reverses the push: a screen pushed from a rect shrinks back to that rect, others
  fade out, then it hides; the screen below is shown at once. Keys and clicks go to the screen below straight away
  (the leaving screen ignores input), and a push or back during a transition finishes the old one first.
- [x] AC6: Clicking a territory card opens its view growing out of that card; Back shrinks it back into the card.

## Out of scope
- The territory view's own layout (frame, large territory card, empty slots): 105.
- Moving the menu, card details, Knowledge, Buy Cards and the event modal onto a navigator.

## Design notes
- `Navigator` gets a title per screen and optional `from: Rect2`; `ScreenHeader` lives in `ui/screen_header.gd`.
- `Anim.SCREEN_TIME` (about 0.22 s) next to the other timings; calm mode via `UIKit.calm()`.
- Changed existing tests (name each at the red checkpoint): `test_start_screen` expects "Back" as the back buttons'
  text in two places; they become "← Main menu".
- Add to CLAUDE.md's UI design section: "A screen you navigate to goes on a `Navigator` with a title, so it gets the
  shared header (a back button naming where it goes, a breadcrumb naming where you are) and enters and leaves with a
  transition (a fade with Reduce motion)."

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_navigator::test_titles_follow_the_stack` |
| AC2 | `test_navigator::test_the_header_names_the_screen_below_and_the_path` |
| AC3 | `test_screen_header::test_the_new_game_and_settings_screens_have_a_header`, `test_the_territory_view_has_a_header` |
| AC4 | `test_navigator::test_push_from_a_rect_grows_the_screen_out_of_it`, `test_push_without_a_rect_fades_in`, `test_with_reduce_motion_a_push_only_fades` |
| AC5 | `test_navigator::test_back_reverses_the_push_and_the_screen_below_takes_input_at_once`, `test_a_new_step_finishes_the_running_transition_first` |
| AC6 | `test_screen_header::test_a_territory_view_grows_out_of_its_card_and_shrinks_back` |
| Changed | `test_start_screen` (two Back texts → "← Main menu"); `test_button_widths::test_title_settings_and_new_game_columns_share_one_width` (Back left the settings and new game columns for the header; it fits its text) |

## Manual check
- [ ] Click a territory: the view grows out of the card, headed "← Realm   Realm › <name>"; Back shrinks it into the
  card. With Reduce motion on, both are short fades.
- [ ] Title → New game → Back and → Settings → Back: the header reads right, and the screens fade.

## Log
- 2026-09-30: Specced after the user said the territory view gives no sign you're in it, and asked for a general
  pattern. The user chose the header, transitions and the territory layout (105); not hiding the other sections.
- 2026-09-30: Built. `Navigator` gets `animated`, a title per screen (`titles()`), `push(..., from: Rect2)`, and
  `Navigator.is_shown(screen)`: a leaving screen is marked (meta `navigator_leaving`), takes no clicks
  (`mouse_behavior_recursive`) and, in a container, leaves the layout (`top_level`) so the screen below takes its
  place at once; a new push or back first completes the running tween. Growing uses a pivot computed so the scaled
  screen lies exactly over the card's rect. `ScreenHeader` (`ui/screen_header.gd`) follows the navigator except while
  its own screen is leaving. The new game and settings screens lost their title labels, Back buttons and
  `back_requested`; the territory view's header back calls its `close` (which returns the card focus, 101) and its
  root title is the Realm section's heading. `main.nav` and the territory view's nav are animated; the screens'
  `is_open()` use `is_shown`. `with_reduce_motion` / `wait_screen_transition` are in `test_case.gd`.
- 2026-09-30: The rule is in CLAUDE.md's UI design section.
