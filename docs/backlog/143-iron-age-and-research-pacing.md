---
id: 143
title: Iron Age techs in the tech deck, and research pacing
type: feature
status: in-progress
branch: feat/143-iron-age-and-research-pacing
---

## Goal
The tech tree lasts the game. The 6 Iron Age techs already in the data join the tech deck, an era-2 tech opens
the Iron Age (as Bronze Working opens the Bronze Age), and prices are set so that the Stone Age runs out around
turn 18 and the Bronze Age around turn 50 of 100. The sim reports when each era opens and runs out, so pacing can be
checked rather than guessed. Follows 139–142; the targets come from `spike/research-insight`.

## Acceptance criteria
- [ ] AC1: `SimStats.run` reports, for each era with techs in the research deck, `era_<n>_open` (the turn era n was
  added; 1 for era 1) and `era_<n>_done` (the turn its last tech was researched, or the turn limit if it never
  was), as mean / min / max like the other metrics. Given fixture data with a 2-tech era 1 and a bot that learns
  both on turn 1, then `era_1_done` min is 1; given a tech it can never afford, then `era_1_done` is the turn limit.
- [ ] AC2 (content invariant): every tech in `research_deck` with a `prereq` has that prereq in `research_deck`, in
  the same era or an earlier one.
- [ ] AC3 (content invariant): every era above 1 that has techs in `research_deck` is added by an `add_era` effect on
  a tech of an earlier era, or by `era_unlocks`.
- [ ] AC4 (content invariant): every eureka's `card` is a card the player can get (in `deck` or `supply`, or created
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
