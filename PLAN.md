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
| Balance simulation | Headless scripted bot over many seeds (`scripts/sim.sh`, 042), playing five strategies as every civilization (134: baseline, growth, wealth, wide, tall); compared against `main`, not pinned in tests; the games run on one process per core (152) |
| Win condition (demo) | Game ends after 100 turns (20 until 066); final score = sum of VP on tableau cards |
| Resources (demo) | Food, wealth and insight (139); unspent resources carry over with no cap. Food pays for people (upkeep, Settlers, growth cards: 262), insight for techs (Capital ⟳ +1, Library ⟳ +2; start with 0), wealth for buildings: non-food buildings cost wealth only, food producers 1 food + wealth; start with 2 food + 2 wealth (Capital, Caravan, Market make wealth; Market +1 per city, 077) (021, 022, 076, 077). Unrest (144) is only gained and lost, capped at the government's unrest limit (see Governments) |
| Actions (127) | Playing a card from hand uses 1 action; nothing else does (buying, learning a tech, choosing an explored territory, relieving a Famine, discarding). The ruling government's `actions` sets how many a turn has (Chiefdom 2, Kingship and Theocracy 3); unused ones are lost |
| Threat effects | Event deck (039): one event drawn per turn, active until it lasts out; harmful ops (072), the Famine (083), eras of events (074) and revolutionary events (148); barbarians are specced (160–168) |

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
    game_engine.gd       # public API: actions and their *_error queries, fork(), the constants; calls the modules below
    engine_queries.gd    # EngineQueries, GameEngine's parent (249): the read queries (score, pop, targets, forecast, …)
    engine_core.gd       # EngineCore, EngineQueries' parent (125): state and accessors, signals, effect hooks (gain, draw, …), _log/_resolve
    game_state.gd        # GameState: everything that changes during a game; copy() is a deep copy (051)
    turn_loop.gd         # TurnLoop: new game setup, start of turn (upkeep, feeding, era unlocks, draw), end turn, discard
    card_play.gd         # CardPlay: play_error, valid targets, playing a hand card
    population.gd        # Population: pop, housing, growth, workers, idle buildings, feeding
    research.gd          # Research: learning techs from the open tree, prerequisites, eras
    supply.gd            # Supply: buying from the card supply
    territories.gd       # Territories: explore and choose, settle, slots, keyword requirements, tableau groups
    discounts.gd         # Discounts (108): what a civilization's discounts take off play, tech and supply costs
    modifiers.gd         # Modifiers (129): the working cards (also upkeep's), standing modifiers summed over them
    famine.gd            # Famine: brought by a hungry upkeep, counters, guard saves, no growth, ends when fed
    anarchy.gd           # Anarchy (145–148, 154, 155): falling at the unrest limit, counters, restore order, renewal, revolt,
                         # the government deck and choice
    events.gd            # Events: event deck setup, drawing one at each turn start, active events' upkeep and discard
    card_details.gd      # CardDetails: a card's rules, live state and explained terms for the details modal (056)
    glossary.gd          # Glossary: fixed mechanic terms (Upkeep, Slots, Workers, …); keyword terms are generated;
                         # BASIC ones (Upkeep, Slots, Pop) are left out of card details (112)
    data_loader.gd       # JSON → CardDef; load_all reads both files; collects all errors/warnings
    config_loader.gd     # config.json → normalized config, checked against the cards (095)
    card_def.gd          # immutable definition; short card text and full tooltip text generated from effects
    card_instance.gd     # runtime copy of a card (uid + def + territory_uid, pop, keywords, turns_left)
    zone.gd              # named ordered pile (deck, hand, discard, tableau, frontier, research_deck, …)
    effect.gd            # Effect base class
    fields.gd            # Fields: read_int / read_string / as_int for card, config and effect fields
    effect_registry.gd   # op name → effect script
    effects/             # one <op>_effect.gd per effect op
    rng.gd               # seeded RNG (reproducible games)
  autoload/game.gd       # "Game" singleton: loads data, owns the engine, reads the launch options
  autoload/launch_options.gd # LaunchOptions (135): --civ, --turns, --seed for the game and the sim
  autoload/settings.gd   # "Settings" singleton: player settings (reduce motion, day mode, sound volumes and interface
                         # sounds, 184), saved via SettingsStore; it sets the audio buses' volumes and mutes
  autoload/settings_store.gd # ConfigFile at user://settings.cfg; bad values fall back with a warning
  ui/                    # main.tscn/main.gd (MainScreen: actions, menu, refresh, test hooks), board_layout.gd
                         # (176: BoardLayout builds the layout and components in code), board_views.gd (176:
                         # BoardViews keeps the card views in line with the engine: deal, place, fly, leave)
                         # cards: card_view.gd (CardView: panel, tooltip, border), card_face.gd (086: its content),
                         # card_motion.gd (086: resting, flying, dragging, leaving), anim.gd (animation tuning),
                         # icons.gd (text glyphs → icon images in cards and the log), ui_kit.gd (shared styles,
                         # labels, overlays, button columns)
                         # board: top_bar.gd (stats, Buy Cards, Knowledge, Log, Menu; on a ruled Strip, 221), sidebar.gd
                         # (202: the right rail, open on the board, 221: the civilization, government and End turn),
                         # counter.gd (181: Counter, a glyph, an odometer figure and the forecast; no tag since 218),
                         # odometer.gd (181: Odometer, a figure whose digits roll),
                         # tableau_view.gd (102, 137: the Realm's row: events, frontier, territories),
                         # territory_view.gd (101, 105: one territory in place of the Realm, its pop meter (124)),
                         # action_button.gd (175: ActionButton, the Relieve famine (084), Restore order (146) and Revolt
                         # (148) buttons below the Realm),
                         # log_drawer.gd (115, 121: the log, deck and discard counts), toasts.gd (116, 250: notices as flags
                         # out of the rail), drag_controller.gd (drag and targeting), card_focus.gd (keyboard focus and keys)
                         # overlays and modals: choice_overlays.gd (explore, renewal 147, government 154, behind
                         # cabinet_doors.gd, 209),
                         # supply_screen.gd (Buy Cards), game_menu.gd and game_over_overlay.gd (Modals since 207),
                         # modal.gd (153: Modal, every modal's base: scrim, close keys, click outside; 207: the drafting
                         # sheet with its title block, body and footer, risen in and dropped off),
                         # modal_stack.gd (153: ModalStack, main.modals: the top one takes input, closing one closes
                         # those above it), card_details_modal.gd (click, right-click or I),
                         # knowledge_screen.gd (208: Knowledge or T, a screen sliding over the Realm, drawn as a drafting sheet, 222; the tech tree modal before it), event_modal.gd (each drawn event, 079), identity_modal.gd (119; Revolt… since 205),
                         # revolt_modal.gd (205: the revolution's confirmation), rename_modal.gd (248: naming a territory)
                         # screens: navigator.gd (103, 104: the screen stack, titles and transitions; main.nav),
                         # screen_header.gd (104, 118, 241: the title bar and its divider tab back), start_screen.gd (063, 099: the title screen),
                         # new_game_screen.gd (099: civilization list and detail pane since 212, seed, Start), settings_modal.gd (206: the settings, a modal from the menu and the title screen)
                         # look: palette.gd (106: every UI colour, named; 183: a Night and a Day value each, switched by
                         # Palette.use, and UIKit.painted / repaint for colours set in code), game_theme.gd (106: the Theme built in
                         # code, with Heading/Title/Stat/DarkPanel/Strip/Rail variations), tokens.gd (193, 194: the guide's spacing,
                         # corner radius and type scales, Tokens.SPACE_*, RADIUS_* and TYPE_*)
                         # sound: sfx.gd (186: Sfx, main.sfx: every sound token, its level, bus, files and rules),
                         # key_sounds.gd (187: every button's click and a disabled key's dead tap), event_sounds.gd (191:
                         # the engine's milestones as Level 3 sounds); legend_key.gd, top_bar.gd (End turn), odometer.gd,
                         # card_motion.gd, modal_stack.gd, navigator.gd and toasts.gd play their own tokens (187–190)
  assets/icons/          # hand-drawn white 24×24 SVGs, imported as DPITexture and tinted in code
  assets/sounds/         # ui/ (Levels 1–2, variants _a…_d) and events/ (Level 3) WAVs, placeholders rendered by
                         # docs/design/sound-export.html from the specimen's synthesis (186)
  default_bus_layout.tres # the audio buses: Game and Interface into Master, each with its limiter (184)
  tests/                 # run_tests.gd runner, lib/test_case.gd helpers, test_<area>.gd (see docs/testing.md)
  sim/                   # bot.gd (ScriptedBot and its strategies, 134), sim_stats.gd (SimStats: per-seed metrics, per
                         # strategy and civilization), run.gd (CLI)
  scripts/test.sh        # test entry point; scripts/test-hook.sh is the Claude Code Stop hook
  scripts/sim.sh         # balance simulator: scripts/sim.sh [seeds] [strategy] [--civ id] [--turns n] (no strategy: all)
  docs/                  # development process, testing guide, backlog
