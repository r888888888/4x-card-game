# 4X Card Game — Prototype Plan

## Decisions
| Topic | Decision |
|---|---|
| Engine | Godot 4.x |
| Language | GDScript |
| Map | None: tableau of cards (cities, buildings, wonders) |
| Solo opposition | Event/barbarian deck that escalates by era |
| Card data | JSON files, loaded at runtime |
| Deck model | Demo uses a fixed deck; engine still supports deck-building and era decks |
| Balance simulation | Headless scripted bot over many seeds (`scripts/sim.sh`, 042); compared against `main`, not pinned in tests |
| Win condition (demo) | Game ends after 100 turns (20 until 066); final score = sum of VP on tableau cards |
| Resources (demo) | Food and wealth; unspent resources carry over with no cap. Food pays for people (growth, upkeep, Settlers), wealth for buildings: non-food buildings cost wealth only, food producers 1 food + wealth; start with 2 food + 2 wealth (Capital, Caravan, Market make wealth; Market +1 per city, 077) (021, 022, 076, 077) |
| Threat effects | Event deck framework built (039): one event drawn per turn, active until it lasts out; harmful ops and real events come later |

## Architecture principle
The rules engine is plain GDScript (`RefCounted`/`Resource` classes, no scene nodes).
Scenes only display state and send player actions. The engine talks to the UI
through signals. This keeps rules testable and allows headless simulation
(`sim/`, run with `scripts/sim.sh`).

## Project layout (as built)
```
res://
  data/
    cards.json           # player card definitions
    config.json          # resources, keywords, turn limit, hand size, deck model, starting state, deck lists
  engine/                # plain GDScript, no scene nodes
    game_engine.gd       # public API: actions and their *_error queries, queries, score, fork(); calls the modules below
    game_state.gd        # GameState: everything that changes during a game; copy() is a deep copy (051)
    turn_loop.gd         # TurnLoop: new game setup, start of turn (upkeep, feeding, era unlocks, draw), end turn, discard
    card_play.gd         # CardPlay: play_error, valid targets, playing a hand card
    population.gd        # Population: pop, housing, growth, workers, idle buildings, feeding
    research.gd          # Research: revealing, buying and declining techs, passes, eras
    supply.gd            # Supply: buying from the card supply
    territories.gd       # Territories: explore and choose, settle, slots, keyword requirements, tableau groups
    famine.gd            # Famine: brought by a hungry upkeep, counters, guard saves, no growth, ends when fed
    events.gd            # Events: event deck setup, drawing in the event phase, active events' upkeep and discard
    card_details.gd      # CardDetails: a card's rules, live state and explained terms for the details modal (056)
    glossary.gd          # Glossary: fixed mechanic terms (Upkeep, Slots, Workers, …); keyword terms are generated
    data_loader.gd       # JSON → CardDef; load_all reads both files; collects all errors/warnings
    config_loader.gd     # config.json → normalized config, checked against the cards (095)
    card_def.gd          # immutable definition; short card text and full tooltip text generated from effects
    card_instance.gd     # runtime copy of a card (uid + def + territory_uid, pop, passes, keywords, turns_left)
    zone.gd              # named ordered pile (deck, hand, discard, tableau, frontier, research_deck, …)
    effect.gd            # Effect base class
    fields.gd            # Fields: read_int / read_string / as_int for card, config and effect fields
    effect_registry.gd   # op name → effect script
    effects/             # one <op>_effect.gd per effect op
    rng.gd               # seeded RNG (reproducible games)
  autoload/game.gd       # "Game" singleton: loads data, owns the engine
  autoload/settings.gd   # "Settings" singleton: player settings (reduce motion), saved via SettingsStore
  autoload/settings_store.gd # ConfigFile at user://settings.cfg; bad values fall back with a warning
  ui/                    # main.tscn/main.gd (MainScreen: card views, refresh, layout built in code), card_view.gd,
                         # anim.gd (animation tuning), icons.gd (text glyphs → icon images in cards and the log),
                         # ui_kit.gd (shared styles, labels, overlays, tokens); components: top_bar.gd, side_panel.gd,
                         # tableau_view.gd, choice_overlays.gd, supply_screen.gd, game_menu.gd, game_over_overlay.gd,
                         # start_screen.gd (063: title, New game with a seed, Reduce motion; shown on launch),
                         # drag_controller.gd (drag and targeting), card_focus.gd (keyboard focus and keys),
                         # card_details_modal.gd (click, right-click in choices and supply, or I: full card details),
                         # tech_tree_modal.gd (Knowledge button or T: the tech tree),
                         # event_modal.gd (each drawn event and what it did, 079)
  assets/icons/          # hand-drawn white 24×24 SVGs, imported as DPITexture and tinted in code
  tests/                 # run_tests.gd runner, lib/test_case.gd helpers, test_<area>.gd (see docs/testing.md)
  sim/                   # bot.gd (ScriptedBot), sim_stats.gd (SimStats: per-seed metrics), run.gd (CLI)
  scripts/test.sh        # test entry point; scripts/test-hook.sh is the Claude Code Stop hook
  scripts/sim.sh         # balance simulator: scripts/sim.sh [seeds]
  docs/                  # development process, testing guide, backlog
```
Adding an effect: follow the `add-effect` skill. The engine API is documented by the `##` comments in
`engine/game_engine.gd`; the sections below give the rules and name the functions only where it helps.
Buildings always target a settled territory with a free slot (`free_slots`).
An effect that targets a card overrides `target_zone()` (and its two error messages); the engine then
derives `needs_target`, `valid_targets` and the target checks in `play_error` from it.

