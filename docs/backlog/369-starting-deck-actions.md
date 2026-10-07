---
id: 369
title: Five new actions pad out the starting deck
type: feature
status: review
branch: feat/369-starting-deck-actions
---

## Goal
The starting deck is 8 actions (7 once 368 takes Hunt out). With a 5-card hand and Chiefdom's 2 actions, the player
sees nearly the whole deck every turn and a half, so every hand looks alike. Add five cheap, varied actions, one copy
each, so hands differ and choosing what to play matters: **Runner**, **Tribute**, **Assembly of Elders**, **Slash and
Burn** and **Corvée**. Slash and Burn is the first card to use the `trash` op, giving the player a reason to care what
is in the deck. Content only: every op exists.

## Acceptance criteria
- [x] AC1 (invariant): Every op in `EffectRegistry` is used by at least one effect of a real card. The failure names
  the unused op. (Fails today: nothing uses `trash`.)
- [x] AC2 (invariant): The real starting deck (`config.deck`) holds at least one card tagged `unrest.allowed_tag`, so a
  player in Anarchy always owns a card they can play. The failure names the tag. (Fails today: Feast, the only order
  card, is in the supply.)
- [x] AC3 (invariant): Every resource a real card's `cost` names is gained by the play effect of at least one card in
  the real starting deck. The failure names the resource. (Guards the deck once 368 removes Hunt, today's only food
  gain in the deck.)
- [x] AC4 (invariant): Every real action card has a flavor line, as buildings do (352). The failure names the card.
- [x] AC5: The existing invariants hold with the change, in particular the flavor length cap (353),
  `test_every_real_card_can_reach_a_game` and `test_real_deck_has_growth_cards`.

## Out of scope
- **Later-era actions** that need new ops: retrieve a card from the discard (Recall) and look at the top cards of the
  deck to take one (Planning). Each is its own item with an `add-effect` op and a tech unlock.
- Supply piles for the new cards: they are dealt only, one copy each. The supply is unchanged.
- Balance: the deck grows from 8 to 13 (12 after 368). Costs and amounts are first guesses; a later balance item
  tunes them (the user's call).
- 368's Hunt change and the Scout change in `docs/TODO.md`.

## Design notes
- No engine, loader or format change. `trash`'s rules (targets another hand card; "There is no other card in hand to
  trash." when it's alone) are covered by `test_trash.gd` and `test_trash_targeting.gd`.
- Content changes, `data/cards.json` (type `action`, `vp` 0, flavor below, no quote):

  | id | name | cost | tags | effects |
  |---|---|---|---|---|
  | `runner` | Runner | — | — | `draw` 1, `gain_actions` 1, `gain` food 1 |
  | `tribute` | Tribute | — | — | `gain_per_tag` wealth 1, tag `city`, zone `tableau` |
  | `assembly_of_elders` | Assembly of Elders | — | `order` | `lose` unrest 1, `gain` insight 1 |
  | `slash_and_burn` | Slash and Burn | — | — | `trash`, `gain` food 1 |
  | `corvee` | Corvée | — | — | `gain` wealth 3, `gain` unrest 1 |

- `data/config.json`: `deck` gains each of the five at 1.
- Flavor (style guide §18; 106–124 characters; two of five end on a wry turn):
  - Runner: "Runners cross the plain from town to town by nightfall, carrying the message word for word in their heads."
  - Tribute: "Each spring the outlying towns send jars of oil, bolts of cloth and silver rings, and a little less than they
    promised."
  - Assembly of Elders: "In the early cities of Sumer an assembly of elders meets at the gate, hears every grievance and
    decides by slow agreement."
  - Slash and Burn: "Fire runs through the brush and the ash feeds the soil. In three years the field is spent and the
    farmers move on."
  - Corvée: "Every household owes the ruler a season of labour: digging canals, hauling stone, raising walls they will
    never live behind."
- Corvée is the first card name with a non-ASCII letter; its id stays ASCII (`corvee`). Jost and Barlow are Google
  Fonts with Latin-1 coverage, but check it renders (Manual check).
- Bot: `legal_actions` lists each hand card on each `valid_targets`, so GenericBot already tries Slash and Burn on its
  targets (`TARGETS_TRIED`). Whether it values thinning the deck is a balance question; note what the sim does in the Log.
- PLAN.md: the starting-deck line names the five; the effect-op list notes Slash and Burn as `trash`'s first card.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_content::test_every_effect_op_is_used_by_a_real_card` |
| AC2 | `test_content::test_starting_deck_holds_an_anarchy_playable_card` |
| AC3 | `test_content::test_every_cost_resource_is_gained_by_a_starting_deck_play` |
| AC4 | `test_content::test_every_action_has_flavor` (exists since 351) |
| AC5 | `test_content::test_flavor_lines_are_short`, `test_every_real_card_can_reach_a_game`, `test_real_deck_has_growth_cards`, `test_real_data_loads` (existing) |

## Manual check
- [ ] Shipped data: the starting deck is Settler, Scout, Research, Barter 2, Storyteller, Bread and Beer, Runner, Tribute, Assembly of Elders, Slash and Burn and Corvée, one of each new card, none in the supply.
- [ ] Card text: Runner reads draw 1, +1 action, +1 food; Tribute +1 wealth per city; Assembly of Elders −1 unrest,
  +1 insight; Slash and Burn removes a card in hand from the game, +1 food; Corvée +3 wealth, +1 unrest.
- [ ] "Corvée" renders with its é on the card face, the details window and the log: `godot --path . -- --seed 5`.
- [ ] Play Slash and Burn: the game asks for a card in hand; the chosen card leaves the game and food goes up by 1.
  With Slash and Burn alone in hand, it can't be played and says why.
- [ ] Fall into Anarchy (or play into it): Assembly of Elders is playable, the other new cards aren't.

## Log
<!-- Decisions and surprises during implementation, newest last. -->
- Spec: assumed the five are dealt only (no supply piles) and Assembly of Elders carries `order`; Recall and Planning
  move to later-era items (user, 2026-10-06).
- Build: AC4 was already covered by `test_every_action_has_flavor` (351), so only AC1–AC3 got new tests. AC3 counts
  play-trigger gains (`gain`, `gain_per_tag`, `gain_per_keyword`) of starting-deck cards only; it failed on food,
  since 368 had already taken Hunt out. Runner and Slash and Burn now fund it.
- Card text checked headless: Runner "Draw 1 card / +1 action / +1 food", Tribute "+1 wealth per city", Assembly of
  Elders "−1 unrest / +1 insight", Slash and Burn "Remove a card in hand from the game / +1 food", Corvée "+3 wealth /
  +1 unrest".
- Balance worries (not run, per CLAUDE.md): the deck goes 7 → 12 and three of the five cost nothing and give
  resources, so early income rises; Corvée's +1 unrest may push toward Anarchy sooner. Whether GenericBot values
  Slash and Burn's thinning is unmeasured: a balance item should run the sim.
