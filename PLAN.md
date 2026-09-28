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
| Balance simulation | Later (engine kept headless-capable so it's cheap to add) |
| Win condition (demo) | Game ends after 20 turns; final score = sum of VP on tableau cards |
| Resources (demo) | Food and wealth; unspent resources carry over with no cap. Food pays for people (growth, upkeep, Settlers), wealth for premium buildings (Temple, Monument, Pyramids, Forge cost both; Capital, Caravan, Market make wealth) (021, 022) |
| Threat effects | Deferred: event phase is a stub until designed |

## Architecture principle
The rules engine is plain GDScript (`RefCounted`/`Resource` classes, no scene nodes).
Scenes only display state and send player actions. The engine talks to the UI
through signals. This keeps rules testable and allows headless simulation later
(`godot --headless --script sim/run.gd`).

## Project layout (as built)
```
res://
  data/
    cards.json           # player card definitions
    config.json          # resources, keywords, turn limit, hand size, deck model, starting state, deck lists
  engine/                # plain GDScript, no scene nodes
    game_engine.gd       # GameState + actions + turn loop (play_card, end_turn, play_error, valid_targets, choose, score)
    data_loader.gd       # JSON → CardDef + normalized config; collects all errors/warnings
    card_def.gd          # immutable definition; short card text and full tooltip text generated from effects
    card_instance.gd     # runtime copy of a card (uid + def + territory_uid)
    zone.gd              # named ordered pile: deck, hand, discard, tableau, territory_deck, frontier, reveal, research_deck, research_reveal, researched
    effect.gd            # Effect base class + field readers
    effect_registry.gd   # op name → effect script
    effects/             # gain, gain_per_tag, draw, create, score, explore, settle, grow
    rng.gd               # seeded RNG (reproducible games)
  autoload/game.gd       # "Game" singleton: loads data, owns the engine
  autoload/settings.gd   # "Settings" singleton: player settings (reduce motion), saved via SettingsStore
  autoload/settings_store.gd # ConfigFile at user://settings.cfg; bad values fall back with a warning
  ui/                    # main.tscn/main.gd (layout built in code), card_view.gd, anim.gd (animation tuning),
                         # icons.gd (text glyphs → icon images in cards and the log)
  assets/icons/          # hand-drawn white 24×24 SVGs, imported as DPITexture and tinted in code
  tests/
    run_tests.gd         # dependency-free runner: finds tests/**/test_*.gd (use scripts/test.sh)
    lib/test_case.gd     # assertions, TEST_CARDS fixture, make_engine and helpers
    test_data_loader.gd  # loader validation tests
    test_rules.gd        # engine rules tests
    test_play_outcome.gd # card_played outcome tests
  scripts/test.sh        # test entry point; scripts/test-hook.sh is the Claude Code Stop hook
  docs/                  # development process, testing guide, backlog
```
Adding an effect: create `engine/effects/<name>_effect.gd` (extends Effect) and register it in `effect_registry.gd`.
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
- `trigger` is `play` (default), `upkeep`, or later `event`.
- `cost` is an object keyed by resource, so adding resources later doesn't change the format.
- Conditional or compound effects nest naturally, e.g. `{ "op": "if", "cond": {...}, "then": [...] }`.
- The loader validates every card (required fields, known `op`s, known resources) and reports
  errors with file, card id and field. Unknown fields are warnings, not errors.
- Deck contents and starting state live in `config.json` (e.g. `"deck": { "farm": 4, "scout": 3, ... }`).
- Territory cards (`"type": "territory"`) need `slots` (int ≥ 0), may set `housing` (int ≥ 1, default
  `slots + 2`) and may list `keywords` from config `keywords`. They go in `territory_deck` (never `deck`); `starting.territory` names the Capital's.
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
3. Play: play or buy cards while resources allow, buy growth for territories, and research once per turn. A hand card can be discarded for free at any time.
4. Event: stub for now (threat design deferred).
5. Cleanup: keep the hand, but over `hand_limit` (7) you must discard down to it before the turn ends; unspent food carries over. The final turn discards the hand. After turn 20, show final score.

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
- **Slots**: a building must be placed in a settled territory with a free slot. The player picks
  the territory; if only one is valid, the engine picks it.
- **Keywords are tags; card data gives them meaning:**
  - Building `requires: [...]`: the territory must have any of the listed keywords.
  - Effect `keyword` condition: the effect applies only if the card's territory has that keyword
    (e.g. Farm +1 more food on Flood Plain).
- **Engine API:**
  - `play_card(uid, target_uid := -1)`, `play_error(uid, target_uid := -1)`
  - `valid_targets(uid)`
  - `pending_choice` + `choose(uid)` (explore only)
  - `CardInstance.territory_uid` links a city or building to its territory.
- **Config:**
  - `keywords` (known list, validated like `resources`)
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
  (Harvest Festival). Engine helper: `add_pop(territory_uid, amount, source)`.
- Workers: a building needs a free worker (pop − buildings on its territory > 0) as well as a free slot.
  If pop drops below the building count, the buildings placed last are idle: they skip upkeep (decided
  before pop eats) but keep their printed VP. Cities never use a worker.
- Score = printed VP + effect VP + total pop × `vp_per_pop`.
- Growth: during play, `grow(territory_uid)` pays `grow_cost` = pop + 1 food for +1 pop, up to housing, with no
  limit per turn. `grow_error` says why not (like `play_error`). The UI shows a Grow button on each territory.
- Engine API: `population_on()`, `pop(territory_uid)`, `housing(territory_uid)`, `total_pop()`,
  `grow_cost(territory_uid)`, `grow_error(territory_uid)`, `grow(territory_uid)`, `free_workers(territory_uid)`,
  `is_idle(uid)`.

## Techs (Milestone 4 — in progress)
Techs never enter the main deck. Backlog: 025 (research deck, reveal 2, buy or decline; built), 026 (passes,
stacking discount, prerequisite discount, removal; built), 027 (eras, `add_era`, Library), 028 (first content).
- Card type `tech`: cost is wealth only (≥ 1); no `keyword` and no targeting effects. Config `research_deck` ({tech_id: count}).
  Techs are not allowed in `deck`.
- Once per turn (`research_left()`), a free action: `research()` reveals the top 2 techs. `buy_tech(uid)` pays
  `tech_cost(uid)` wealth, moves the tech to `researched`, resolves its `play` effects, and shuffles the other back;
  `decline_research()` shuffles both back (the charge stays spent). Open options block play, grow, discard and end turn.
- Researched techs score their printed VP and resolve `upkeep` effects like tableau cards; they use no territory,
  slot or worker.
- Passes (026): buying one revealed tech gives the other a pass (`tech_passes(uid)`); declining passes nothing.
  Each pass is -1 wealth, and a third pass sends the tech to `lost_techs`. A tech's optional `prereq` (another
  tech) with `prereq_discount` (default 2) lowers its cost while the prereq is in `researched`; it never blocks a
  purchase. `tech_cost` = max(1, printed - passes - prereq discount).
- Engine API: `research_error()`, `research()`, `research_options()`, `research_left()`, `buy_tech_error(uid)`,
  `buy_tech(uid)`, `tech_cost(uid)`, `tech_passes(uid)`, `decline_research()`.
- UI: a Research button (R) above End turn (hidden when the config has no research deck), a choice panel
  with the revealed techs (click one to buy) and Decline, and a Researched row.

## Later
- Headless bot + balance stats (random, then greedy)
- Save/load, undo (snapshot GameState)
- More eras, wonders, techs, automated rival