## Card data format
JSON only. Effects are structured objects, so no mini-language parser is needed.
`data/cards.json`:
```json
{
  "cards": [
    {
      "id": "farm", "name": "Farm", "type": "building",
      "cost": { "food": 2 }, "vp": 1, "tags": ["food"],
      "effects": [ { "op": "gain", "resource": "food", "amount": 1, "trigger": "upkeep" } ],
      "text": "Upkeep: +1 food."
    },
    {
      "id": "scout", "name": "Scout", "type": "action",
      "cost": { "food": 0 }, "vp": 0, "tags": ["explore"],
      "effects": [ { "op": "draw", "amount": 2 } ],
      "text": "Draw 2 cards."
    },
    {
      "id": "city", "name": "City", "type": "city",
      "cost": { "food": 0 }, "vp": 3, "tags": ["expand"],
      "effects": [ { "op": "gain", "resource": "food", "amount": 2, "trigger": "upkeep" } ],
      "text": "Upkeep: +2 food."
    }
  ]
}
```
- `trigger` is `play` (default), `upkeep`, or `start` (062: civilizations only, once at `new_game`; no op that needs a
  target or opens a choice). Only `gain`, `gain_per_tag`, `gain_per_keyword`, `lose`, `lose_pop`, `score` and `grow` may use
  `upkeep` (043): the forecast restores only resources, bonus score and pop, so other ops are a loader error there.
- `trade` (055, play only): `{ "op": "trade", "resource": "wealth", "per_root_city": 2, "pop_per": 5, "min_cities": 2 }`
  gains `per_root_city` × ⌊√cities⌋ + ⌊total pop / `pop_per`⌋; with fewer than `min_cities` city cards in the
  tableau the card can't be played (Caravan).
- `gain_per_keyword` (081): `{ "op": "gain_per_keyword", "resource": "food", "amount": 1, "keywords": ["forest", "grassland"] }`
  gains `amount` (default 1) per settled territory (in the tableau) with any of `keywords`, printed or rolled; each
  territory counts once. `GameEngine.count_territories_with(keywords)` is the count (Hunt).
- Harmful ops (072), on any card type: `{ "op": "lose", "resource": "food", "amount": 2 }` takes a resource, never
  below 0 ("−2 food"); `{ "op": "lose_pop", "amount": 1 }` takes pop one at a time from the territory with the most
  pop, ties first in tableau order, the same rule as starvation (`Population.most_pop`).
- `trash` (082, play only): `{ "op": "trash" }` targets another card in hand and moves it to the `trashed` zone, out of
  the game (never reshuffled). The card being played is never its own target; the outcome's `trashed` is the uid
  (Winnow, supply only).
- `create` puts a new card in `tableau` (default), `hand`, `discard` or `deck` (`GameEngine.CREATE_ZONES`, 048);
  any other zone is a loader error.
- `cost` is an object keyed by resource, so adding resources later doesn't change the format.
- Conditional or compound effects nest naturally, e.g. `{ "op": "if", "cond": {...}, "then": [...] }`.
- The loader validates every card (required fields, known `op`s, known resources) and reports
  errors with file, card id and field. Unknown fields are warnings, not errors.
