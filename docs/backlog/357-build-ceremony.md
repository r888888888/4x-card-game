---
id: 357
title: Building, recruiting and upgrading end in a ceremony with an event sound
type: feature
status: red-review
branch: feat/357-build-ceremony
---

## Goal
Building on a territory is the player's main way of growing it, but today the new card just pops into its slot in
silence. Give it a moment: a lamp ring, a 12-ray starburst and a BUILT (or RECRUITED) stamp on the new card, with an
event sound that rings out, so a build feels like an achievement. Designed and chosen on `spike/build-fanfare` (the
"Starburst" and "Stamp" styles together, without the card flying from the sheet; the "Civic" sound, lengthened; the
"Drum" sound for units) and written into the style guide: §9.4 (the Build ceremony row), §10.8, §11.6, §16.4 rule 5.

## Acceptance criteria
- [ ] AC1 (engine): Given a game where Farm can be built on Homeland (as in `test_build_modal`), when `build("farm",
  home)` succeeds, then the engine emits `built(uid)` once, with the new Farm's uid, before `changed`. When `build`
  refuses (say with too little food), `built` is not emitted. Settling a territory into a city, playing a hand card and
  an effect's `create` don't emit it.
- [ ] AC2 (engine, upgrade): Given a Farm on Homeland and its upgrade buildable on it (as in `test_upgrade_ribbons`),
  when the upgrade is built on the Farm, then `built` is emitted once with the upgrade's uid, and `upgrade_base` of that
  uid is the Farm's uid.
- [ ] AC3 (a building): Given the main scene with Homeland's view open and Reduce motion off, when the Build modal's
  Build Farm is pressed, then the Farm's view rests in its slot at full scale (no pop-in: its `fx_scale` is `Vector2.ONE`
  from the first frame); a build ceremony is on the fx layer over that card, whose parts are ring, rays and tag, with the
  tag reading "BUILT" and the ring and rays in `Palette.BUILDING`; `ui.milestone.build` is played once, `Anim.BUILD_DELAY`
  (0.16 s) after the press, and `ui.confirm` isn't played; and once `Anim.BUILD_CEREMONY_TIME` has passed the ceremony is
  gone from the fx layer.
- [ ] AC4 (a unit): Given the same, when Recruit Warriors is pressed, then the Warriors' view gets the ceremony with ring,
  rays and a tag reading "RECRUITED", in `Palette.UNIT`, and `ui.milestone.recruit` is played once (not
  `ui.milestone.build`).
- [ ] AC5 (an upgrade): Given a Farm on Homeland and the view open, when its upgrade is built from the Build modal, then
  the ceremony plays on the Farm's view with ring and rays and no tag, and `ui.milestone.build` is played once.
- [ ] AC6 (other arrivals): Given the view open, when a card reaches it any other way (a building created by an effect, a
  unit moved in from another territory), then its view arrives as it does today (pop-in or flight) with no ceremony and
  no build sound.
- [ ] AC7 (Reduce motion): Given Reduce motion on, when Build Farm is pressed, then the ceremony shows ring, rays and tag
  at once at their full extent (ring 12 px out, rays 24 px long, the tag at its rest place, all fully opaque), they hold
  for 1.5 s and are then gone; `ui.milestone.build` is still played once.
- [ ] AC8 (the sounds): `Sfx.MILESTONE_BUILD` (`ui.milestone.build`) and `Sfx.MILESTONE_RECRUIT` (`ui.milestone.recruit`)
  are Level 3 tokens with their files (`events/ui_milestone_build.wav`, `events/ui_milestone_recruit.wav`), listed in the
  guide's §14.1 Level 3 table (so `test_sfx`'s guide check covers them), and `EventSounds`' order ranks them below every
  other event.

