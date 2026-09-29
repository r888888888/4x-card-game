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
| Win condition (demo) | Game ends after 20 turns; final score = sum of VP on tableau cards |
| Resources (demo) | Food and wealth; unspent resources carry over with no cap. Food pays for people (growth, upkeep, Settlers), wealth for premium buildings (Temple, Monument, Pyramids, Forge cost both; Capital, Caravan, Market make wealth) (021, 022) |
| Threat effects | Deferred: event phase is a stub until designed |

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
    game_engine.gd       # game state, actions and their *_error queries, turn loop, score
    data_loader.gd       # JSON → CardDef + normalized config; collects all errors/warnings
    card_def.gd          # immutable definition; short card text and full tooltip text generated from effects
    card_instance.gd     # runtime copy of a card (uid + def + territory_uid)
    zone.gd              # named ordered pile (deck, hand, discard, tableau, frontier, research_deck, …)
    effect.gd            # Effect base class
    fields.gd            # Fields: read_int / read_string / as_int for card, config and effect fields
    effect_registry.gd   # op name → effect script
    effects/             # one <op>_effect.gd per effect op
    rng.gd               # seeded RNG (reproducible games)
  autoload/game.gd       # "Game" singleton: loads data, owns the engine
  autoload/settings.gd   # "Settings" singleton: player settings (reduce motion), saved via SettingsStore
  autoload/settings_store.gd # ConfigFile at user://settings.cfg; bad values fall back with a warning
  ui/                    # main.tscn/main.gd (layout built in code), card_view.gd, anim.gd (animation tuning),
                         # icons.gd (text glyphs → icon images in cards and the log)
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
- `trigger` is `play` (default), `upkeep`, or later `event`. Only `gain`, `gain_per_tag`, `score` and `grow` may use
  `upkeep` (043): the forecast restores only resources, bonus score and pop, so other ops are a loader error there.
- `cost` is an object keyed by resource, so adding resources later doesn't change the format.
- Conditional or compound effects nest naturally, e.g. `{ "op": "if", "cond": {...}, "then": [...] }`.
- The loader validates every card (required fields, known `op`s, known resources) and reports
  errors with file, card id and field. Unknown fields are warnings, not errors.
- Deck contents and starting state live in `config.json` (e.g. `"deck": { "farm": 4, "scout": 3, ... }`).
- Territory cards (`"type": "territory"`) need `slots` (int ≥ 0), may set `housing` (int ≥ 1, default
  `slots + 2`) and may list `keywords` from config `keywords`. They go in `territory_deck` (never `deck`); `starting.territory` names the Capital's.
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
1. Upkeep: cities and buildings trigger `@upkeep` (produce food), then pop eats food (starving on a shortfall).
2. Draw up to hand size (unplayed cards stay in hand).
3. Play: play or buy cards while resources allow, buy growth for territories, and play Research cards to reveal techs. A hand card can be discarded for free at any time.
4. Event: stub for now (threat design deferred).
5. Cleanup: keep the hand, but over `hand_limit` (7) you must discard down to it before the turn ends; unspent food carries over. The final turn discards the hand. After turn 20, show final score.

Forecast (035, `upkeep_forecast` in `engine/game_engine.gd`): returns what the next upkeep does to each resource on hand, food net of what
pop eats (may be negative), plus `starve` (pop the shortfall would kill); `{}` on the last turn or after game over.
It runs the upkeep effects quietly and restores resources, bonus score and pop, which is all an upkeep effect may
change (`Effect.upkeep_ok`, 043). The top bar shows it as "Food: 2 (+1)",
with the food stat in the warning color when pop would starve.

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
  - Building `requires: [...]`: the territory must have any of the listed keywords.
  - Effect `keyword` condition: the effect applies only if the card's territory has that keyword
    (e.g. Farm +1 more food on Flood Plain).
  - Both check the territory copy's keywords (`CardInstance.keywords`: printed, then rolled resources).
- Code: `engine/effects/explore_effect.gd`, `settle_effect.gd`; slots, targets and keywords in
  `engine/game_engine.gd`. A city or building links to its territory through `CardInstance.territory_uid`.
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
- [x] UI: hand, tableau, stats bar, game log; drag or double-click to play, E ends turn, full keyboard play (017) (event panel waits on threat design)
- [x] End-of-game score screen, restart with seed
- [x] Drag cards to play (double-click fallback), card and resource animations (008)
- [x] Engine unit tests