- Deck contents and starting state live in `config.json` (e.g. `"deck": { "farm": 4, "scout": 3, ... }`).
- Territory cards (`"type": "territory"`) need `slots` (int ≥ 0), may set `housing` (int ≥ 1, default
  `slots + 2`) and may list `keywords` from config `keywords`. They go in `territory_deck` (never `deck`); `starting.territory` names the Capital's.
- Buildings may set `housing` (int ≥ 1: added to their territory's housing, idle or not) and `famine_guard` (int ≥ 1:
  pop on their territory saved from starving each upkeep, while working) (060).
- Resource keywords (config `resource_keywords`, e.g. gold) are never printed on a territory: each copy rolls
  them from its weighted table in config `territory_resources` (`{"hills": [{"keywords": ["gold"], "weight": 1},
  {"keywords": [], "weight": 1}]}`) when the game starts, with the seeded rng. Terrain with no table rolls nothing.
  Iron counts as everywhere, so it isn't a keyword (036). Shipped: gold, tin and copper on Hills and
  Highlands; Forge scores +1 VP each upkeep on copper and on tin (037).
- Territory slots and housing follow the land (038): fertile river land has high housing, flat land more
  slots, and rough terrain (hills, mountain, jungle, desert) low on both, to be made up by keywords.
- Buildings may list `requires` (keyword ids, any-of). Any effect may have a `keyword`; it then applies
  only when its card's territory has that keyword (text: "… (on Flood Plain)").

## Keeping the deck model open
Every deck model is expressed through **zones + a `move_card` effect**:
- Deck-building: `market` zone, `buy_card` action moves market → discard.
- Fixed deck: no market; progression comes from the tableau only.
- Era decks: `era_1..era_n` zones; advancing an era swaps the draw source.
`config.json` selects the model, so all three can be playtested without code changes.

## Turn loop (initial)
1. Upkeep: cities and buildings trigger `@upkeep` (produce food), then researched techs, the civilization and the government, then active events
   (which may end), then pop eats food (a shortfall brings or worsens a Famine; a fed upkeep ends it, 083).
2. Draw up to hand size (unplayed cards stay in hand).
3. Play: play or buy cards while resources allow, buy growth for territories, and play Insight cards (id `research`) to reveal techs. A hand card can be discarded for free at any time.
4. Event: draw one event from the event deck and resolve its `play` effects (see Events).
5. Cleanup: keep the hand, but over `hand_limit` (7) you must discard down to it before the turn ends; unspent food carries over. The final turn discards the hand. After turn 20, show final score.

Forecast (035, `upkeep_forecast` in `engine/game_engine.gd`): returns what the next upkeep does to each resource on hand, food net of what
pop eats (may be negative), plus `starve` (pop the Famine would kill, after guards); `{}` on the last turn or after game over.
It runs the upkeep effects on a fork (`GameEngine.fork`, a new engine on `GameState.copy()`, 051), so the game itself
never changes. Upkeep effects are still limited to resources, bonus score and pop (`Effect.upkeep_ok`, 043). The top bar shows it as "Food: 2 (+1)",
with the food stat in the warning color when pop would starve.

Pending decisions (050, `pending()`): an explore choice, open research or a hand-limit discard. While one is owed,
every action is refused with the same message (`_blocked_error`), except that a discard still lets you discard and
browse the supply. A new decision kind (e.g. events) adds one `PENDING_*` constant and one branch there.

## Territories (Milestone 2 — in design)
Loop: **explore → settle → build**. Territories give expansion a purpose and turn building
into a placement decision, without a map. Backlog items 001–006 build it in slices
(001 done: territory cards, territory deck, starting territory, tableau groups;
002 done: explore, frontier, choice panel; 003 done: settle, card targets, targeting UI; 004 done: building slots; 005 done: keyword requires and bonuses; 006: content in, playtesting next).

- **Territory cards**: `type: "territory"`, with `slots` (building capacity) and `keywords`
  (Fresh Water, Flood Plain, Mountain, Jungle, …). They come from a separate `territory_deck` zone.
- **Explore** (`explore` op, e.g. on Scout): reveal the top 2 territories and pick 1. The pick goes
  to the **frontier** zone (discovered, unclaimed); the other goes to the bottom of the territory
  deck. Play and end turn are blocked while the choice is pending. With 1 territory left it is
  taken automatically; with 0 nothing happens.