```
Prices (173): an action checks a price ({resource: amount}) with `can_pay` / `price_error` and pays it with `pay`, all on
`EngineCore`; unrest is added or capped only through `set_unrest`, which stops at `unrest_limit()`.
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
- Standing modifiers (129): buildings, cities, techs, civilizations, governments and events may set `modifiers`, an
  object of `DataLoader.MODIFIER_KEYS` (`actions`, `hand_size`, `housing`, `unrest_limit`, `renewal`, `insight_per_gain`) to non-zero ints, e.g.
  `"modifiers": {"actions": 1}`. `insight_per_gain` (157) is added to each insight gain in `EngineCore.gain`, never below
  0 ("Each insight gain −1"); a per-count op or `trade` is one gain. Real data: Theocracy −1.
  `modifier(key)` sums one over the working tableau cards (not idle), `ALWAYS_ON_ZONES` and the active events
  (`Modifiers.total`); `actions_per_turn()` adds the `actions` modifier to the government's, never below 1. Text
  "+1 action each turn" (an event's tooltip adds "while active"). `hand_size` (109): `hand_size()` is config
  `hand_size` plus the modifier, between 1 and `hand_limit`, and the turn draws up to it ("Draw up to 1 more card each
  turn"); a card whose `hand_size` alone takes config `hand_size` past `hand_limit` is a config error. `housing` (110)
  adds to every settled territory's housing, never below 1 ("Every territory houses 1 more pop"); a building's own
  `housing` field (its territory, idle or not) is separate. `population.start` is checked against printed housing.
  `unrest_limit` (144) adds to the government's unrest limit ("Unrest limit +1").
- `gain_actions` (128, play only): `{ "op": "gain_actions", "amount": 1 }` (amount defaults to 1) gives that many more
  actions this turn (127), on top of the government's; they don't carry over, and the op does nothing while actions
  are unlimited. A load error on `start` or on an event (both resolve outside your plays): `Effect.needs_a_turn`.
  Text "+1 action" (tooltip "+1 action this turn"). Real data: Scout and Barter.
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
- Terrains (130): config `terrains` (a subset of `keywords`) names the terrain keywords; the rest are features (fresh
  water, coastal, …). With `terrains` set, every territory card prints exactly one terrain (a load error otherwise).
- Buildings may set `housing` (int ≥ 1: added to their territory's housing, idle or not) and `famine_guard` (int ≥ 1:
  pop on their territory saved from starving each upkeep, while working) (060).
- Units (`"type": "unit"`, 160) need `strength` (int ≥ 1). Played from the hand onto a settled territory with a free
  worker, their home: they take no slot but use a worker there (with its buildings, in placement order, so the last
  placed go idle first), and stand on a station (the home until moved). No `requires`, no effect `keyword`
  and no `grow` "here" (a unit can move, so it has no fixed land). They go in `deck` or `supply`, never the other decks.
- Moving and disbanding (163): `move_unit(uid, territory)` stations a unit on another settled territory for one action,
  once a turn per unit (`GameState.moved_units`); its home and worker stay. `disband(uid)` sends it to the discard,
  freeing its worker, for no action. `move_targets`, `unit_move_block` and `unit_origin` ("from Homeland") feed the
  details modal's Move… and Disband and the unit's face.
- Defence (161): buildings and cities may set `defense` (int ≥ 1), and config `terrain_defense` maps keywords (resource
  keywords too) to ints ≥ 1. A settled territory's `defense(uid)` sums the `unit_strength` of the units stationed
  there, its working buildings' and its cities' `defense`, and `terrain_defense` for every keyword of the copy;
  `defense_parts(uid)` gives `{units, buildings, cities, terrain, total}`. Rules in `engine/military.gd` (`Military`).
- Training (164): a building may set `training` (int ≥ 1). `unit_strength(uid)` is a unit's printed strength plus the
  `training` of the working buildings on its station (0 when idle), and defence sums it. A trained unit's face shows
  `unit_strength_tag(uid)` ("Strength 3") and its details explain the bonus.
- Resource keywords (config `resource_keywords`, e.g. gold) are never printed on a territory: each copy rolls
  them from its weighted table in config `territory_resources` (`{"hills": [{"keywords": ["gold"], "weight": 1},
  {"keywords": [], "weight": 1}]}`) when the game starts, with the seeded rng. A table is keyed by territory id or
  by terrain (130); a territory's own table wins over its terrain's, and a key can't be both. No table, no roll.
  Iron counts as everywhere, so it isn't a keyword (036). Shipped: gold, tin and copper on the hills
  and mountain terrains; Forge scores +1 VP each upkeep on copper and on tin (037).
- Territory slots and housing follow the land (038): fertile river land has high housing, flat land more
  slots, and rough terrain (hills, mountain, marsh, desert) low on both, to be made up by keywords.
- Shipped set (131): six terrains (grassland, forest, hills, mountain, desert, marsh) times the features fresh water,
  flood plain (always with fresh water) and coastal; every keyword is on at least 2 territory types. Slots/housing come
  from a terrain base plus +1 housing per feature (flood plain also −1 slot, min 1), until a balance pass.
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
2. Draw up to hand size (unplayed cards stay in hand); under Anarchy, renewal is owed.
3. Event (237: from turn 2): draw one event from the event deck and resolve its `play` effects (see Events). It is
   drawn last so it is active all turn: you see it in the Realm and play around it, and an event that lasts N turns
   is active for N play phases.
4. Play: play cards while actions (127) and resources allow, buy cards, play Research cards (id `research`) for insight, and learn techs in the tech tree (140). A hand card can be discarded for free at any time.
5. Cleanup: keep the hand, but over `hand_limit` (7) you must discard down to it before the turn ends; unspent food carries over. The final turn discards the hand. After the last turn (`turn_limit`, 100 in the real data), show final score.

Forecast (035, `upkeep_forecast` in `engine/game_engine.gd`): returns what the next upkeep does to each resource on hand, food net of what
pop eats (may be negative), plus `starve` (pop the Famine would kill, after guards); `{}` on the last turn or after game over.
It runs the upkeep effects on a fork (`GameEngine.fork`, a new engine on `GameState.copy()`, 051), so the game itself
never changes. Upkeep effects are still limited to resources, bonus score and pop (`Effect.upkeep_ok`, 043). The top bar shows it as "Food: 2 (+1)" (and Wealth, Insight, and "Unrest: 2 (+1)", 144; its limit is in the tooltip, 228),
with the food stat in the warning color when pop would starve.

Pending decisions (050, `pending()`): an explore choice, a hand-limit discard, a renewal (147) or the government
choice (154). It is one dictionary in the state, `GameState.pending` (172), and `pending()` returns a copy with the
options a discard, renewal or government choice has now. While one is owed, every action is refused with the same
message (`_blocked_error`), except the decision's own action, and a discard still lets you discard, browse the supply
and learn techs. A decision's own action checks the game being over, then another decision owed, then its own
"nothing owed" message (`_owed_error`). A new kind follows the `add-decision` skill.

## Territories (Milestone 2 — in design)
Loop: **explore → settle → build**. Territories give expansion a purpose and turn building
into a placement decision, without a map. Backlog items 001–006 build it in slices
(001 done: territory cards, territory deck, starting territory, tableau groups;
002 done: explore, frontier, choice panel; 003 done: settle, card targets, targeting UI; 004 done: building slots; 005 done: keyword requires and bonuses; 006: content in, playtesting next).

- **Territory cards**: `type: "territory"`, with `slots` (building capacity) and `keywords`
  (a terrain such as Hills or Desert, plus features such as Fresh Water or Coastal). They come from a separate `territory_deck` zone.
- **Explore** (`explore` op, e.g. on Scout): reveal the top 2 territories and pick 1. The pick goes
  to the **frontier** zone (discovered, unclaimed); the other goes to the bottom of the territory
  deck. Play and end turn are blocked while the choice is pending. With 1 territory left it is
  taken automatically; with 0 nothing happens.
- **Settle** (`settle` op, on Settler): move a frontier territory to the tableau and found a City
  on it. Each territory holds one city. The Capital starts on `starting.territory`.
- **Slots**: a city card may add `slots` to its territory (the Capital gives +3, 113). A building must be placed in a settled territory with a free slot. The player picks
  the territory; if only one is valid, the engine picks it.
- **Keywords are tags; card data gives them meaning:**
  - Building `requires: [...]`: the territory must have any of the listed keywords (e.g. Farm needs
    Fresh Water, so the Capital starts on River Meadow, which has it).
  - Effect `keyword` condition: the effect applies only if the card's territory has that keyword
    (e.g. Farm +1 more food on Flood Plain).
  - Both check the territory copy's keywords (`CardInstance.keywords`: printed, then rolled resources).
- Code: `engine/effects/explore_effect.gd`, `settle_effect.gd`; slots, targets and keywords in
  `engine/territories.gd` and `engine/card_play.gd`. A city or building links to its territory through `CardInstance.territory_uid`.
- **Config:**
  - `keywords` (printable territory keywords, validated like `resources`) and `terrains` (the terrain subset, 130)
  - `resource_keywords` and `territory_resources` (rolled per copy, 036)
  - `territory_deck` ({id: count})
  - `starting.territory`

## Milestone 1
- [x] Godot project + folder skeleton, autoload, test framework
- [x] Engine: state, zones, seeded RNG, actions, turn loop, 5 effect ops
- [x] JSON data loader with validation
- [x] 22-card fixed deck from 9 card types, plus Capital/City (event cards once threat is designed)
- [x] UI: hand, tableau (headed "Realm" on screen, on top; 053; one wrapping row of cards, 078: the active events and
  frontier territories first (137; no Frontier, Known or Events rows, and Relieve below the row), then each settled
  territory as a card with its slots and pop, then cards on no territory, 102; every card in the row one fixed height
  with one line per field, the rest in its details, frontier territories hatched with a dashed border and a badge,
  events badged with their turns left, 138; a click opens the territory view with
  its city, buildings and pop meter, 101; 087's collapsing groups are gone), top bar (stats; civilization and government, Buy Cards, Knowledge, Log, End turn, Menu; keys in the tooltips, 120), the game log in a drawer (L; 115, no sidebar) with the deck and discard counts (121; cards deal from and discard to the Log button) whose notable lines also show as notification flags out of the rail (116, 250); drag or double-click to play, E ends turn, full keyboard play (017)
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
  with 0 food left, removes it from the game. One Famine at a time; the `grow` op adds nothing while it lasts; `famine_counters()` / `event_counters(uid)`; the event panel shows "N counters". Pop can
  reach 0; the city stays. Famine guard (060): the working buildings on a territory (decided before pop eats) save
  up to their total `famine_guard` of the Famine's deaths there each upkeep; `upkeep_forecast().starve` counts only
  the pop that die. A guard save skips one counter's upkeep effects (096).
- Relief (084): `famine.relief` (optional cost, e.g. `{ "wealth": 5 }`; real data 5 wealth) lets the player pay to
  end an active Famine at once (`relieve_famine()` / `relieve_famine_error()`, the Relieve button below the
  Realm; `famine_relief()` gives the price). A later hungry upkeep brings a new Famine with 1 counter. The sim bot
  relieves before ending a turn when it can pay and `upkeep_forecast().starve` is still above 0.
- Growth cards: the `grow` op (`{ "op": "grow", "amount": 1, "where": "here" | "each" | "best", "count": 3 }`) adds
  pop for free, capped by housing: `here` on the card's own territory (the Granary until 060, upkeep), `each` on every
  settled territory (Harvest Festival until 069, now an event), or with `count` on at most that many, smallest pop
  first among those with room (ties: tableau order; 261). `best` adds it all to one territory: one with idle buildings
  first, else the smallest with room (`Population.best_to_grow`, 261). `here` is a load error on a tech or an event,
  which has no territory (069); `count` only goes with `each`.
- Workers: a building needs a free worker (pop − buildings on its territory > 0) as well as a free slot.
  If pop drops below the building count, the buildings placed last are idle: they skip upkeep (decided
  before pop eats) but keep their printed VP. Cities never use a worker.
- Score = printed VP + effect VP + total pop × `vp_per_pop`.
- Growth (262): pop grows only from growth cards, never by itself (260's automatic growth from a food surplus is
  gone, and 010's bought Grow with it). Bread and Beer (action, 2 food: +1 pop where it's needed most; 1 in the
  starting deck, 8 in the supply at 2) and Land Grants (action, 5 food: +1 pop on each of your 3 smallest territories
  with room; 4 in the supply at 3). Growth competes for actions and food. In the territory view pop is a meter of pips,
  one per housing (124).
- Code: pop, housing, growth and workers in `engine/population.gd`; the `grow` op in `engine/effects/grow_effect.gd`.

## Techs (Milestone 4 — in progress)
Techs never enter the main deck. Backlog: 025 (research deck; built; reveal-2 replaced by 140), 026 (passes and the
prerequisite discount; built, removed by 140), 139 (Insight pays for techs; built), 140 (open tech tree; built), 027 (eras, `add_era`, Library; built), 028 (first content; built: 13 techs in eras 1–2, Library via Writing; Pasture, Harbor, Monument,
Pyramids and Forge left the deck and come back through techs), 034 (Research is a card; built), 058 (Stone Age → Bronze
Age tree; built: 7 era-1 techs, Bronze Working adds era 2, 6 era-2 techs), 141–142 (eurekas, diffusion; built), 143
(Iron Age: 6 era-3 techs in the deck, opened by Writing; eurekas on every tech; pacing; built).
- Gating (058): a tech that gives a card creates 1 free copy in the discard and unlocks that card's locked supply pile
  (057), so more copies can be bought. Wonders (tag `wonder`) are created only, one copy each, and also carry `culture` (265): era 1 Oracle of Delphi
  (Mysticism, ⟳ +2 insight) and Walls of Uruk (Masonry, defence 4, unrest limit +1); era 2 Pyramids (Priesthood),
  Great Ziggurat (Code of Laws, ⟳ −1 unrest, limit +2), Hanging Gardens (Calendar, fresh water, every territory houses
  1 more), Great Library (Writing, ⟳ +3 insight), Great Harbor of Tyre (Sailing, coastal, ⟳ +1 wealth per coastal
  territory) and Royal Road (Currency, hand size +1). The
  starting deck is the basics (132): Farm 3 (⟳ +2 food, +1 more on a flood plain), Settler 2, Scout 2, Hunters' Camp 2 (forest; Lumber Camp until 263),
  Research 2, Barter 2 (2 food → 2 wealth), Storyteller 1 (1 food: draw 2), Hunt 1. Early buildings (080) are on sale from turn 1, in unlocked supply piles,
  Farm and Hunters' Camp too (232, 263), the rest with no deck copies: Fishing Huts (coastal, ⟳ +1 food) and Shrine (anywhere, 1 VP,
  culture), so every territory can take a building before any tech (Quarry, a one-time +1 VP, was removed by 263: every building
  gives something lasting). Mines (Mining) make ⟳ +1 wealth, +1 more each for gold, tin and copper (132, 263); Harbor (Sailing)
  makes ⟳ +1 food and +2 wealth; Temple ⟳ −1 unrest, with ⟳ +1 VP only on a mountain (263).
- Card type `tech`: cost is insight only (≥ 1, 139; era 1 costs 5–8, era 2 13–19, era 3 27–32, set by 143 so era 1 runs out around turn 18 and era 2
  around 50 in the sim); no `keyword` and no targeting effects. Config `research_deck` ({tech_id: count}).
  Techs are not allowed in `deck`.
- Open tree (140): every tech in `research_deck` whose `prereq` is researched can be learned at any time, with no card
  or action: `buy_tech(uid)` pays `tech_cost(uid)` insight, moves the tech to `researched` and resolves its `play`
  effects. `buy_tech_error` refuses when the game is over or an explore choice is open ("Choose a territory first.";
  learning goes on while a discard is owed), when the tech isn't in the research deck ("That tech isn't on offer."),
  when its prereq isn't researched ("Iron Working needs Bronze Working first.") or when insight is short. The Research
  card (id `research`) just gains 3 insight; `research_card_name()` names the first deck-then-supply card that gains
  insight, for hints. Nothing is ever pending for research.
- Researched techs score their printed VP and resolve `upkeep` effects like tableau cards; they use no territory,
  slot or worker.
- Prerequisites (026, hard since 140): a tech's optional `prereq` (another tech) must be researched before it can be
  learned; card text "Needs Bronze Working". Techs that need each other are one load error per cycle (174), on its
  first tech in card order ("prereq: cycle a → b → a").
- Eurekas (141): a tech's optional `eureka` (`{"card": "farm" | "tag": "city", "count": 2, "off": 2}`) takes `off`
  insight off while the tableau holds `count` matching cards (idle ones count). Card text "Eureka: -2 insight with 2
  Farms"; real eurekas take 2 insight in era 1, 4 in era 2 and 6 in era 3 (143). `tech_tree()` entries carry `eureka` (met or not) and the tree shows the line, ✔ when met.
- Diffusion (142): a tech costs 1 insight less per era added past its own (`Research.diffusion`); the details say
  "−1 older era". `tech_cost` = max(1, printed − civilization discount − eureka − diffusion).
- Eras (027): a tech's `era` (default 1) decides where it starts: era 1 in `research_deck`, later eras in
  `future_techs`. The `add_era` op (`{ "op": "add_era", "era": 2 }`, on a tech or building) shuffles that era's
  techs into the research deck, once per era (`era()` is the highest added). Learning the last tech of the research
  deck adds the lowest waiting era (140). The Library makes ⟳ +2 insight (139; a pile of 6 since 264), the Stone Circle ⟳ +1 (Mysticism, 264).
- Era thresholds (029): config `era_unlocks` ({"2": {"pop": 8, "wealth": 15}}) adds an era at the start of a turn
  (after upkeep and pop eating) when total pop or wealth on hand reaches either number. Wealth is not spent; an era
  already added isn't added again. `era_unlocks()` returns the thresholds; the tech tree shows them.
- An effect can refuse its card in `play_error` (`Effect.play_block_error`).
- Code: learning, prerequisites and eras in `engine/research.gd`; `engine/effects/add_era_effect.gd`.
- Tech tree (059): `tech_tree()` lists every tech in `research_deck` by era, then config order, as
  `{id, era, prereq, state, cost, gives, uid}`; `state` is `GameEngine.TECH_RESEARCHED` / `TECH_AVAILABLE` (in the
  research deck, prereq met) / `TECH_LOCKED` (prereq not researched) / `TECH_FUTURE`, `gives` the cards it creates or
  unlocks, `uid` −1 for a future tech. Optional config
  `era_names` (`{"1": "Stone Age"}`) feeds `era_name(n)`, default "Era n".
- UI: a Knowledge button (T) in the top bar (the current era's name in its tooltip; hidden when the config has no
  research deck) opens the Knowledge screen (208), drawn as a drafting sheet (222): "Insight N · play a Research card
  for more", then one band per era with its title block at the left and its techs as index-card tiles of one size.
  A tile shows the tech's name and a marker (✓ researched, its cost now, "needs Mining" while locked) and "✔ Eureka"
  when met, and is filled by state (teal researched, well locked); its tooltip has the state in words, why it can't
  be learned (`buy_tech_error`), what it gives and its eureka. A click, Enter, a right click or I opens the
  details, whose Learn button researches a tech not yet learned (disabled with `buy_tech_error`, 229). An era not reached lies under a vellum printed "<ERA> · OPENS AT 8
  POP OR 15 WEALTH". Researched techs show only in the tech tree (137).

## Supply (backlog 032)
Players can spend wealth to add more copies of existing cards to their deck. No new cards: some of the
starting deck moved into the supply (Scout, Settler, Temple, Granary); 034 adds Research (price 3, 2 copies). Since 058
the building piles (Granary, Pasture, Mine, Temple, Caravan, Monument, Forge, Library, Market, Harbor) start locked.
264 adds locked piles for Stone Circle (Mysticism, ⟳ +1 insight), Mud-Brick Houses (Pottery, housing 2), Caravanserai
(The Wheel, desert, ⟳ +1 wealth, +1 more on fresh water), Bathhouse (Priesthood, fresh water, housing 1, ⟳ −1 unrest),
Courthouse (Code of Laws, ⟳ −1 unrest, unrest limit +1) and Aqueduct (Engineering, housing 2; Engineering gave a second
Monument until then): every terrain has a building, every era opens a new one.
- Config `supply: { "scout": { "price": 2, "count": 2 } }`: only `action` and `building` cards; `price`
  (wealth) and `count` are integers ≥ 1. Without the block the supply is empty. `deck_model` stays `fixed`.
- `buy(card_id)` pays `buy_price` wealth, puts a new copy on top of the discard and lowers the pile by 1.
  There is no limit per turn; an empty pile can't be bought from. Blocked like grow (game over, explore
  choice, discard owed).
- Locked piles (057): `"locked": true` on a supply entry keeps the pile shut until an `unlock` effect
  (`{ "op": "unlock", "card": "guildhall" }`, play only) opens it, typically on a tech next to a `create` of the free
  copy. `supply()` still lists locked piles; `supply_locked(card_id)` tells them apart, `buy_error` says
  "X isn't unlocked yet.", and the Supply screen hides them. Every `unlock` on a card the config uses must name a
  supply pile. The lock state is in `GameState.locked_supply` and copied by `fork()`.
- Code: supply and `buy` in `engine/supply.gd`.
- UI (033): the top bar's Buy Cards button (S, 115) opens the supply screen, an overlay with one card per pile
  (232: its play cost after discounts in its title row, `supply_play_cost`, as on a hand card; its price on a gold
  "Buy" tag hanging below it, and the copies left under that). Click or Enter opens the pile's details over the
  screen (259): the card with its tag and count under it, and a Buy key, disabled with the engine's reason on the
  footer's left when the pile can't be bought; Buy closes the details and the screen stays open. S or Esc closes it. It can't
  open during an explore choice or after the game ends. Buying rolls the screen's wealth figure down with a
  "−N" tag (181) and sends a copy to the screen's Discard counter (all off with Reduce motion).

## Events (backlog 039)
The framework for solo opposition. Harmful ops (072), the Famine (083), eras (074) and the event modal (079) build on it.
- Card type `event`: no `cost`, `vp` 0, no `keyword` and no targeting effects. Optional `discard`, the condition
  that ends it; for now only `{"turns": n}` (int ≥ 1, default 1), an unknown condition is a loader error. Card text
  and tooltip add "Lasts n turns" (tooltip: 070). Config `event_deck` ({event_id: count}, default {}); events are not allowed in `deck` or `supply`.
- Zones `event_deck` (shuffled by seed at setup), `active_events` and `event_discard`.
- Eras (074): an event may set `era` (int ≥ 1, default 1), like a tech. Only era-1 events start in `event_deck`;
  later ones wait in `future_events`. When an era is added (the `add_era` op, the empty research deck, or an
  `era_unlocks` threshold), its events are shuffled into `event_deck`, once; the era-1 events, the active events
  and the event discard stay as they are. The event pile line's tooltip says how many events wait.
- The turn's event (237: last in each turn start from turn 2, after upkeep, feeding, the Anarchy check and drain, the
  hand draw and renewal; none on turn 1 or after the final turn): draws the top event,
  shuffling `event_discard` back in when the deck is empty (nothing when both are empty), makes it active with
  `turns_left` = its `discard.turns`, and resolves its `play` effects. Then `event_drawn(outcome)` reports it (079:
  `{uid, id, gained, lost, vp, drawn, created}`, before `changed`); the UI pops up a modal with the event and
  `outcome_summary(outcome)` ("No immediate effect" when empty), except when the game just ended. Play outcomes
  gain `lost` too: what a `lose` effect actually took.
- Upkeep: each active event resolves its `upkeep` effects, then its `turns_left` drops by 1 and at 0 it moves to
  `event_discard`, so a 1-turn event is active for the turn it is drawn and gives exactly one upkeep, at the next
  turn's start. An unrest event that reaches the limit leaves a turn to calm before the Anarchy check. `event_turns_left(uid)` reads it; the forecast
  includes active events.
- Raids (162): an event may set `raid` `{strength (≥ 1), targets (config keywords, optional), pop (≥ 0, default 1)}`
  (never with `discard`), and only a raid's effects may use the triggers `repel` and `pillage` (upkeep-safe ops only).
  When drawn it is announced: its play effects resolve and its target is fixed (`raid_target(uid)`, kept in the
  event's `territory_uid`) on the settled territory with any of `targets` (all of them when none has one) with the
  lowest `defense`, then the most pop, then tableau order. It skips upkeep and two event phases later (257: at turn T+2's
  start when drawn on turn T, before the new event is drawn; `raid_turns_left(uid)` counts 2, 1), it strikes: repelled when the target's defence ≥ its strength (its `repel` effects), else
  pillaged (its `pillage` effects, the units stationed there to the discard, `pop` pop lost, never below 0); then it
  goes to `event_discard` and `raid_resolved(outcome)` reports `{uid, target, strength, defense, repelled, units_lost,
  pop_lost, gained, lost, vp}`. A raid drawn on the final turn or the one before never strikes.
  Pacing (257): a raid is drawn only while raids are allowed: `realm_size()` (config `territory_value` per settled
  territory plus the total cost of every city, building and unit in the tableau) is at least `raid_min_size`, no raid
  is active, and `raid_gap` turns have passed since the last strike (`GameState.last_raid_turn`; no gap before the
  first). Otherwise it goes to the event deck's bottom and the next event is drawn; with only such raids left, no
  event that turn. Shipped: `territory_value` 3, `raid_min_size` 12, `raid_gap` 4. `raid_forecast()` lists the announced
  raids with their target's current defence; the UI reads `raid_line`, `raid_tag`, `raid_short` and `raid_warning`.
  Shipped era 1: Raiders (2, grassland/desert), Sea Raiders (3, coastal), Hill Tribes (3, hills/mountain). Rules in
  `Military`.
- Code: `engine/events.gd`.
- Starter deck (069): 13 events, all neutral or small boons: 4 blank (Solstice Rites, Traveling Bards, Comet Sighted,
  Distant Drums), +1 food, +1 wealth, +1 VP ×2, ⟳ +1 food for 2 turns, ⟳ +1 wealth, Forage (+2 food, 2 copies)
  and Harvest Festival (⟳ +1 food per farm). Forage and Harvest Festival left the main deck (now 19 cards), and the
  supply's Granary pile grew to 3 to keep growth cards available.
- UI (068, 137, 138): the active events lead the Realm's row as board cards with their turns left (a Famine shows its
  counters); the row's tooltip says one event is drawn at the start of each turn from turn 2. None show without an event deck.

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
- Real data (107, replacing 064's four): six civilizations of antiquity. Egypt (⟳ +1 food per fresh water or flood
  plain territory; the default), Sumer (Start: a Farm on its home, 133, and a Research in the discard; ⟳ +1 food per farm; houses +1 pop everywhere, 110), Phoenicia (Start: +3
  wealth; ⟳ +1 wealth per coastal territory), Babylon (Start: Kingship in the discard), Greece (Start: a Storyteller in
  the discard; draws up to 6, 109), Persia (Start: a Caravan in the discard; ⟳ +1 wealth). A start gift is always a card the game
  also hands out otherwise. A start `create` into the tableau (133) must name a building and puts it on the home; the
  config loader checks it meets the home's keywords and fits its slots (the territory's plus the starting tableau's).
- Discounts (108): a civilization's optional `discounts` is a list of entries, each with one filter (`type`: a card
  type, `tag`, or `supply: true`) and amounts of resources (ints ≥ 1), e.g. `{"tag": "wonder", "wealth": 3}`. A type
  or tag discount lowers a hand card's `play_cost(uid)` (what `play_error` checks and `play_card` charges, never below 0
  per resource) and a tech's `tech_cost` (never below 1); a supply discount lowers `buy_price` (never below 0). Text
  "Wonders cost 3 less wealth." Real data: Babylon techs −1 insight, Phoenicia supply −1 wealth, Egypt wonders −3
  wealth. Hand cards show their cost after discounts; card details show the printed cost.
- Home (111): a civilization may set `home`, a territory card id. A game as it starts on that territory (the
  Capital on it, `population.start` pop) instead of `starting.territory`; the home isn't drawn from `territory_deck`,
  and its resource roll uses a copy of the rng, so the same seed deals and rolls the same whatever the civilization.
  `population.start` must fit every listed civilization's home. Card text: "Starts on: <territory>". Real data:
  Egypt Desert Floodplain, Sumer Delta Marsh, Babylon Alluvial Plain, Phoenicia Cedar Coast, Greece Coastal Hills,
  Persia Highland Valley; every home takes most of the starting deck's buildings.
- City names (248): a civilization may set `city_names` (distinct, non-empty strings). The home and each territory
  settled after it take the next name (`CardInstance.city_name`; `GameState.names_given` counts them), then the list
  again as "Thebes II", "Thebes III", …; without a list a territory keeps its card's name. `territory_name(uid)` is the
  name it goes by; `rename_territory(uid, name)` / `rename_territory_error` rename a settled territory (trimmed, 1 to
  `MAX_TERRITORY_NAME` 24 characters, no action, never shifts the next default). The territory view and its Realm card
  show the name over the land's; the view's Rename… opens `RenameModal`. Real data: 12 historical names each.
- Flavor (107): a civilization may set `flavor` (a paragraph) and `quote` ({"text", "by"}); both optional, non-empty
  strings. `def_details` / `card_details` return `flavor` ("" if none) and `quote` ({} if none) for every card, and
  the details modal shows them first (flavor in italics, then the quote and who said it), before the rules. On the
  new game screen a click on a civilization selects it and opens these details, with a "Play as <name>" button that
  starts the game as it.
  A government (205), a tech and an event (215) may set `flavor` too, and a government or a tech a `quote` (an event
  may not); every real tech has both and every real event a flavor line. Flavor and quotes show only in the details,
  never on a card face.
- UI: the new game screen (099) shows the civilizations as cards; a click selects one (and `Settings` saves it) and
  Start plays it. The saved one is preselected (`SettingsStore.civilization_in` falls back to the first, with a warning,
  if it's no longer offered). Restart, Replay and the game-over New game keep the civilization; the menu says
  "Playing as …" and the game-over text "Played as …". In play, the civilization is named on the top bar's civilization and government button (088, 115, 119).

## Governments (backlog 065)
Your people have one government at a time; its bonuses apply while it rules.
- Card type `government`: never in `deck`, `supply`, `territory_deck`, `research_deck` or `event_deck`. A `create`
  of one (any zone) puts it in the government deck, the `governments` zone, unless one with its id is already there or
  rules (then nothing is created; 154). Its effects can't need a target, use
  `keyword` or act on their own territory (like a tech's). Config `starting.government` (optional, a government id)
  puts it in the `government` zone at `new_game`. `government()` is its uid, or -1.
- Government deck (154): when Anarchy ends (burning out or `restore_order`), no government rules and `pending()` is
  `{kind: PENDING_GOVERNMENT, options: the deck's uids}`, `default_government()` first (254: the config's
  starting government when it's in the deck, else the deck's first; -1 with no choice owed); every other action
  refuses ("Choose a government first.").
  `choose_government(uid)` / `choose_government_error(uid)` ("No government to choose.", "That government isn't in
  your government deck."): it leaves the deck and rules, unrest drops to at most half its limit (modifier added
  first), its `play` effects resolve and its cost isn't paid; no action used. The Government overlay shows the deck in
  that order with the card focus on the default (Left/Right move it, Enter chooses), a click chooses; the civilization modal shows the deck as a row of tabs under its two cards (231). The bot chooses by lookahead (159).
