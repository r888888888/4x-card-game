---
id: 295
title: Build buildings from a build menu instead of buying their cards
type: feature
status: done
branch: feat/295-build-menu-for-buildings
---

## Goal
Today a building is a card you buy into your discard, wait to draw, then play: the payoff from buying it arrives
several turns late and at random, and it cost a buy price on top of its build cost. After this, buildings aren't cards
in your deck at all. The game keeps a **build menu**: techs unlock its entries, and you build an unlocked building
straight onto a settled territory for 1 action plus its cost, whenever you can pay. The deck is what your people do
(action cards); the build menu is your civilization's infrastructure. Follows the build-menu spike (see Design notes).

## Acceptance criteria
- [x] AC1: Given config `build_menu` `{"farm": {}}`, a settled territory with a free slot and a free worker, 2 actions
  left and 3 food, when `build("farm", territory)` is called, then it returns true; a new Farm (a fresh uid) is in the
  tableau on that territory; food is 1 (Farm costs 2 food, after discounts as for playing it); actions left is 1;
  `card_played` is emitted with the Farm's uid and the territory as target, and its `play` effects resolve; the hand,
  deck and discard are unchanged. `build_menu()` returns `["farm"]` (unlocked entries, in config order). With
  `territory` −1 and exactly one territory that takes it, it builds there.