## Out of scope
- The card flying from the Build sheet into its slot (the spike's "Delivery"): not chosen.
- The spike's other sound candidates (stamp, hammer, crane) and the blueprint style.
- Any change to how cards arrive outside a build (AC6).
- Balance and the build rules themselves.

## Design notes
- **Engine:** a new signal `built(uid: int)` on the engine, emitted by `BuildMenu.build` after the card is put into play
  and before `changed`, like `milestone`. The UI reads `upgrade_base(uid)` to tell an upgrade from a card with its own
  view, and the card's type for building vs unit. No state is stored: the signal is per action.
- **UI:** a `BuildCeremony` overlay (from the spike's `ui/build_fanfare.gd`, cut to ring, rays and tag) on main's fx layer,
  following the card's rect and freeing itself. Main (or a small listener node, like `EventSounds`) notes the uids from
  `built`; `BoardViews.place`, creating the view of a noted uid, attaches it in place instead of `pop_in` and starts the
  ceremony; for an upgrade it starts the ring and rays on the base's view at the next sync. The spike's static hand-off
  from `BuildModal` goes away: the modal only calls `build`.
- **Timing constants** go in `Anim`: `BUILD_DELAY` 0.16 (the sheet's close), ring 0.45 s to 12 px (`Tokens.SPACE_3`),
  rays 0.4 s to 24 px (`Tokens.SPACE_5`) from 8 px off the edge (`Tokens.SPACE_2`), the tag 0.12 s after the ring: in
  0.09 s with a 4 px drop (`Tokens.SPACE_1`), hold 0.9 s, out 0.14 s; `BUILD_CEREMONY_TIME` the whole run (≈ 1.4 s).
  Reduce motion: hold 1.5 s (§9.5).
- **Sounds:** the spike's `ui.build.civic` (the lengthened version: 2 s notes, a 1.2 s room, a low D under the chord, peak
  −17 dBFS, ≈ 1.7 s) becomes `ui.milestone.build`, and `ui.recruit.drum` becomes `ui.milestone.recruit`, both rendered by
  `docs/design/tools/sound-export.html` (copy their definitions from the spike, renamed, level 9). Add their two rows to
  the guide's §14.1 Level 3 table in this item, not before: `test_sfx` reads that table, and rows without constants
  would turn the suite red. `EventSounds.SOUNDS` gets them last (an era, a raid or a city in the same action wins).
- Playing the build sound ducks the system's routine sounds for ≈ 1.7 s (Level 3, §16.4 rule 1); the guide accepts this
  (§16.4 rule 5). Note in the Log if the counters going quiet after a build reads badly in play.
- The spike's F7/F8 cycling and the candidate files stay on `spike/build-fanfare`; none of it merges.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_built_signal::test_building_emits_built_with_the_new_card_before_changed`, `::test_recruiting_emits_built_with_the_unit`, `::test_a_refused_build_emits_nothing`, `::test_other_arrivals_emit_no_built`, `::test_settling_a_territory_emits_no_built` |
| AC2 | `test_built_signal::test_building_an_upgrade_emits_built_with_the_upgrade` |
| AC3 | `test_build_ceremony::test_a_building_built_rests_in_its_slot_under_a_ceremony`, `::test_the_ceremony_goes_once_it_has_run` |
| AC4 | `test_build_ceremony::test_a_unit_recruited_gets_the_ceremony_and_the_drum` |
| AC5 | `test_build_ceremony::test_an_upgrade_plays_ring_and_rays_on_its_base` |
| AC6 | `test_build_ceremony::test_a_card_played_from_the_hand_arrives_without_a_ceremony` (plus AC1's engine tests) |
| AC7 | `test_build_ceremony::test_reduce_motion_shows_the_ceremony_whole_and_holds_it` |
| AC8 | `test_sfx::test_the_build_sounds_are_events_in_the_guide`, `test_build_ceremony::test_a_build_that_adds_an_era_plays_only_the_era` |

## Manual check
- [ ] Build a Farm: the card is in its slot as the sheet closes, then the ring blooms, the rays draw out and fade, and
  BUILT snaps onto its corner and wipes away; the civic sound rings out over about two seconds.
- [ ] Recruit a unit: the same in bronze, RECRUITED, with the drum and horn.
- [ ] Build an upgrade: the ring and rays play on the building it upgrades, no stamp, with the civic sound.
- [ ] Night and Day modes: the rays and tag read on both.
- [ ] Reduce motion: everything appears at once, holds and goes; the sound still plays.
- [ ] Build twice in a turn: the second ceremony and sound play in full.

## Log
- 2026-10-06: spec'd from `spike/build-fanfare` (mock: `docs/design/mocks/build-fanfare-options.html` there). Units get
  the ceremony with the drum sound; upgrades get ring and rays on their base, both by the user's choice.