- Bot lookahead (159, `sim/bot.gd`): `ScriptedBot.lookahead(engine, strategy, government_id, revolt)` plays a fork
  `LOOKAHEAD_TURNS` (12) turns on and returns its score; the real game is untouched. When the government choice is
  owed the bot chooses the option whose lookahead scores most (ties: deck order; one option: no lookahead). Every
  `REVOLT_EVERY` (4) turns, at the end of the turn and not in the last 6, it revolts when a lookahead that revolts to
  some government in the deck outscores staying. Inside a lookahead it never revolts and chooses the government the
  fork was opened for, else `best_government` (154's ranking: most `actions`, then highest `unrest_limit`, then deck
  order). It values score only, not research.
- A government is never played from hand (155): `play_error` is "A government is chosen, not played.". When Anarchy
  runs out at the end of a turn, `pending()` carries the choice before the next turn starts and choosing finishes the
  turn; after `restore_order` the turn goes on.
- The ruling government is in `ALWAYS_ON_ZONES`: it resolves upkeep (and the forecast), and scores its printed VP.
- Actions (127): a government's optional `actions` (int ≥ 1; text "2 actions each turn.") is how many cards can be
  played from hand each turn while it rules. `actions_per_turn()` and `actions_left()` (-1 for both when no government
  rules or it sets none: unlimited, as in the test fixtures); `play_error` says "No actions left this turn." after the
  game-over and pending-decision checks. `GameState.actions_used` counts plays (reset at the start of a turn), so a
  government chosen mid-turn counts at once. The rules are in `CardPlay`; the counter sits beside the hand's heading.