- [x] AC2: `build_error(card_id, territory)` is "" exactly when `build` would succeed, and `build` returns false and
  changes nothing otherwise. Each refusal, with its message: game over or a decision owed (`_blocked_error`'s message);
  a card with no build-menu entry ("Scout can't be built."); a locked entry ("Granary isn't unlocked yet."); no actions
  left ("No actions left this turn."); under Anarchy (Anarchy's play refusal, as for a hand card); short of its cost
  ("Farm needs 2 food (you have 1)."); no territory takes it (the messages playing it gives: "No territory with a free
  slot.", "No territory with a free worker.", or its requires message); a territory that isn't a valid target ("That
  target isn't valid.", or its requires message when only its terrain is wrong); `territory` −1 with two or more valid
  territories ("Choose a territory for Farm."). `build_targets(card_id)` lists the territories it could go on now
  (slot, worker, terrain), whatever it costs; [] for a locked or unknown entry.
- [x] AC3: Given `build_menu` `{"granary": {"locked": true}}` and a tech whose effect is `{"op": "unlock", "card":
  "granary"}`, when the tech is learned, then `build_menu()` includes "granary", `build_error("granary", t)` no longer
  says it is locked, and the notice "Granary can now be built." is logged; no Granary card is created in any zone.
  The unlock effect's card text reads "Granary can now be built." (an action card's unlock keeps "… can now be bought
  in the supply.").
- [x] AC4: Given an entry with `"once": true` (a wonder), when it has been built once, then `build_error` refuses
  ("Granary is already built.") for the rest of the game, even if that copy leaves play; an entry without `once` can be
  built any number of times (three Farms on a territory with 3 free slots and workers, 6 food and 3 actions).
  `GameState.copy()` copies which entries are unlocked and which `once` entries are built.
- [x] AC5: The loader validates config `build_menu` (`{card_id: {locked?, once?}}`, default `{}`): an unknown card
  ("build_menu: unknown card 'x'"); a card that isn't a building or unit ("build_menu: 'scout' is an action"); `locked`
  or `once` not a bool; an unknown field (a warning); a card also in `supply` ("build_menu: 'farm' is also in the
  supply"). An `unlock` effect must name a supply pile or a build-menu entry (today: a supply pile). Buildings and units
  stay allowed in `deck` and `supply` (the rules fixtures use them; see Design notes).
- [x] AC6: Content (real data): no building is in `deck` or `supply`; every building that a tech created or unlocked
  before this item has a build-menu entry that the same tech unlocks; every locked entry is unlocked by some tech;
  every building tagged `wonder` has `once`; no tech `create`s a building into a zone other than the tableau; and the
  starting resources pay for at least one entry unlocked from turn 1 that every listed civilization's home can take.
  (Replaces the three content tests that assume buildings in the starting deck.)

## Out of scope
- Units in the build menu (296), the territory view's Build… (297), the bot (298).
- Numbers: what each building costs now that the buy price is gone, and wealth income. A balance item after 298.
- Pile counts for buildings: the build menu has none (slots and workers limit building); `once` replaces the
  one-copy wonders.

## Design notes
- **Data format.** New config `build_menu`: `{"farm": {}, "granary": {"locked": true}, "pyramids": {"locked": true,
  "once": true}, …}`, in the order the build menu lists them. Real data moves every building out of `supply` (and Farm 2,
  Hunters' Camp 1 out of `deck`) into `build_menu`; the piles open on turn 1 today (Farm, Fishing Huts, Hunters' Camp,
  Shrine, Palisade) become unlocked entries, the locked piles become locked entries. Each tech's `create` (to the
  discard) + `unlock` pair for a building becomes the `unlock` alone; the wonders (created only today) become locked
  `once` entries their techs unlock. Sumer's start effect that creates a Farm in the tableau stays.
- **Engine API.** `build_error(card_id, territory_uid := -1)` / `build(card_id, territory_uid := -1)` in GameEngine's
  actions (after `buy`); queries `build_menu()`, `build_targets(card_id)`. State: the unlocked entries and the built
  `once` entries in `GameState`. Rules in `engine/supply.gd` or a new `engine/build_menu.gd` (supply.gd is small; split
  if it grows past a screen). Building reuses the play step: a new copy played onto the territory, so `play` effects,
  `card_played`, discounts (type and tag; Egypt's −3 wealth on wonders, Sumer's −1 on farms) and Anarchy rules match
  playing the card. Phoenicia's `supply: true` discount now only touches action cards.
- **Why buildings stay legal in `deck`.** Nearly every rules test deals a `{"farm": 10}` deck. Forbidding buildings in
  the deck would rewrite hundreds of tests for no rule gain, so playing a building card from the hand stays a working
  rule; only the real data stops using it (AC6). Likewise a `create` of a building into the discard keeps working.
- **Blocked actions.** Add `build` to `test_blocking`'s action table.
- **Items to revise when this lands:** 289 (tech details' Gives captions say "1 to your discard · in the supply"; a
  build-menu entry should read e.g. "build menu"), 286 (wonders built over turns: "playing a wonder" becomes building
  it), 166 and 167 (see 296).
- **Spike findings** (`spike/rotating-supply`, commits a570721 and 0a53674; unmerged):
  - Sending bought buildings to the hand instead of the discard clogged the hand: with draws "up to hand size", a hand
    of unaffordable buildings draws nothing. Bot games kept over the hand limit about 24 turns in 100, and discarded
    about two-thirds of the buildings they bought unbuilt.
  - A rotating 6-card market plus 6 staples worked mechanically but needs far more distinct cards than the game has
    (9 action cards); tech unlocks bunched up and pushed market cards out. Dropped.
  - The build menu (this item) in bot games, 20 seeds per strategy, old rules → build menu: score growth 107 → 135,
    wealth 80 → 106, tall 54 → 54, baseline 203 → 178, wide 229 → 187. Wealth went from piling up unspent (baseline
    ended turns with 287 on average) to scarce (24): buildings now compete with buying cards. Baseline and wide played
    fewer Settlers (28 → 13, 34 → 25 per game) because they used to buy them with wealth dumped before Anarchy's drain;
    298 gives the bot a deliberate Settler rule.
  - Building from the Buy screen felt detached from the board; hence Build… on the territory view (297).

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_build_menu::test_building_puts_a_new_copy_on_the_territory_for_an_action_and_its_cost`, `test_building_resolves_play_effects_and_pays_the_discounted_cost`, `test_with_no_territory_named_it_builds_on_the_only_one_that_takes_it` |
| AC2 | `test_build_menu::test_build_refuses_with_a_reason_and_changes_nothing`, `test_build_refuses_without_a_slot_or_a_worker`, `test_build_refuses_an_invalid_target_or_an_unnamed_choice`, `test_build_targets_ignore_cost_and_are_empty_for_a_locked_or_unknown_entry`, `test_build_refuses_when_the_game_is_over_or_a_decision_is_owed`; `test_anarchy::test_under_anarchy_nothing_is_built_from_the_build_menu`; `test_blocking` (a `build` row) |
| AC3 | `test_build_menu::test_a_tech_unlocks_a_build_menu_entry_without_creating_a_card`, `test_an_unlock_of_a_building_reads_can_now_be_built` |
| AC4 | `test_build_menu::test_a_once_entry_is_built_once_for_the_whole_game`, `test_an_entry_without_once_builds_any_number_of_times`, `test_a_copy_keeps_what_is_unlocked_and_built` |
| AC5 | `test_build_menu::test_build_menu_loads_with_defaults`, `test_build_menu_validation`, `test_an_unlock_may_name_a_build_menu_entry` |
| AC6 | `test_content::test_buildings_are_in_the_build_menu_not_the_deck_or_supply`, `test_every_locked_build_menu_entry_is_unlocked_by_a_tech_and_back`, `test_every_wonder_is_a_once_entry`, `test_no_tech_creates_a_building_outside_the_tableau`, `test_every_civilization_can_build_on_its_home_on_turn_1`, `test_every_listed_civilization_has_its_own_home_that_takes_most_open_entries`; changed: `test_eras_1_and_2_each_have_2_wonders_from_their_techs`, `test_every_wonder_comes_only_from_one_tech` (unlocks, not creates) |

## Manual check
- [ ] `data/config.json`: the `build_menu` lists every building, open ones first as today's turn-1 piles; the starting
  deck is the action cards and Warriors (Warriors moves in 296).
- [ ] A tech's card text and details say "X can now be built." for each building it unlocks.

## Log
- 2026-10-05: The user chose to land 295 without a build UI and build 297 straight after: until 297 the real game
  can't build anything (buildings left the deck and supply).
- Built. `engine/build_menu.gd` (`BuildMenu`); `CardPlay` split into `place_error(e, card, target)` (actions, Anarchy,
  cost, play blocks, target) and `put_into_play(e, card, target, verb)` (pay, move, resolve, emit), shared by playing a
  hand card and building; `targets_for(e, card)`. The unlock op opens a build-menu entry when the config has one, else
  a supply pile; its long text is "… can now be built." for a building or unit (by type: card text can't see the
  config). Loader: `build_menu`, and an `unlock` may name an entry. The log says "Built Farm.".
- Real data: the five turn-1 building piles became open entries, the locked building piles locked entries, Monument
  and Forge (one-copy piles) and the eight wonders locked `once` entries; Farm and Hunters' Camp left the deck. Techs
  lost their building `create`s; wonder `create`s became `unlock`s.
- Test changes beyond the red checkpoint: `test_supply::test_unlock_text` (Guildhall is a building: "can now be
  built.", named at the checkpoint); `test_content::test_real_deck_has_wealth_costs_and_the_starting_tableau_makes_wealth`
  now counts open build-menu entries too (the deck holds no wealth cost any more; missed in the red-phase trial, which
  left out test_content); `test_build_menu`'s full-slots fixture starts with 7 pop, not 9 (9 is over the home's
  housing, so the fixture didn't load).
- Follow-ups: 289's Gives captions still say "in the supply" for a build-menu entry; `ScriptedBot` never builds, so
  sim games now place no buildings beyond Sumer's start Farm (298). The balance suite still passes.
