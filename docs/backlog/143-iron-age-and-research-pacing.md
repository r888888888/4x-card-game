---
id: 143
title: Iron Age techs in the tech deck, and research pacing
type: feature
status: review
branch: feat/143-iron-age-and-research-pacing
---

## Goal
The tech tree lasts the game. The 6 Iron Age techs already in the data join the tech deck, an era-2 tech opens
the Iron Age (as Bronze Working opens the Bronze Age), and prices are set so that the Stone Age runs out around
turn 18 and the Bronze Age around turn 50 of 100. The sim reports when each era opens and runs out, so pacing can be
checked rather than guessed. Follows 139–142; the targets come from `spike/research-insight`.

## Acceptance criteria
- [x] AC1: `SimStats.run` reports, for each era with techs in the research deck, `era_<n>_open` (the turn era n was
  added; 1 for era 1) and `era_<n>_done` (the turn its last tech was researched, or the turn limit if it never
  was), as mean / min / max like the other metrics. Given fixture data with a 2-tech era 1 and a bot that learns
  both on turn 1, then `era_1_done` min is 1; given a tech it can never afford, then `era_1_done` is the turn limit.
- [x] AC2 (content invariant): every tech in `research_deck` with a `prereq` has that prereq in `research_deck`, in
  the same era or an earlier one.
- [x] AC3 (content invariant): every era above 1 that has techs in `research_deck` is added by an `add_era` effect on
  a tech of an earlier era, or by `era_unlocks`.
- [x] AC4 (content invariant): every eureka's `card` is a card the player can get (in `deck` or `supply`, or created
  by some card's effect), and every eureka's `tag` is on at least one such card.

## Out of scope
- New Iron Age techs or cards beyond the 6 defined (Philosophy, Iron Working, Mathematics, Monarchy, Astronomy,
  Engineering). Most read more Classical than Iron Age; proper Iron Age content is a later content item.
- Making Insight scale with the empire (see Design notes): a separate item if wanted.
- A general balance pass (scores, strategies, civilizations).

## Design notes
- Data: `research_deck` adds the 6 era-3 techs. An era-2 tech gets `{"op": "add_era", "era": 3}`; Writing is the
  suggested opener (needed for Philosophy, and opens no other era). No era-3 entry in `era_unlocks`: in the spike, a pop/wealth
  threshold opened the Iron Age at turns 19–24 whatever it was set to, while era-3 prereqs set the real pace.
- Eurekas for the era-3 techs (spike): Philosophy 2 Temples, Iron Working 1 Forge, Mathematics 2 Markets, Monarchy 5
  city cards, Astronomy 2 Harbors, Engineering 3 Quarries. Consider sizing eurekas by era (the spike's flat −2 is
  small next to era-3 prices).
- Spike results (`sim/tempo.gd`, 20 seeds, mean turn each era ran out; era 3 opened by a 24 pop / 60 wealth
  threshold there): era 1 at 16–20, era 2 at 41–67, era 3 at 70 (growth) to never (tall) with era-1 prices 6–10,
  era-2 15–22, era-3 27–32, Research +3, Capital +1, Library +2. The baseline bot (no plan) ran 10+ turns behind.
- The spread is the main worry: Insight comes only from the Capital, Research cards and one Library, so a big empire
  has no more scholars than a small one; growth and wide gain through eurekas that count cities and buildings. Note it
  in the Log; a later item can add an Insight source tied to development (e.g. culture buildings).
- `sim/tempo.gd` from the spike is replaced by the AC1 metrics.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_sim::test_sim_stats_report_when_each_era_opens_and_runs_out`, `test_an_era_never_finished_reports_the_turn_limit`, `test_sim_stats_have_no_era_metrics_without_techs` (guard) |
| AC2 | `test_content::test_every_tech_prereq_is_in_the_research_deck` (existing), `test_every_tech_prereq_is_in_the_same_era_or_an_earlier_one` |
| AC3 | `test_content::test_every_researchable_era_has_2_techs_and_is_added` (existing) |
| AC4 | `test_content::test_every_eureka_counts_cards_the_player_can_get` |

## Manual check
- [ ] `scripts/sim.sh 20`: averaged over growth, wealth, wide and tall, `era_1_done` is about 18 and `era_2_done`
  about 50; era 3 is mostly finished by turn 100 for growth and wide. Record the numbers in the Log.
- [ ] Shipped numbers: the era-3 opener, era-3 prices, the eurekas above.
- [ ] Play to turn ~40 (`godot --path . -- --seed 5 --turns 40`): the Iron Age column fills once its opener is learned;
  its techs are locked until their prereqs are researched.

## Log
- 2026-10-01: Built. `SimStats` reports `era_<n>_open` / `era_<n>_done` per era with techs (an era never opened or
  finished reports the last turn played); `sim/tempo.gd` was not brought over. Data: the 6 era-3 techs join
  `research_deck`; Writing adds era 3; every tech has the spike's eureka, sized by era as agreed at the red checkpoint
  (−2 / −4 / −6); Engineering also unlocks the Monument pile (agreed: the gives-a-locked-pile invariant).
  `test_tech_tree_modal`'s real-data column test now derives the columns from `tech_eras()` (agreed).
- Pacing, `scripts/sim.sh 20`, mean turn each era ran out (growth / wealth / wide / tall; baseline):
  - era-1 6–10, era-2 15–22 (the spike's): era 1 22.4 / 21.8 / 22.6 / 19.9 (avg 21.7), era 2 49.6 / 69.4 / 49.3 / 59.9
    (avg 57.0); baseline 29.1 / 64.1.
  - Shipped, era-1 5–8, era-2 13–19, era-3 27–32 unchanged: era 1 18.4 / 17.3 / 18.3 / 16.4 (avg 17.6), era 2 42.7 /
    60.4 / 41.6 / 50.1 (avg 48.7), era 3 79.0 / 97.5 / 76.5 / 99.4; baseline 21.3 / 50.8 / 89.3. Era 2 opens around
    turn 7 (the 8 pop / 15 wealth threshold), era 3 around 26–29.
- Spread (Design notes): wealth and tall finish era 2 10–20 turns after growth and wide and rarely finish era 3: Insight
  doesn't grow with the empire. A later item could add an Insight source tied to development (culture buildings).