- Unrest (144): `EngineCore.UNREST`, on when config `resources` lists it (`unrest_on()`; test fixtures leave it out). A
  government's optional `unrest_limit` (int ≥ 1; text "Unrest limit 5.") caps it: `unrest_limit()` is that plus the
  `unrest_limit` modifier, never below 0, and -1 (no limit) while unrest is off or the government sets none;
  `at_unrest_limit()` says unrest has reached it. `gain` stops unrest at the limit and reports what it added. Unrest can't
  be paid: in a cost, a civilization discount, `population.famine.relief` or a `trade` it is a load error ("unrest can't
  be paid (it is only gained and lost)", `Fields.unpayable`).
- Anarchy (145, `engine/anarchy.gd`): config `unrest` `{anarchy, max_counters, era_unrest (0), allowed_tag
  ("")}`, only with unrest listed (`fallback` dropped in 154, `relief` in 155: unknown fields); `anarchy` is a
  event (253) with no `discard`, never in `event_deck` (it may carry a `quote`, as any event may). A turn that starts
  (after upkeep, feeding and era unlocks, before the draw) with unrest at the limit falls: the government goes to the
  government deck (154), the anarchy event joins `active_events` (`anarchy()` its uid) and no government rules
  (`government()` -1, so `unrest_limit()` is -1). While it lasts only `allowed_tag` cards play ("Anarchy: only an order
  card can be played."), grow, buy and `buy_tech` refuse ("Anarchy: nothing can be grown, bought or researched."),
  `actions_per_turn()` is the actions modifier alone (the event's `modifiers: {actions: 1}` included, never below 1),
  and its upkeep resolves with the other events' without counting it down. `event_counters(uid)` shows its counters
  left on the board, and the sidebar names it in the government's place. Each added era adds `era_unrest` (capped).
- Anarchy's length (155): it falls with ⌈max_counters × unrest ÷ L⌉ counters, 1 to max_counters, L the fallen
  government's `unrest_limit()` (`GameState.anarchy_limit`). `anarchy_counters()` is the counters left: calming lowers
  them for good (`EngineCore._unrest_lowered` → `Anarchy.calm`), never below 1 while it rules. One comes off at the end
  of each Anarchy turn (after the hand-limit discard, in `TurnLoop.finish_turn`); at 0 the anarchy event goes to
  `removed` and the government choice is owed (154). From its second turn (`GameState.anarchy_turn`) `restore_order()`
  buys the rest off for c × (c + 1) wealth (`order_relief()`; `restore_order_error()`: "Order can't be restored on
  Anarchy's first turn.", the price short); the choice is owed at once. The Restore order button sits beside Relieve
  famine below the Realm. The bot pays from the second turn with 2+ counters left or a starving upkeep ahead.
- Renewal (147): with config `unrest.renewal` (int ≥ 0; absent = renewal off), each turn that starts under Anarchy
  owes, after the draw, `pending()` `{kind: PENDING_RENEWAL, count, options}`: count = renewal + (Anarchy's turn − 1)
  + the `renewal` modifier ("Renewal trashes 1 more card"), capped at the options: the hand's, deck's and discard's
  cards but governments, by name then uid (255). `renew(uids)` / `renew_error(uids)` pay it at once, exactly count
  distinct options, each trashed from wherever it is (−1 unrest each; the deck keeps its order); refusals: "Trash a
  card from your hand, deck or discard (not a government).", "Each card can be trashed once.", "Choose 2 cards to
  trash.". Until paid every other action is refused ("Anarchy: trash 2 cards from your hand, deck or discard
  first."). The Renewal modal (`RenewalModal`, not dismissable) lists the options as a ledger: hover or Up/Down shows
  a row's card, a click or Enter chooses it (its lamp lights, `ui.toggle.on`; again, `ui.toggle.off`; past the count
  `ui.reject.locked`), and "Trash N cards" unlocks at the count. The bot trashes the count's cards worth least (cost
  + 2 × VP, +4 building, +3 calms unrest, +3 explores/settles while land remains, +3 gains insight), ties by option
  order. Real data: renewal 1, Mysticism +1.
- Revolution (148, 155): `revolt()` declares one at any time (`GameState.revolt_pending`); Anarchy falls at the next
  turn's start, before upkeep, so its first turn has an Anarchy upkeep. No action used. `revolt_error()`: game over or
  pending, "Without unrest there is no revolution.", "Anarchy already rules.", "A revolution is already under way.",
  "There is no government to overthrow.". `revolt_forecast()` is the counters it would bring. The Revolt button sits
  beside Relieve famine and Restore order whenever you may revolt; its tooltip says Anarchy starts next turn and lasts
  about N turns. The bot weighs a revolt by lookahead (159, below). Real data: Calls for Reform (2 turns, renewal +1),
  Peasant Uprising (+1 unrest), Radical Thinkers (era 2, 3 turns, renewal +2). Anarchy (an event, +1 action), 4 counters, era
  unrest 3, drain 20%, Feast is the `order` card.
- Anarchy's drain (156): config `unrest.drain_pct` (0–100, absent = 0). Each turn that starts under Anarchy (after any
  fall, before the draw) loses that share of stored food and wealth, rounded up (`Anarchy.drain`, logged as the Anarchy
  card's loss). `upkeep_forecast()` includes it on the stores after upkeep and feeding when Anarchy will rule next turn
  (a revolution pending, or 2+ counters left).
  The top bar shows "Unrest: 2 (+1)" with the limit in its tooltip (228), in the warning colour at the limit; its glyph
  breathes while `anarchy_ahead()` (the next upkeep brings unrest to the limit), held still with Reduce motion. Its
  stats use the `BarStat` variation (20 px) so the bar fits 1920 px. `ScriptedBot` skips a card that gains unrest when
  unrest + the forecast + 1 + the gain reaches the limit, and one that calms it while that sum is below the limit − 2.
  Real data: Settler +1 unrest; Famine ⟳ +1 per counter; Temple ⟳ −1; Shrine and Monument raise the limit by 1 and 2;
  Harvest Festival −1; Feast (supply action, 3 food: −2 unrest, tag `order`); events Grumbling (+1), Omen of Doom
  (+2) and Bandit Raids (⟳ +1, 2 turns), the only events that harm.
- Real data: Chiefdom (2 actions, unrest limit 8; no other bonus; the start), Kingship (3 actions, limit 10, ⟳ +1 wealth; from Code of Laws),
  Theocracy (3 actions, limit 13, ⟳ +1 VP; from Priesthood). Techs that give a government add it to the government deck (154); it has no supply pile.
- UI: one top-bar button names the civilization and the government ("Egypt · Chiefdom"), before Buy Cards and
  Knowledge (088, 115, 119); it opens a modal showing both (flavor, quote, rules), and a played government flies to it.

## Later
- Smarter bots for the simulator (greedy, then search); starvation and era-timing stats
- Save/load, undo (on `GameState.copy()`, 051)
- More eras, wonders, techs, automated rival