- **Settle** (`settle` op, on Settler): move a frontier territory to the tableau and found a City
  on it. Each territory holds one city. The Capital starts on `starting.territory`.
- **Slots**: a city card may add `slots` to its territory (the Capital gives +4). A building must be placed in a settled territory with a free slot. The player picks
  the territory; if only one is valid, the engine picks it.
- **Keywords are tags; card data gives them meaning:**
  - Building `requires: [...]`: the territory must have any of the listed keywords (e.g. Farm and
    Irrigation need Fresh Water, so the Capital starts on River Meadow, which has it).
  - Effect `keyword` condition: the effect applies only if the card's territory has that keyword
    (e.g. Farm +1 more food on Flood Plain).
  - Both check the territory copy's keywords (`CardInstance.keywords`: printed, then rolled resources).
- Code: `engine/effects/explore_effect.gd`, `settle_effect.gd`; slots, targets and keywords in
  `engine/territories.gd` and `engine/card_play.gd`. A city or building links to its territory through `CardInstance.territory_uid`.
- **Config:**
  - `keywords` (terrain keywords, validated like `resources`)
  - `resource_keywords` and `territory_resources` (rolled per copy, 036)
  - `territory_deck` ({id: count})
  - `starting.territory`

## Milestone 1
- [x] Godot project + folder skeleton, autoload, test framework
- [x] Engine: state, zones, seeded RNG, actions, turn loop, 5 effect ops
- [x] JSON data loader with validation
- [x] 22-card fixed deck from 9 card types, plus Capital/City (event cards once threat is designed)
- [x] UI: hand, tableau (headed "Realm" on screen, on top; 053; a territory's cards wrap, 078; a group's territory is
  its one-line title bar, and groups collapse to that and a summary from `territory_summary`, with Collapse all on
  the Realm heading, 087), stats bar, game log; drag or double-click to play, E ends turn, full keyboard play (017) (event panel waits on threat design)
- [x] End-of-game score screen, restart with seed
- [x] Drag cards to play (double-click fallback), card and resource animations (008)
- [x] Engine unit tests

## Population (Milestone 3 — built, playtesting next)
Pop lives on each settled territory and is held, not spent. Backlog: 009 (pop, housing, pop VP; done),
010 (buy growth with food; done), 011 (food upkeep and starvation; done), 012 (workers gate buildings; done), 013 (growth cards; done).
- Config `population: { "start": 2, "food_upkeep": 1, "vp_per_pop": 1, "famine": { "card": "famine",
  "max_counters": 3 } }` turns the rules on; without the block the game has no pop (the test fixtures leave it out;
  `raw_config` adds `FAMINE` when a test turns it on). `famine` is required with population on (083).
- The starting territory gets `start` pop; a settled territory gets 1. Pop can't exceed `housing`: the
  territory's own plus its buildings' (060).
- Upkeep: after every card's upkeep effects, pop eats `food_upkeep` food each. Famine (083, replaces 011's one
  death per unpaid food): when pop can't be fed in full, the famine card (an event, never in `event_deck`, with no
  `discard`) becomes active if it isn't, gains a counter up to `max_counters`, and its upkeep effects resolve once
  per counter (real data: −1 pop from the territory with the most pop, ties settled first). A fed upkeep, even
  with 0 food left, removes it from the game. One Famine at a time; no growth while it lasts (`grow_error`, and
  `grow` adds nothing); `famine_counters()` / `event_counters(uid)`; the event panel shows "N counters". Pop can
  reach 0; the city stays. Famine guard (060): the working buildings on a territory (decided before pop eats) save
  up to their total `famine_guard` of the Famine's deaths there each upkeep; `upkeep_forecast().starve` counts only
  the pop that die. A guard save skips one counter's upkeep effects (096).
- Relief (084): `famine.relief` (optional cost, e.g. `{ "wealth": 5 }`; real data 5 wealth) lets the player pay to
  end an active Famine at once (`relieve_famine()` / `relieve_famine_error()`, the Relieve button under the Events
  row; `famine_relief()` gives the price). A later hungry upkeep brings a new Famine with 1 counter. The sim bot
  relieves before ending a turn when it can pay and `upkeep_forecast().starve` is still above 0.
