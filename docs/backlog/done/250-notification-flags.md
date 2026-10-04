---
id: 250
title: Notification flags out of the rail, as in the MCM specimen
type: feature
status: done
branch: feat/250-notification-flags
---

## Goal
The engine's notices show as the MCM specimen's notification flags (guide §10.7, §15.9) instead of dark toasts
centred under the top bar: a square `sheet` strip that slides out of the rail with a hue bar, a glyph, one line and a
close ×. Urgent news (a famine, a revolution, Anarchy) stays until the player dismisses it instead of fading after
6 s. This replaces how 116 and 190 placed and timed the toasts; the bell (189, 190) is unchanged.

## Acceptance criteria
<!-- All UI tests on the real main.tscn (test_toasts.gd, test_notice_priorities.gd). -->
- [x] AC1: A flag comes out of the rail. Given a notice, when its slide has finished, then its flag's right edge
  meets the rail's left edge (within 1 px), its top is below the top bar, and it is at least `Toasts.WIDTH` (360) wide
  (wider only when its one line needs it) and at least `Toasts.MIN_HEIGHT` (48, `Tokens.SPACE_7`) tall. The flag is clipped at the rail's edge: right after the
  notice it is wholly behind the rail (its left edge at or right of the rail's left edge, out of view), and after
  0.25 s it is at rest; it slides out over 200 ms. With Reduce motion it doesn't move, and fades in instead.
- [x] AC2: The flag's look. Its panel has the `Flag` theme variation: `RAISED` fill, a 2 px `TEXT` border on its top,
  left and bottom and none on the rail side, square corners, a hard `GameTheme.PLINTH` shadow. A notice's flag shows,
  left to right, its priority's glyph (tinted the priority's hue), the notice's text on one line (never wrapped), a × button, and
  the 4 px hue bar against the rail (`Toasts.bar(flag)`, flush with the flag's right edge): info `INSIGHT` with the insight glyph, caution `WEALTH` with the shield, urgent
  `WARN` with the blocked glyph (⊘). The targeting hint's flag has text only: no glyph, no ×, no bar.
- [x] AC3: How long a flag stays. Given an info and a caution notice, then each is gone after `Anim.TOAST_TIME`
  (3 s). Given an urgent notice, then its flag is still shown after 10 s, and only goes when its × is pressed.
  Pressing a flag's × (any priority) takes it out of `shown()` at once and slides it back into the rail; it is freed
  within 0.3 s. The targeting hint stays until targeting ends, as now.
- [x] AC4: The stack. Flags stack downward, newest at the bottom, `Tokens.SPACE_2` apart; at most 3 show, and a
  fourth pushes out the oldest (urgent or not).
- [x] AC5: Flags never take the focus, and only the × takes the mouse: the layer, the flag's panel, its glyph, text
  and bar ignore the mouse, the × stops it, and every one of them has `FOCUS_NONE`. They still hide while the menu, a
  modal or a screen is open, as now.
- [x] AC6: A new game clears them. Given an urgent flag showing, when a new game starts, then no flag is shown.

## Out of scope
- The rail's per-category indicator lamps (§10.7) and collapsing old flags into a count badge.
- Moving the bell to the flag's full extension (≈ 108 ms, §15.9): it still rings as the notice arrives, ≥ 400 ms
  apart, as 189 and 190 set and test it.
- A second caption line on a flag, and per-subject glyphs: both need the engine to send more with each notice.
- Urgent flags staying until the famine or Anarchy is resolved: that needs an engine query (a later item if wanted).

## Design notes
- Choices made in place of questions (the user said to continue with the recommendations): the flags come out of
  the game's rail, which is on the right (202), so they slide leftward and their rail-side edge (bar, no border) is
  the right one; urgent stays until dismissed; one line; one glyph per priority.
- UI only: `Toasts` (`ui/toasts.gd`, still `main.toasts`) becomes the flag layer: a clip control whose right edge
  follows the rail's left edge, holding a column of flags. New API: `Toasts.WIDTH`, `MIN_HEIGHT`, `clear()`,
  `close_button(flag) -> Button`, `glyph(flag) -> TextureRect` and `bar(flag) -> Control` (each null for the hint). `BAR_WIDTH`,
  `shown()`, `texts()`, `priorities()`, `bar_role()`, `notice()`, `hint()` and `clear_hint()` stay.
- New theme variation `Flag` (PanelContainer) in `GameTheme`; flag text uses the `type.label` size.
- Motion: in 200 ms `machined` (`TRANS_QUART`/`EASE_OUT`), out 160 ms `release` (`EASE_IN`); the stack closes up
  over 120 ms. Reduce motion: a 120 ms fade each way.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_notification_flags::test_a_flag_slides_out_of_the_rail_and_rests_against_it`, `test_a_long_notice_widens_its_flag_on_one_line`, `test_with_reduce_motion_a_flag_appears_at_rest_and_fades_in`; `test_toasts::test_with_reduce_motion_toasts_fade_in_place` (kept) |
| AC2 | `test_notification_flags::test_a_flag_is_a_square_sheet_strip_open_on_the_rail_side`, `test_each_priority_has_its_glyph_and_hue_bar_in_order_left_to_right`, `test_the_targeting_hint_flag_has_text_only`; `test_notice_priorities::test_each_toast_carries_its_priority_as_a_hue_bar` (order now top to bottom) |
| AC3 | `test_notification_flags::test_info_and_caution_flags_go_after_toast_time_and_an_urgent_one_stays_until_dismissed`, `test_a_flag_slides_back_into_the_rail_when_closed`; `test_toasts::test_an_information_notice_shows_a_flag_for_toast_time` |
| AC4 | `test_notification_flags::test_flags_stack_down_newest_at_the_bottom_a_step_apart`, `test_a_fourth_flag_pushes_out_the_oldest_even_when_urgent`; `test_toasts::test_at_most_three_flags_show_newest_at_the_bottom` |
| AC5 | `test_notification_flags::test_only_a_flags_close_button_takes_the_mouse_and_nothing_takes_focus`; `test_toasts::test_toasts_hide_while_*` (kept) |
| AC6 | `test_notification_flags::test_a_new_game_clears_every_flag` |

Superseded by this item (116 AC3/AC6, 190 AC6): `test_toasts::test_a_notice_shows_a_toast_under_the_top_bar_for_toast_time`
(centred under the bar → `test_an_information_notice_shows_a_flag_for_toast_time` plus AC1's position test),
`test_at_most_three_toasts_show_newest_on_top` (→ newest at the bottom), `test_toasts_ignore_the_mouse_and_never_take_focus`
(→ AC5's, the × excepted); `test_notice_priorities::test_an_urgent_toast_stays_twice_as_long` (→ AC3's).

## Manual check
- [ ] Seed 5, end turns until a notice (a supply pile unlocking, an era's techs): its flag slides out of the rail's left
  edge under the Civilization block, with the book glyph and a blue bar against the rail, and slides back in after
  about 3 s.
- [ ] Reach a famine (end turns without feeding pop): the red flag with ⊘ stays past several seconds and turns; its ×
  slides it back in. A × click doesn't play a card or move keyboard focus.
- [ ] Three notices at once (an era change): they stack downward, newest at the bottom; a long line widens its flag
  leftward, still flush with the rail.
- [ ] Double-click Settler (or another targeted card): the hint shows as a plain flag (no glyph, ×, bar) until you pick
  or press Esc.
- [ ] Settings → Reduce motion on: flags fade in and out in place. Day mode: the flag is the light sheet with an ink rule.

## Log
- `Toasts` (`ui/toasts.gd`) is now the flag layer, built on the rail (`Toasts.new(main.sidebar, covered)`): a clip
  control ending at the rail's left edge holds a right-aligned column of flags. New: `WIDTH`, `MIN_HEIGHT`, `clear()`
  (called by `main.start_game`), `glyph()`, `close_button()`, `bar()`. The theme gains `Flag`, `FlagText` and
  `FlagClose`. The × is printed at `TYPE_TITLE`: Barlow's × is small at the body size.
- A screenshot showed the hue bar inset by the strip's padding; the strip has no vertical padding now, so the bar runs
  the flag's full height (the row centres in `MIN_HEIGHT`).
- Follow-ups (not specced): the bell at the flag's full extension (§15.9, shifts `test_sheet_sounds`' times); rail lamps
  and the count badge (§10.7); urgent flags clearing when the famine or Anarchy ends (an engine query).
- Test fix agreed with the user at green: `test_a_flag_slides_out_of_the_rail_and_rests_against_it` checked "wholly
  behind the rail" after two frames (1/60 s), when the 200 ms slide is already ≈ 29% out. It now checks right after
  the notice, before a frame passes, that the flag sits a full width right of its place; the rest is unchanged.
