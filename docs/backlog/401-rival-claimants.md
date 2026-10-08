---
id: 401
title: Rival claimants - back one each Anarchy turn, the best-backed takes the court
type: feature
status: ready
branch: feat/401-rival-claimants
---

## Goal
After [384](384-simpler-anarchy.md) the 3 Anarchy turns are quiet: play some action cards, maybe trash one. Make them a
contest for power. When Anarchy falls, 3 **claimants** (a new card type) are dealt face-up. Each Anarchy turn you back
one: its **boon** (its play effects) resolves at once and it gains 1 **support**. When Anarchy ends, the claimant with
the most support **takes the court**, a one-card slot that a later Anarchy can overturn. Backing the same one is a sure
win; spreading gets you different boons. This item is the engine for dealing, backing and the winner; what a court
card does while it holds the court comes in [402](402-court-rank.md), era successors and the incumbent in
[403](403-claimant-eras.md), the real claimants in [404](404-claimant-content.md).

Builds on 384.

## Acceptance criteria
Fixtures (new, in `tests/lib/anarchy_case.gd`): claimants Alpha (faction `a`, play: +2 wealth), Beta (faction `b`,
play: +1 insight), Gamma (faction `c`, play: grow 1 at the best territory) and Delta (faction `d`, play: +1 VP); the
unrest block with `court: {"claimants": ["alpha", "beta", "gamma", "delta"], "dealt": 3}`; Anarchy falling at turn 2's
start and lasting 3 turns.

- [ ] AC1 (loader): A `claimant` card needs a `faction` (a non-empty string; else an error naming the card and field)
  and takes an `era` (default 1). `unrest.court.claimants` lists claimant ids (an unknown id or a card of another type
  is an error naming it, as is the same id twice); `dealt` is an integer ≥ 1 (default 3). A claimant can't be listed in
  `deck`, `supply` or `event_deck` (an error naming it).
- [ ] AC2 (dealt at the fall): When Anarchy falls (at the limit, or by revolution), the `claimants` zone holds 3 of the
  4, of 3 different factions, each with 0 support (`counters`); the same seed deals the same 3. With only 2 claimants
  configured, 2 are dealt.
- [ ] AC3 (backing is owed each Anarchy turn): On each of Anarchy's 3 turns, after the draw, the decision
  `PENDING_BACK` is owed with the dealt claimants as options. `back(alpha uid)` returns true, gives +2 wealth, puts
  Alpha's support at 1, uses no action and clears the decision; a second `back` that turn is refused. `back_error` is
  non-empty and `back` changes nothing for a uid that isn't dealt, when no backing is owed, and when the game is over.
  A choice event drawn that turn waits until the backing is done (as it waited for renewal).
- [ ] AC4 (a boon ignores Anarchy's limits): Given Gamma dealt, backing it adds 1 pop during Anarchy, although nothing
  can be grown by the player then.
- [ ] AC5 (the best-backed takes the court): When Anarchy ends at its 3rd turn's end, before the government choice: with
  Alpha, Beta, Alpha backed, Alpha moves to the `court` zone; with Alpha, Beta, Gamma backed (a three-way tie) Gamma,
  the one backed last, does. The `claimants` zone is then empty and the others can be dealt again. A later Anarchy's
  winner replaces the court card, which can be dealt again.
- [ ] AC6 (off without config, and the bot): With no `court` in the unrest block nothing is dealt and no backing is owed
  (Anarchy as in 384). While backing is owed, `legal_actions()` has one `["back", uid]` per dealt claimant; a fixture
  game played by `GenericBot` through a whole Anarchy backs once per turn and ends with a claimant in the court.
  `copy()` keeps the dealt claimants, their support and the court (the suite's copy check).

## Out of scope
- What a court card does (its passive, its rank): 402. Era successors, the incumbent's guaranteed place and keeping rank:
  403. The real claimants and their numbers: 404.
- A revolution's head start (backing one before the fall); a later item if wanted.

## Design notes
- New card type `CardDef.CLAIMANT := "claimant"`; new field `faction` (`DataLoader.TYPE_FIELDS`, follow the
  `add-card-field` skill) and `era` extended to claimants. A claimant's play effects are its boon; its upkeep effects and
  modifiers are its court passive (402), so they must not count anywhere until then.
- Config `unrest.court`: `{"claimants": [ids], "dealt": 3}` (402 adds `rank_turns`, `max_rank`).
- New zones `claimants` (dealt, face-up) and `court` (one card). The pool isn't a zone: it is the configured claimants
  not dealt and not in the court, so nothing goes stale between Anarchies. Dealing uses the engine's seeded rng, one per
  faction (403 refines which of a faction's claimants).
- New decision kind `PENDING_BACK` (follow the `add-decision` skill): owed after the draw on each Anarchy turn; action
  `back(uid)` / `back_error(uid)`; the choice overlay shows the dealt claimants with their support; focus keys; the sim
  bot's pick (its rollouts value boons by their effects).
- Support is the claimant's `counters`. Ties go to the tied claimant backed last: keep the order backed (state on the
  cards or a list in `GameState`, copied).
- `Anarchy._end` decides the court before the government choice is owed.
- `revolt_summary()` gains "Each turn, back a claimant; the best-backed takes your court." when a court is configured.
- UI: the dealt claimants show beside Anarchy's card with their support; the court card has a slot near the government.

## Test plan
| AC | Test |
|---|---|
| AC1 | |

## Manual check
- [ ] During Anarchy the 3 claimants show with their support; the backing overlay opens each turn after the draw.
- [ ] After Anarchy the winner sits in the court slot.

## Log
- 2026-10-07: designed with the user: claimants enable strategies (wide, tall, research, coastal, military) through 5
  factions; court rank every 10 turns; era-gated successors. A spike (`spike/rival-claimants`) may come first to try
  the feel; its findings go here.
