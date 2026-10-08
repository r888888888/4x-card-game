---
id: 390
title: Let the tall bot settle up to 3 territories, at low priority
type: feature
status: done
branch: feat/390-tall-settles-three
---

## Goal
The sim's tall strategy never founds a city past its second territory (the Homeland plus one), which leaves it too
small to say much about a tall empire. Tall should found cities up to 3 settled territories (the capital's Homeland
plus 2 founded cities), but only as a last resort: a settle play comes after every other worthwhile play of the step.

## Acceptance criteria
<!-- Fixtures: test_generic_bot.gd's bot_game / land_game (Lone: 1 action, 10 turns left; Pioneer settles). -->
- [x] AC1 (third territory): Given a tall game with Homeland and Hills settled, Grassland in the frontier and only a
  Pioneer in hand that can settle it, when the bot takes its turn with "tall", then Grassland is settled (3 settled
  territories).
- [x] AC2 (limit): Given a tall game with Homeland, Hills and Grassland settled, Jungle in the frontier and only a
  Pioneer in hand that can settle it, when the bot takes its turn with "tall", then Jungle stays in the frontier. The
  generic strategy, given the same game, settles Jungle.
- [x] AC3 (low priority): Given a Lone game (1 action) with only the Homeland settled, Hills in the frontier and a
  Pioneer and a Shrine in hand, when the bot takes its turn, then generic plays the Pioneer (a City beats +1 score)
  but tall plays the Shrine and Hills stays in the frontier.
- [x] AC4 (idle settle): Given the AC1 game under Stewards (unlimited actions) with a Pioneer and a Shrine in hand,
  when the bot takes its turn with "tall", then it plays the Shrine and then the Pioneer, settling Grassland.

## Out of scope
- Tuning tall's weights or any balance number; the limit and priority only.
- Wide and generic: unchanged.

## Design notes
- `GenericBot.TALL_TERRITORIES` goes from 2 to 3; `_settles_too_far` keeps working on it.
- Low priority: for tall, `best_action` leaves settle plays (a `play_card` of a card with a `settle` effect, as
  `_settles_too_far` reads it) out of the candidates on a first pass; only when nothing else beats doing nothing does
  it try them (a second pass, same seed). Generic and wide keep one pass.
- An owed decision's options (`deciding`, `_settle`) aren't held back: the rule is for plays from hand only.
- Rollouts (cheap mode) follow the same rule, so the rollouts that pick tall's government see tall's settling.
- Replaces 314's `test_tall_never_settles_a_third_territory_and_generic_does` (its rule changes here): AC1/AC2 take its
  place. Update GenericBot's header comment and PLAN.md's strategy line ("never plays a `settle` card past 2
  territories").

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_generic_bot::test_tall_settles_a_third_territory` |
| AC2 | `test_generic_bot::test_tall_never_settles_a_fourth_territory_and_generic_does` (passes at red: today's limit of 2 is stricter) |
| AC3 | `test_generic_bot::test_tall_plays_anything_worthwhile_before_settling` |
| AC4 | `test_generic_bot::test_tall_settles_once_nothing_else_is_worth_doing` |

## Manual check
- [ ] Balance (the user runs it): `scripts/sim.sh --level 2 --compare <main checkout>`; tall's `settlements` should
  rise to at most 2 per game, its score shift noted in the Log.

## Log
- Red: AC3/AC4 use a Shrine (+1 now) rather than a Temple: generic already prefers the Temple to settling, so only
  the Shrine tells the priority rule apart. AC3 starts from the Homeland alone so tall may settle at red.
- Green: `best_action` hands the candidates to `_best_of`; tall's settle plays (`_settles`) go in a second pass on the
  same seed, tried only when the first finds nothing. The QUIET look-on step recurses through `best_action`, so it
  follows the rule too. Balance worry: tall now founds cities late in a turn, after its builds; its food may rarely
  reach a Settler's cost, so `settlements` may barely move (see Manual check).