- Growth cards: the `grow` op (`{ "op": "grow", "amount": 1, "where": "here" | "each" }`) adds pop for free,
  capped by housing: `here` on the card's own territory (the Granary until 060, upkeep), `each` on every settled territory
  (Harvest Festival until 069, now an event; no shipped card uses `each` today). `here` is a load error on a tech
  or an event, which has no territory (069).
- Workers: a building needs a free worker (pop − buildings on its territory > 0) as well as a free slot.
  If pop drops below the building count, the buildings placed last are idle: they skip upkeep (decided
  before pop eats) but keep their printed VP. Cities never use a worker.
- Score = printed VP + effect VP + total pop × `vp_per_pop`.
- Growth: during play, `grow(territory_uid)` pays `grow_cost` = pop + 1 food for +1 pop, up to housing, with no
  limit per turn. `grow_error` says why not (like `play_error`). The UI shows a Grow button on each territory.
- Code: pop, housing, growth and workers in `engine/population.gd`; the `grow` op in `engine/effects/grow_effect.gd`.

## Techs (Milestone 4 — in progress)
Techs never enter the main deck. Backlog: 025 (research deck, reveal 2, buy or decline; built), 026 (passes,
stacking discount, prerequisite discount, removal; built), 027 (eras, `add_era`, Library; built), 028 (first content; built: 13 techs in eras 1–2, Library via Writing; Pasture, Harbor, Monument,
Pyramids and Forge left the deck and come back through techs), 034 (Research is a card; built), 058 (Stone Age → Bronze
Age tree; built: 7 era-1 techs, Bronze Working adds era 2, 6 era-2 techs; era-3 techs defined but not in the deck).
- Gating (058): a tech that gives a card creates 1 free copy in the discard and unlocks that card's locked supply pile
  (057), so more copies can be bought. Wonders (tag `wonder`, e.g. Pyramids via Priesthood) are created only. The
  starting deck is the basics: Farm 4, Irrigation 1, Settler 2, Scout 2, Lumber Camp 2, Insight 2, Barter 1 (2 food →
  2 wealth), Storyteller 1 (1 food: draw 2). Early buildings (080) are on sale from turn 1, in unlocked supply piles
  with no deck copies: Fishing Huts (coastal, ⟳ +1 food), Quarry (hills/mountain, +1 VP) and Shrine (anywhere, 1 VP,
  culture), so every territory can take a building before any tech.
- Card type `tech`: cost is wealth only (≥ 1); no `keyword` and no targeting effects. Config `research_deck` ({tech_id: count}).
  Techs are not allowed in `deck`.
- Research is a card (034): the `research` op (`{ "op": "research" }`, play only, no fields) reveals the top 2
  techs (`reveal_techs`). There is no free research: the deck starts with 1 Research card and the supply sells 2,
  with no limit per turn. With nothing to reveal the card can't be played ("The research deck is empty.").
  `buy_tech(uid)` pays `tech_cost(uid)` wealth, moves the tech to `researched`, resolves its `play` effects, and
  shuffles the other back; `decline_research()` shuffles both back. Open options block play, grow, discard and end turn.
- Researched techs score their printed VP and resolve `upkeep` effects like tableau cards; they use no territory,
  slot or worker.
- Passes (026): buying one revealed tech gives the other a pass (`tech_passes(uid)`); declining passes nothing.
  Each pass is -1 wealth, and a third pass sends the tech to `lost_techs`. A tech's optional `prereq` (another
  tech) with `prereq_discount` (default 2) lowers its cost while the prereq is in `researched`; it never blocks a
  purchase. `tech_cost` = max(1, printed - passes - prereq discount).
- Eras (027): a tech's `era` (default 1) decides where it starts: era 1 in `research_deck`, later eras in
  `future_techs`. The `add_era` op (`{ "op": "add_era", "era": 2 }`, on a tech or building) shuffles that era's
  techs into the research deck, once per era (`era()` is the highest added). Researching with an empty research
  deck adds the lowest waiting era; it only errors when nothing waits. A tech with `add_era` is never lost
  (its passes stop at 2). The Library creates a Research card in the discard when built (034; it used
  to add research actions at upkeep).
- Era thresholds (029): config `era_unlocks` ({"2": {"pop": 8, "wealth": 15}}) adds an era at the start of a turn
  (after upkeep and pop eating) when total pop or wealth on hand reaches either number. Wealth is not spent; an era
  already added isn't added again. `era_unlocks()` returns the thresholds; the tech tree shows them.
