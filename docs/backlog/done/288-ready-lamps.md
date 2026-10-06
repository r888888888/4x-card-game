---
id: 288
title: Light a lamp on Knowledge and Buy Cards when something new can be bought
type: feature
status: done
branch: feat/288-ready-lamps
---

## Goal
The player notices, without opening either screen, that they can now learn a tech or buy a supply card they couldn't
before. A lamp inside the Knowledge key and the Buy Cards key lights when something new becomes purchasable and goes
out when the player opens that screen. Design: option A of
[ready-lamp-options.html](../design/ready-lamp-options.html), drawn like the specimen's "Learn Pottery" lamp
(`mcm-specimen.html`, Feedback section).

## Acceptance criteria
"Learnable" means `buy_tech_error(uid) == ""` for a tech in the research deck; "buyable" means `buy_error(card_id) == ""`
for a supply pile. Rules tests use `TEST_CARDS` + `make_engine`.

- [x] AC1: Given a game where no tech is learnable (insight below every offered tech's `tech_cost`), when insight
  rises so that exactly one tech becomes learnable, then `tech_lamp()` turns from false to true and
  `ready_techs()` returns that tech's id only.
- [x] AC2: Given `tech_lamp()` is true, when `see_techs()` is called (the Knowledge screen opens), then `tech_lamp()`
  is false, and it stays false while the same techs remain the only learnable ones: after more insight that
  makes no other tech learnable, after `end_turn()`, and after insight drops below that tech's cost and later rises
  to it again.
- [x] AC3: Given `see_techs()` was called while tech A was learnable, when tech B (not learnable then) becomes
  learnable, then `tech_lamp()` is true. Given `see_techs()` was called while nothing was learnable, any tech becoming
  learnable lights it.
- [x] AC4: Given a tech that is affordable but can't be learned (its prereq isn't researched, a choice is pending,
  Anarchy forbids building, or the game is over), then it isn't in `ready_techs()` and lights nothing; when the block
  lifts and it hasn't been seen, then `tech_lamp()` is true.
- [x] AC5: The supply works the same way with `supply_lamp()`, `ready_supply()` (buyable card ids) and
  `see_supply()`: a pile becoming buyable (wealth reaching its `buy_price`, or a locked pile unlocking while
  affordable) lights it; `see_supply()` puts it out until a pile not buyable at that call becomes buyable; a sold-out
  or locked pile lights nothing.
- [x] AC6: The seen sets live in `GameState`, so an engine copy reports the same `tech_lamp()` / `supply_lamp()` and
  calling `see_*` on the copy leaves the original's lamp as it was. A new game starts with both sets empty (so the
  lamp is lit at once if something is already purchasable).
- [x] AC7 (UI): The Knowledge key shows a lit lamp exactly when `tech_lamp()` is true and the Buy Cards key exactly
  when `supply_lamp()` is true (test hooks on the keys, e.g. `TopBar.knowledge_lamp_lit()`); opening the Knowledge
  screen or the Supply calls `see_techs()` / `see_supply()`, and closing it calls it again, so whatever became
  purchasable while the screen was open counts as seen.

## Out of scope
- Counting how many are purchasable (options C and E).
- Lamps on other keys (Log keeps its "Log •").
- Bot behaviour: `ScriptedBot` never opens screens and ignores the lamps; the sim is unchanged.

## Design notes
- **New engine API** (in `engine_queries.gd` or a small `ReadyLamps` module, delegated from `GameEngine`):
  `ready_techs() -> Array[String]` (tech ids learnable now, research-deck order), `ready_supply() -> Array[String]`
  (card ids buyable now, config order), `tech_lamp() -> bool`, `supply_lamp() -> bool`, `see_techs()`,
  `see_supply()`.