## Population (Milestone 3 — built, playtesting next)
Pop lives on each settled territory and is held, not spent. Backlog: 009 (pop, housing, pop VP; done),
010 (buy growth with food; done), 011 (food upkeep and starvation; done), 012 (workers gate buildings; done), 013 (growth cards; done).
- Config `population: { "start": 2, "food_upkeep": 1, "vp_per_pop": 1 }` turns the rules on; without the
  block the game has no pop (the test fixtures leave it out).
- The starting territory gets `start` pop; a settled territory gets 1. Pop can't exceed `housing`.
- Upkeep: after every card's upkeep effects, pop eats `food_upkeep` food each. Each food that can't be paid
  starves 1 pop from the territory with the most pop (ties: settled first). Pop can reach 0; the city stays.
- Growth cards: the `grow` op (`{ "op": "grow", "amount": 1, "where": "here" | "each" }`) adds pop for free,
  capped by housing: `here` on the card's own territory (Granary, upkeep), `each` on every settled territory
  (Harvest Festival).
- Workers: a building needs a free worker (pop − buildings on its territory > 0) as well as a free slot.
  If pop drops below the building count, the buildings placed last are idle: they skip upkeep (decided
  before pop eats) but keep their printed VP. Cities never use a worker.
- Score = printed VP + effect VP + total pop × `vp_per_pop`.
- Growth: during play, `grow(territory_uid)` pays `grow_cost` = pop + 1 food for +1 pop, up to housing, with no
  limit per turn. `grow_error` says why not (like `play_error`). The UI shows a Grow button on each territory.
- Code: pop, housing, growth and workers in `engine/game_engine.gd`; the `grow` op in `engine/effects/grow_effect.gd`.

## Techs (Milestone 4 — in progress)
Techs never enter the main deck. Backlog: 025 (research deck, reveal 2, buy or decline; built), 026 (passes,
stacking discount, prerequisite discount, removal; built), 027 (eras, `add_era`, Library; built), 028 (first content; built: 13 techs in eras 1–2, Library via Writing; Pasture, Harbor, Monument,
Pyramids and Forge left the deck and come back through techs), 034 (Research is a card; built).
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
  already added isn't added again. `era_unlocks()` returns the thresholds; the research info label's tooltip shows them.
- An effect can refuse its card in `play_error` (`Effect.play_block_error`), as Research does with an empty deck.
- Code: research, passes and eras in `engine/game_engine.gd`; `engine/effects/research_effect.gd`, `add_era_effect.gd`.
- UI: a research info label above End turn (research deck count, era, lost techs; hidden when the config has no
  research deck), a choice panel with the revealed techs (click one to buy) and Decline, and a Researched row.

## Supply (backlog 032)
Players can spend wealth to add more copies of existing cards to their deck. No new cards: some of the
starting deck moved into the supply (Scout, Settler, Temple, Granary); 034 adds Research (price 3, 2 copies).
- Config `supply: { "scout": { "price": 2, "count": 2 } }`: only `action` and `building` cards; `price`
  (wealth) and `count` are integers ≥ 1. Without the block the supply is empty. `deck_model` stays `fixed`.
- `buy(card_id)` pays `buy_price` wealth, puts a new copy on top of the discard and lowers the pile by 1.
  There is no limit per turn; an empty pile can't be bought from. Blocked like grow (game over, explore
  choice, research open, discard owed).
- Code: supply and `buy` in `engine/game_engine.gd`.
- UI (033): a Supply (S) button above the research info opens the supply screen, an overlay with one card per pile
  ("2 wealth · 1 left" under it). Click or Enter buys and the screen stays open; S or Esc closes it. It can't
  open during an explore or research choice or after the game ends. Buying squashes the card, flies a wealth
  token and sends a copy to the screen's Discard counter (all off with Reduce motion).

## Later
- Smarter bots for the simulator (greedy, then search); starvation and era-timing stats
- Save/load, undo (snapshot GameState)
- More eras, wonders, techs, automated rival