- An effect can refuse its card in `play_error` (`Effect.play_block_error`), as Research does with an empty deck.
- Code: research, passes and eras in `engine/research.gd`; `engine/effects/research_effect.gd`, `add_era_effect.gd`.
- Tech tree (059): `tech_tree()` lists every tech in `research_deck` by era, then config order, as
  `{id, era, prereq, state, cost, passes, gives}`; `state` is `GameEngine.TECH_RESEARCHED` / `TECH_AVAILABLE` (research
  deck or revealed) / `TECH_FUTURE` / `TECH_LOST`, `gives` the cards it creates or unlocks. Optional config
  `era_names` (`{"1": "Stone Age"}`) feeds `era_name(n)`, default "Era n".
- UI: a Knowledge (T) button above End turn (with the current era's name; hidden when the config has no research
  deck) opens the tech tree modal: one column per era with its thresholds, each tech's state as a mark and a word,
  cost now, prereq ("after Mining") and what it gives; clicking a tech opens its details. A choice panel shows the
  revealed techs (click one to buy) and Decline, and a Known row the researched techs.

## Supply (backlog 032)
Players can spend wealth to add more copies of existing cards to their deck. No new cards: some of the
starting deck moved into the supply (Scout, Settler, Temple, Granary); 034 adds Research (price 3, 2 copies). Since 058
the building piles (Granary, Pasture, Mine, Temple, Caravan, Monument, Forge, Library, Market, Harbor) start locked.
- Config `supply: { "scout": { "price": 2, "count": 2 } }`: only `action` and `building` cards; `price`
  (wealth) and `count` are integers ≥ 1. Without the block the supply is empty. `deck_model` stays `fixed`.
- `buy(card_id)` pays `buy_price` wealth, puts a new copy on top of the discard and lowers the pile by 1.
  There is no limit per turn; an empty pile can't be bought from. Blocked like grow (game over, explore
  choice, research open, discard owed).
- Locked piles (057): `"locked": true` on a supply entry keeps the pile shut until an `unlock` effect
  (`{ "op": "unlock", "card": "guildhall" }`, play only) opens it, typically on a tech next to a `create` of the free
  copy. `supply()` still lists locked piles; `supply_locked(card_id)` tells them apart, `buy_error` says
  "X isn't unlocked yet.", and the Supply screen hides them. Every `unlock` on a card the config uses must name a
  supply pile. The lock state is in `GameState.locked_supply` and copied by `fork()`.
- Code: supply and `buy` in `engine/supply.gd`.
- UI (033): a Supply (S) button above the Knowledge button opens the supply screen, an overlay with one card per pile
  ("2 wealth · 1 left" under it). Click or Enter buys and the screen stays open; S or Esc closes it. It can't
  open during an explore or research choice or after the game ends. Buying squashes the card, flies a wealth
  token and sends a copy to the screen's Discard counter (all off with Reduce motion).

## Events (backlog 039)
The framework for solo opposition; real events, harmful ops and the event UI come later.
- Card type `event`: no `cost`, `vp` 0, no `keyword` and no targeting effects. Optional `discard`, the condition
  that ends it; for now only `{"turns": n}` (int ≥ 1, default 1), an unknown condition is a loader error. Card text
  and tooltip add "Lasts n turns" (tooltip: 070). Config `event_deck` ({event_id: count}, default {}); events are not allowed in `deck` or `supply`.
- Zones `event_deck` (shuffled by seed at setup), `active_events` and `event_discard`.
- Eras (074): an event may set `era` (int ≥ 1, default 1), like a tech. Only era-1 events start in `event_deck`;
  later ones wait in `future_events`. When an era is added (the `add_era` op, the empty research deck, or an
  `era_unlocks` threshold), its events are shuffled into `event_deck`, once; the era-1 events, the active events
  and the event discard stay as they are. The event pile line's tooltip says how many events wait.
- Event phase (once per `end_turn()`, before the hand-limit discard, also on the final turn): draws the top event,
  shuffling `event_discard` back in when the deck is empty (nothing when both are empty), makes it active with
  `turns_left` = its `discard.turns`, and resolves its `play` effects. Then `event_drawn(outcome)` reports it (079:
  `{uid, id, gained, lost, vp, drawn, created}`, before `changed`); the UI pops up a modal with the event and
  `outcome_summary(outcome)` ("No immediate effect" when empty), except when the game just ended. Play outcomes
  gain `lost` too: what a `lose` effect actually took.