- **Rule** (the design page's rule 1, "something new"): a lamp is lit while the ready list holds an id not in its
  seen set; `see_*` replaces the seen set with the current ready list. Ids, not uids: a tech's id and a pile's
  card id are stable.
- **State**: `GameState.seen_techs: Array[String]`, `GameState.seen_supply: Array[String]`, copied by `copy()`.
  Nothing saves games yet, so there is no save format to change.
- `see_*` are bookkeeping, not player actions: nothing refuses them (no `_blocked_error`, no `*_error` pair), they
  log nothing and change no resource, score or zone. Call that out in their `##` comments so the action rule in
  CLAUDE.md isn't read as missing.
- **Look** (match the specimen's "Learn Pottery" lamp, inside the key, before its label):
  - A 12 px disc, `RADIUS_FULL`, `SPACE_3` before the label (the rays end 17 px from its centre, clear of the text), always present so the key's width never changes. Dark: `Palette.FIELD` with a 1 px
    `CONTROL_BORDER` ring. Lit: `Palette.GAIN` (sage) with a 2 px ring and the one highlight dot (§7.11). Same
    colour for both keys, as in the specimen. `EndTurnKey`'s lamp (`ui/end_turn_key.gd`) is the nearest code;
    factor a shared lamp control if it stays small.
  - Lighting: on instantly (`ease.lamp` on, 40 ms) plus the confirmation starburst (§10.8): six 2×8 px `GAIN` rays
    at 60° steps wiping out from 9 px off the lamp's centre, then fading as they move to 13 px, 400 ms,
    `ease.machined` (the specimen's `@keyframes ray`). Reduce motion: the rays are drawn whole for 1.5 s, then go.
    The burst plays only when a lamp goes dark → lit, not on every refresh while lit, and not on a new game's first
    refresh (like the counters' `_fresh`, 126).
  - Sound: `ui.confirm` (`Sfx.CONFIRM`) at lamp-on, as the specimen and §7.11 do; quiet refreshes stay silent. Going
    out: silent, `ease.lamp` off (120 ms).
  - Tooltips gain a line while lit, e.g. "New: a tech you can learn." (no card names in UI text).
- Hidden keys (`research_on()` false; an empty supply) show no lamp.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_ready_lamps::test_a_tech_becoming_learnable_lights_the_tech_lamp`, `test_ready_techs_are_in_research_deck_order` |
| AC2 | `test_ready_lamps::test_seeing_the_techs_puts_the_lamp_out_while_nothing_new_is_learnable` |
| AC3 | `test_ready_lamps::test_a_tech_not_learnable_when_seen_relights_the_lamp`, `test_after_seeing_nothing_any_learnable_tech_lights_the_lamp` |
| AC4 | `test_ready_lamps::test_a_tech_whose_prereq_is_missing_lights_nothing_until_it_is_met`, `test_a_pending_choice_keeps_the_lamps_dark_until_it_is_made`, `test_a_finished_game_lights_nothing`; `test_anarchy::test_under_anarchy_the_ready_lamps_stay_dark_until_a_government_rules` |
| AC5 | `test_ready_lamps::test_a_pile_becoming_buyable_lights_the_supply_lamp`, `test_seeing_the_supply_puts_the_lamp_out_until_a_new_pile_is_buyable`, `test_a_sold_out_or_locked_pile_lights_nothing` (and the pending, game-over and Anarchy tests above) |
| AC6 | `test_ready_lamps::test_a_copy_reports_the_same_lamps_and_seeing_on_it_leaves_the_original`, `test_a_new_game_starts_with_nothing_seen`, `test_seeing_changes_no_resource_log_or_zone` |
| AC7 | `test_ready_lamp_keys::test_the_keys_lamps_follow_the_engine`, `test_opening_knowledge_sees_the_techs_and_puts_its_lamp_out`, `test_closing_knowledge_sees_what_became_learnable_while_it_was_open`, `test_opening_the_supply_sees_the_piles_and_puts_its_lamp_out`, `test_closing_the_supply_sees_what_became_buyable_while_it_was_open` |

## Manual check
- [ ] Night and Day: the dark lamp reads as an unlit well; the lit lamp matches the specimen's lit "Learn Pottery"
  lamp; the six rays fire once as it lights, with the confirm tone.
- [ ] Reduce motion on: the rays sit still for about 1.5 s, then go.
- [ ] End a turn into enough insight for a new tech: Knowledge lights with a burst; open and close Knowledge: it goes
  out and stays out next turn; Buy Cards behaves the same with wealth.
- [ ] The keys don't shift width when a lamp lights.

## Log
- 2026-10-05: Built. Engine: `ReadyLamps` (`engine/ready_lamps.gd`) behind `GameEngine.ready_techs`, `ready_supply`,
  `tech_lamp`, `supply_lamp`, `see_techs`, `see_supply`; `GameState.seen_techs` / `seen_supply`. "Research-deck order"
  is top card first. UI: `ReadyLamp` (`ui/ready_lamp.gd`) sits on a blank 12 px icon of its key, so the key's width
  never changes; `TopBar` lights both lamps (quietly on a new game's first refresh) and adds the "New: …" tooltip line
  to Knowledge, `SupplyScreen` to Buy Cards. `KnowledgeScreen` and `SupplyScreen` emit `looked` on open and close, and
  `BoardLayout` sees and refreshes the lamps then (main.gd stayed at its 500-line soft limit).
- The lamp's lit ring and highlight are `Palette.GAIN` darkened and lightened, not new palette roles. The rays ease on
  `TRANS_CUBIC`/`EASE_OUT`, approximating `ease.machined`. `EndTurnKey`'s lamp isn't shared: it changes colour by
  role, has no burst, and is drawn as a `StyleBoxFlat` panel. A follow-up could merge the two if a third lamp
  appears.
