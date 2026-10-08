---
id: 403
title: Claimant eras and the incumbent - successors per era, loyal wins keep rank
type: feature
status: ready
branch: feat/403-claimant-eras
---

## Goal
Claimants should scale with the game, and rivalry should feel like the incumbent against challengers. Three rules:
- **Era successors**: each faction offers its claimant of the current era (the highest era reached that it has a
  claimant for), so later Anarchies deal stronger claimants and nothing weak lingers.
- **The incumbent always contests**: the faction holding the court is always one of the claimants dealt, so your
  strategy can't fail to turn up.
- **Loyal wins keep rank**: if the incumbent's faction wins again, its new claimant takes the court at the old rank.
  A challenger starts at rank 1.

So each Anarchy weighs rank against era: stay loyal and move up to the new era's claimant keeping rank, or start over
with a challenger.

Builds on 401 and 402.

## Acceptance criteria
Fixtures: 401's and 402's, plus Alpha II (faction `a`, era 2) and Beta II (faction `b`, era 2) in the court pool.

- [ ] AC1 (successors): In era 1 a fall deals only era-1 claimants (Alpha, never Alpha II). After era 2 is added, a fall
  deals Alpha II for faction `a` and Beta II for `b`, never Alpha or Beta; factions `c` and `d`, with no era-2
  claimant, still deal Gamma and Delta. At most one claimant per faction is dealt.
- [ ] AC2 (the incumbent contests): Given Alpha in the court, when Anarchy falls in era 1 the court empties and Alpha
  is dealt with 2 claimants of other factions; over seeds 1 to 10 Alpha is dealt every time. While Anarchy rules the
  court is empty, so Alpha's passive (402) doesn't apply. Before any court exists, all 3 are drawn at random.
- [ ] AC3 (a loyal win keeps rank, and moves up an era): Given Alpha in the court since turn 5 at rank 2 on turn 20, era
  2 added, and Anarchy falling: Alpha II is dealt for faction `a` (Alpha returns to the pool and isn't dealt again in
  era 2). Backing Alpha II most puts it in the court with `court_rank()` 2 on the next turn (its time counted from
  turn 5).
- [ ] AC4 (the incumbent re-won in the same era): Given Alpha in the court and an era-1 Anarchy where Alpha wins again,
  Alpha returns to the court and its rank keeps counting from when it first took it (turn 5).
- [ ] AC5 (a challenger starts over): Given Alpha in the court at rank 2 and Beta winning the next Anarchy,
  `court_rank()` is 1 on the next turn.
- [ ] AC6 (loader): Two claimants with the same faction and era are an error naming both.

## Out of scope
- The real claimants and their numbers: 404.

## Design notes
- Dealing (401's `Anarchy` deal step): for each faction in the pool, its candidate is its claimant with the highest
  `era` ≤ `era()` (none if all its claimants are later). At the fall the court card leaves the court (the court is
  contested, so its passive pauses for the 3 turns) and the incumbent's faction is remembered (`GameState.incumbent`,
  copied). That faction's candidate is dealt first: the old court card itself if it is still its faction's candidate,
  else its successor (the old card returns to the pool). Then `dealt` − 1 others from the remaining factions by the
  seeded rng.
- A winner of the incumbent's faction keeps `GameState.court_since`; any other winner sets it to the next turn.
  `incumbent` clears when the court is decided.

## Test plan
| AC | Test |
|---|---|
| AC1 | |

## Manual check
- [ ] The dealt row marks the incumbent's claimant (e.g. "Incumbent") and shows that its rank would carry over.

## Log