- Upkeep: each active event resolves its `upkeep` effects, then its `turns_left` drops by 1 and at 0 it moves to
  `event_discard`, so a 1-turn event gives exactly one upkeep. `event_turns_left(uid)` reads it; the forecast
  includes active events.
- Code: `engine/events.gd`.
- Starter deck (069): 13 events, all neutral or small boons: 4 blank (Solstice Rites, Traveling Bards, Comet Sighted,
  Distant Drums), +1 food, +1 wealth, +1 VP ×2, ⟳ +1 food for 2 turns, ⟳ +1 wealth, Forage (+2 food, 2 copies)
  and Harvest Festival (⟳ +1 food per farm). Forage and Harvest Festival left the main deck (now 19 cards), and the
  supply's Granary pile grew to 3 to keep growth cards available.
- UI (068): an Events row below Researched shows the active events as compact cards with "N turns left", and an
  "Events: deck N · discard M" label sits under the Knowledge button (tooltip: one event is drawn at the end of each
  turn). Both are hidden when the config has no event deck. An ending event flies to that label.

## Civilizations (backlog 062)
A game is played as one civilization: a permanent card with a starting gift and ongoing bonuses.
- Card type `civilization`: never in `deck`, `supply`, `territory_deck`, `research_deck` or `event_deck`. Config
  `starting.civilization` (optional, a civilization id) puts it in the `civilization` zone at `new_game`, where its
  `start` effects resolve once, before turn 1's upkeep. `civilization()` is its uid, or -1.
- It resolves `upkeep` every turn and scores its printed VP like a researched tech: `GameEngine.ALWAYS_ON_ZONES`
  (`researched`, `civilization`, `government`) lists the permanents outside the tableau.
- Card text marks start effects "Start:" (face) and "When the game starts:" (tooltip).
- Choosing (064): config `civilizations` (optional, civilization ids in order, no duplicates; `starting.civilization`
  must be one of them) lists what a game may start as; `civilizations()` returns it. `new_game(seed, civ_id)` plays
  as civ_id, or `starting.civilization` when civ_id is ""; `new_game_error(civ_id)` refuses an unlisted id. The
  civilization is created after every shuffle and roll, so the same seed deals the same game whatever you choose.
- Real data (064): Children of the River (⟳ +1 food; the default), Salt Road Traders (Start: +3 wealth; ⟳ +1 wealth),
  Hearth Clans (Start: +4 food), Star Watchers (1 VP; ⟳ +1 VP).
- UI: the start screen shows the civilizations as cards; a click selects one (and `Settings` saves it) and New game
  plays it. The saved one is preselected (`SettingsStore.civilization_in` falls back to the first, with a warning,
  if it's no longer offered). Restart, Replay and the game-over New game keep the civilization; the menu says
  "Playing as …" and the game-over text "Played as …". In play, the civilization is a line in the side panel (088).

## Governments (backlog 065)
Your people have one government at a time; its bonuses apply while it rules.
- Card type `government`: never in `deck`, `supply`, `territory_deck`, `research_deck` or `event_deck`, but a `create`
  may put one in the discard, so it's drawn and played like any hand card. Its effects can't need a target, use
  `keyword` or act on their own territory (like a tech's). Config `starting.government` (optional, a government id)
  puts it in the `government` zone at `new_game`. `government()` is its uid, or -1.
- Playing one pays its cost, moves it to `government` and moves the ruling one to `removed` (out of the game); then its
  `play` effects resolve. The outcome's `to_zone` is `government`. `play_error` refuses a government with the same id
  as the ruling one ("X is already your government.").
- The ruling government is in `ALWAYS_ON_ZONES`: it resolves upkeep (and the forecast), and scores its printed VP.
- Real data: Chiefdom (no bonus; the start), Kingship (⟳ +1 wealth; from Code of Laws), Theocracy (⟳ +1 VP; from
  Priesthood). Techs that give a government create it in the discard; it has no supply pile.
- UI: the civilization and the government are one-line buttons in the side panel above Knowledge (088): hover shows
  the rules, a click opens the details, and a played government flies to its line.

## Later
- Smarter bots for the simulator (greedy, then search); starvation and era-timing stats
- Save/load, undo (on `GameState.copy()`, 051)
- More eras, wonders, techs, automated rival
