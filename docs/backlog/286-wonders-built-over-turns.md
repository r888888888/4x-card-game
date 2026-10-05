---
id: 286
title: Wonders are built over turns, a pop-capped share of wealth each turn
type: feature
status: review
branch: feat/286-wonders-built-over-turns
---

## Goal
Today a wonder costs 10–16 wealth paid at once, and wealth carries over uncapped, so its only real cost is saving up.
After this, playing a wonder places an unfinished site: it takes a slot and a worker and does nothing until it is
paid off. Wealth goes in a little each turn, at most 1 per pop on the site's territory, toward a much higher total
(about 3× today's). A wonder becomes a commitment of several turns that weakens a territory while it is built, and
favours growing that territory tall. (Ideas 1 + 2 of the wonder rethink; a rival race is not part of this.)

## Acceptance criteria
Fixture: `TEST_CARDS` with population on, plus an extra card Colossus: `{"id": "colossus", "name": "Colossus",
"type": "building", "cost": {"wealth": 12}, "vp": 5, "tags": ["wonder"], "project": true, "modifiers": {"hand_size":
1}, "effects": [{"op": "gain", "resource": "insight", "amount": 2, "trigger": "upkeep"}, {"op": "gain", "resource":
"food", "amount": 3}]}`. Homeland's pop is 4 (`set_home_pop`) unless a criterion says otherwise.

- [x] AC1: Playing places a site: given Colossus in hand and 0 wealth, then `play_cost` of it is `{}` and
  `play_error` is "". When it is played on Homeland, then 1 action is used, wealth is still 0, Colossus is on the
  tableau on Homeland, `is_site(uid)` is true, `site_progress(uid)` is 0 and `site_cost(uid)` is 12, and Homeland
  has 1 fewer free slot and 1 fewer free worker. With a civilization discount of 3 wealth on tag `wonder`,
  `site_cost` is 9. A non-project building (Farm) is unchanged: `is_site` false, its cost paid on play.
- [x] AC2: An unfinished site does nothing: given Colossus placed as a site, then food did not rise by 3 when it was
  played, `score()` doesn't include its 5 VP (also when the game ends with it unfinished), the next upkeep gains no
  insight from it, the next turn draws the hand size without its +1, and it still uses its worker (a building
  placed after it on Homeland at pop 2 with one other building is idle).
- [x] AC3: Contributing: given a site on Homeland (pop 4) and 10 wealth, then `contribute_limit(uid)` is 4. When
  `contribute(uid, 3)`, then wealth is 7, `site_progress` is 3, no action is used and `contribute_limit` is 1; after
  `contribute(uid, 1)` it is 0. After `end_turn`, `contribute_limit` is 4 again. The limit is the least of the
  territory's pop less what went in this turn, `site_cost − site_progress`, and wealth held: with 2 wealth it is 2,
  and with progress 10 of 12 it is 2. Contributing works on the turn the site was played. A `fork()` mid-build and
  `GameState.copy()` keep progress and this turn's contributions.
- [x] AC4: Contributing is refused, with `contribute_error` non-empty and nothing changed, when: the amount is below 1;
  the amount is more than the wealth held ("needs 5 wealth (you have 2)"); the amount is more than
  `contribute_limit` (pop 4, 4 already in this turn); the uid is not an unfinished site (a Farm on the tableau, a
  completed Colossus, a Colossus in hand); the site is idle (Homeland's pop dropped below its buildings and the site
  is past its pop: `contribute_limit` 0); a decision is owed (the `_blocked_error` message); or the game is over.
- [x] AC5: Completion: given a site at progress 8 of 12 and 10 wealth, when `contribute(uid, 4)`, then `is_site` is
  false, food rises by 3 (its play effects resolve now), `score()` rises by 5, `contribute_limit` is 0, the next
  upkeep gains 2 insight from it and the next turn draws 1 more card. Completing logs "Completed Colossus." and
  emits `changed`.
- [x] AC6: Data: the loader accepts `project: true` on a building and rejects it on any other type, a non-bool value,
  and a project whose cost is not wealth alone, at least 1 (`{"food": 1, "wealth": 10}`, `{}`), each error naming
  file, card and field. A project's generated text adds "Built over turns: up to 1 wealth per pop here each turn."
  Real data (`test_content`): every card tagged `wonder` is a project, and every project is tagged `wonder`.
- [x] AC7: Bot: given a fixture game of a few turns where ScriptedBot has a Colossus site on Homeland (pop 4), after
  its plays and buys at the end of `take_turn` it contributes `min(contribute_limit, wealth − SITE_RESERVE)` to each
  site in tableau order (`SITE_RESERVE` = 3): with 10 wealth it puts in 4 and keeps 6; with 5 wealth it puts in 2;
  with 3 or less it puts in nothing. It plays a wonder card like any building, and never abandons a site.
- [x] AC8: Abandoning: given a Colossus site on Homeland at progress 7 and 2 wealth, when `abandon(uid)`, then no
  action is used, wealth is still 2, Colossus is in the discard pile (not the tableau), Homeland has its slot and
  worker back, and a building that was idle because of the site now works. Played again later, it is a new site at
  progress 0 with a full `contribute_limit`. `abandon_error` is non-empty and nothing changes for a card that isn't
  an unfinished site (a Farm on the tableau, a completed Colossus, a Colossus in hand), while a decision is owed (the
  `_blocked_error` message) and once the game is over. Abandoning logs "Abandoned Colossus.".

## Out of scope
- A rival race that can take a wonder away (idea 5 of the rethink); a separate item if wanted.
- A cap set by the settlement tier (281); this item caps by pop.
- Moving a site, a refund on abandoning, a down payment on play, contributing resources other than wealth, contributing with an
  action.
- An amount picker in the UI: the button contributes `contribute_limit`.
- Balance beyond the 3× costs below (Egypt's −3 on wonders now matters much less; see Log).

## Design notes
- Data: new building-only field `project` (bool) in `DataLoader.TYPE_FIELDS`; `CardDef.project`. The engine keys on
  the field, not the `wonder` tag (no tag strings in `engine/`). A project's `cost` is the total wealth to complete.
- State: `CardInstance.progress` (wealth paid in) and `CardInstance.given_this_turn` (reset at turn start), both
  copied in `copy()`. A site is a project on the tableau with `progress < site_cost`.
- Playing a project: `play_cost` is `{}`; `CardPlay.play` places it on the target like a building and skips
  `_resolve(card, "play")`; completion resolves "play" then.
- A site is left out of `Modifiers.working_cards` (no upkeep, no modifiers) and its VP out of `score()`, but still
  counts as a worker on its territory (so it can make later buildings idle, and be idle itself). Military defence
  skips sites too (no wonder has defence until done; Walls of Uruk does when finished).
- New API: `is_site(uid)`, `site_progress(uid)`, `site_cost(uid)` (the discounted cost's wealth),
  `contribute_limit(uid)`, `contribute_error(uid, amount)`, `contribute(uid, amount)`, `abandon_error(uid)`,
  `abandon(uid)`. Both error queries start with `_blocked_error`. Abandoning clears `progress` and `given_this_turn`
  and moves the card to the discard, like disbanding a unit (no action). Contributing is not a decision kind: an unfinished site never blocks anything.
- Card details of a site add its state ("Being built: 4 / 12 wealth"); the UI shows it and the button, holding no
  rules.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_wonder_sites::test_a_project_costs_nothing_to_play_and_is_placed_as_a_site`, `test_a_site_cost_is_the_discounted_wealth_cost`, `test_a_building_that_isnt_a_project_is_paid_on_play` |
| AC2 | `test_wonder_sites::test_an_unfinished_site_resolves_no_play_effect_and_scores_nothing`, `test_an_unfinished_site_scores_nothing_at_the_end`, `test_an_unfinished_site_has_no_upkeep_and_no_modifiers`, `test_an_unfinished_site_still_uses_a_worker` |
| AC3 | `test_wonder_sites::test_contributing_puts_in_wealth_up_to_the_pop_each_turn`, `test_the_contribute_limit_is_the_least_of_pop_cost_left_and_wealth`, `test_a_fork_and_a_copy_keep_progress_and_this_turns_contributions` |
| AC4 | `test_wonder_sites::test_contributing_below_1_or_past_wealth_or_the_limit_is_refused`, `test_contributing_to_a_card_that_isnt_an_unfinished_site_is_refused`, `test_contributing_to_an_idle_site_is_refused`, `test_contributing_is_refused_while_a_decision_is_owed_or_the_game_is_over` |
| AC5 | `test_wonder_sites::test_paying_the_last_wealth_completes_the_site` |
| AC6 | `test_wonder_sites::test_project_loads_on_a_building_with_its_text`, `test_project_validation`; `test_content::test_every_wonder_is_a_project_and_every_project_a_wonder` |
| AC7 | `test_wonder_sites::test_the_bot_contributes_down_to_its_reserve_at_the_end_of_its_turn`, `test_the_bot_plays_a_wonder_and_never_abandons_its_site` |
| AC8 | `test_wonder_sites::test_abandoning_a_site_discards_it_and_frees_its_slot_and_worker`, `test_a_site_played_again_after_abandoning_starts_over`, `test_abandoning_is_refused_for_a_card_that_isnt_an_unfinished_site`, `test_abandoning_is_refused_while_a_decision_is_owed_or_the_game_is_over` |

## Manual check
- [ ] Real wonder costs (about 3× before): Oracle of Delphi 30, Walls of Uruk 30, Pyramids 40, Great Ziggurat 42,
  Hanging Gardens 48, Great Library 48, Great Harbor of Tyre 45, Royal Road 45; each has `project: true`.
- [ ] A wonder in hand shows no wealth cost to play, and its details show the total and the build rule.
- [ ] A site on a territory reads clearly as unfinished (progress "4 / 12" or a meter) and shows no VP or effect yet.
- [ ] The site's details have a Contribute button that puts in `contribute_limit`, disabled with the
  `contribute_error` reason as its tooltip when nothing can go in; the wealth figure in the top bar rolls down.
- [ ] The site's details have an Abandon button that asks for confirmation (naming the wealth that will be lost)
  before abandoning.
- [ ] Finishing a wonder is noticeable (the site becomes the wonder, its VP counts).

## Log
- Spec choices (user): cap = the territory's pop each turn; playing costs just the action; costs about 3×; the bot
  contributes at turn end down to a reserve. Added after: abandoning, free, card to the discard, progress lost.
- Balance worries for a later balance item: Egypt's −3 wealth on wonders is now ~7% instead of ~25%; Royal Road and
  the Oracle may come much later in the game; whether sites crowd out supply buys for the bot.
- Red: `project` on a non-building gets the usual TYPE_FIELDS warning ("only applies to buildings (ignored)"), as AC6's
  "rejects" reads with the house rule for type-only fields; a non-bool value and a non-wealth cost are errors.
- Built. Rules in a new `engine/sites.gd` (`Sites`); `CardPlay.cost_to_play` returns {} for a project, and a project
  skips its play effects until completed. Unfinished sites are left out of `Modifiers.working_cards`, `score()`, defence
  and training, but still count as a worker and a slot. The blocking test's action table gained `contribute` and
  `abandon`.
- Green: `test_the_bot_plays_a_wonder_and_never_abandons_its_site` had a fixture flaw: with Court's 3 actions the bot
  spent them on the hand's 5 Shrines before reaching the Colossus. Its deck went from 20 Shrines to 2; the assertions
  are unchanged.
- Added at green (design notes and Manual check): `card_details` state "Being built: N / M wealth"
  (`test_a_sites_details_show_its_progress`); the details modal's Contribute (puts in `contribute_limit`, disabled with
  `contribute_error` as its tooltip) and Abandon… with an `AbandonModal` confirmation naming the wealth lost
  (`test_details_contribute_to_and_abandon_a_site`); a site's board card shows "N / M wealth"; a wonder in hand shows no
  cost. The modal hangs off the details modal (`CardDetailsModal.abandon_modal`), since `main.gd` is at its 500-line cap.
- Real data: costs as in the Manual check, each with `project: true`. The balance suite passes.
- Suite 1896 → 1922 tests.
