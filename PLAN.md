# 4X Card Game — Prototype Plan

## Decisions
| Topic | Decision |
|---|---|
| Engine | Godot 4.x |
| Language | GDScript |
| Map | None: tableau of cards (cities, buildings, wonders) |
| Solo opposition | Event/barbarian deck that escalates by era |
| Card data | JSON files, loaded at runtime |
| Deck model | A fixed main deck, grown through the supply, the build menu and techs (see The deck model) |
| Balance simulation | Headless `GenericBot` over many seeds (`scripts/sim.sh`, 042, 313, 314): it values every legal action on a sample fork, with no rule per mechanic; three strategies as every civilization (generic, wide, tall); compared against `main` game by game (`--compare`, 293), not pinned in tests; the games run on the performance cores but one from one queue, one run at a time (152, 291), cached by code and data (292) |
| Win condition (demo) | Game ends after 100 turns (20 until 066); final score = sum of VP on tableau cards |
| Resources (demo) | Food, wealth and insight (139); unspent resources carry over with no cap. Food pays for people (upkeep, Settlers, growth cards: 262), insight for techs (Capital ⟳ +1, Library ⟳ +2; start with 0), wealth for buildings: non-food buildings cost wealth only, food producers 1 food + wealth; start with 2 food + 2 wealth (Capital, Caravan, Market make wealth; Market +1 per city, 077) (021, 022, 076, 077). Unrest (144) is only gained and lost, capped at the government's unrest limit (see Governments) |
| Actions (127) | Playing a card from hand uses 1 action; nothing else does (buying, learning a tech, choosing an explored territory, relieving a Famine, discarding). The ruling government's `actions` sets how many a turn has (Chiefdom 2, Kingship and Theocracy 3); unused ones are lost |
| Threat effects | Event deck (039): one event drawn per turn, active until it lasts out; harmful ops (072), the Famine (083), eras of events (074), revolutionary events (148), choice events (269) and era 2 and 3 events that escalate (270); barbarians are specced (160–168) |

## Architecture principle
The rules engine is plain GDScript (`RefCounted`/`Resource` classes, no scene nodes).
Scenes only display state and send player actions. The engine talks to the UI
through signals. This keeps rules testable and allows headless simulation
(`sim/`, run with `scripts/sim.sh`).

## Project layout (as built)
Each script opens with a `##` comment saying what it holds, so this lists folders and entry points only (330); the
suite checks every path named here exists.
- `data/`: the content. `data/cards.json` (card definitions) and `data/config.json` (resources, keywords, decks,
  supply, build menu, eras, population, unrest, starting state), validated on load.
- `engine/`: the rules, plain GDScript with no scene nodes.
  - `engine/game_engine.gd`: `GameEngine`, the public API: actions and their `*_error` queries, `fork()`,
    `sample_fork()` (311) and the constants. It extends `engine/engine_queries.gd` (read queries: score, targets,
    forecasts, …), which extends `engine/territory_queries.gd` (pop, slots, workers, tiers), which extends
    `engine/engine_core.gd` (state accessors, signals, the helpers effects call).
  - `engine/game_state.gd`: `GameState`, everything that changes during a game; `copy()` is a deep copy (051).
  - Rules modules: one class of static functions per subsystem (`TurnLoop`, `CardPlay`, `Population`, `Research`,
    `Supply`, `BuildMenu`, `Territories`, `Military`, `Anarchy`, `Events`, …), which `GameEngine` calls.
  - Loading: `engine/data_loader.gd` (`DataLoader.load_all`: JSON to `CardDef`s, every error and warning collected;
    `TYPE_FIELDS` and `INT_FIELDS` say which types take a field and an integer field's minimum and default, and
    `engine/card_type_fields.gd` reads each type's own fields, 338) and `engine/config_loader.gd` (config.json,
    normalized and checked against the cards, 095; `engine/population_config.gd` parses its population, tiers, unrest
    and the civilizations' homes, 339).
  - Cards: `engine/card_def.gd` (the immutable definition and its generated text), `engine/card_instance.gd` (a card
    in play), `engine/zone.gd` (an ordered pile).
  - Effects: `engine/effect.gd` (the base class), `engine/effect_registry.gd` (op name to script) and one
    `<op>_effect.gd` per op in `engine/effects/`.
- `autoload/`: the singletons. `autoload/game.gd` (`Game`: loads the data, owns the engine, reads
  `autoload/launch_options.gd`'s `--civ`, `--turns`, `--seed`) and `autoload/settings.gd` (`Settings`, saved through
  `autoload/settings_store.gd`).
- `ui/`: the display, one component per script, built in code. `ui/main.tscn` and `ui/main.gd` (`MainScreen`: the
  refresh, the actions it wires up, the test hooks); `ui/board_layout.gd` builds the board; `ui/board_views.gd` keeps
  the card views in line with the engine; the looks are `ui/palette.gd`, `ui/game_theme.gd`, `ui/tokens.gd` and `ui/surfaces.gd` (wood and paper, 341);
  modals extend `ui/modal.gd` on a `ui/modal_stack.gd`, screens go on `ui/navigator.gd`; sounds are `ui/sfx.gd`.
- `assets/`: icons (white SVGs tinted in code), sounds (placeholders, 186) and the walnut and paper textures
  (`assets/background/`, 341); `default_bus_layout.tres` holds the
  audio buses (184).
- `tests/`: `tests/run_tests.gd` (the runner), `tests/lib/test_case.gd` (assertions, fixtures, helpers), one
  `test_<area>.gd` per area and `tests/balance/` (see `docs/testing.md`).
- `sim/`: the balance simulator: `sim/generic_bot.gd` (`GenericBot`, 313, 314), `sim/sim_stats.gd` (`SimStats`),
  `sim/sim_compare.gd` (two checkouts game by game, 293) and `sim/run.gd` (the CLI).
- `scripts/`: `scripts/test.sh` (the tests), `scripts/test-hook.sh` (the Claude Code Stop hook), `scripts/sim.sh`
  (the simulator), `scripts/cpus.sh` (usable CPUs on Linux) and `scripts/cloud-setup.sh` (Godot for a cloud session).
- `docs/`: the development process, the testing guide, the design guide and the backlog.

Prices (173): an action checks a price ({resource: amount}) with `can_pay` / `price_error` and pays it with `pay`, all on
`EngineCore`; unrest is added or capped only through `set_unrest`, which stops at `unrest_limit()`.
Adding an effect: follow the `add-effect` skill. The engine API is documented by the `##` comments in
`engine/game_engine.gd`; the sections below give the rules and name the functions only where it helps.
Buildings always target a settled territory with a free slot (`free_slots`).
An effect that targets a card overrides `target_zone()` (and its two error messages); the engine then
derives `needs_target`, `valid_targets` and the target checks in `play_error` from it.
`would_need_target(uid)` / `would_target(uid)` (310) give the same answers for a card in any zone, as if it were in the
hand (false and `[]` for no card or after game over): a bot tells a card with nothing to act on from one with.

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
  target or opens a choice). Only `gain`, `gain_per_tag`, `gain_per_keyword`, `gain_per_pop`, `lose`, `lose_pct`, `lose_per_keyword`, `lose_pop`, `score` and
  `grow` may use
  `upkeep` (043): the forecast restores only resources, bonus score and pop, so other ops are a loader error there.
- `trade` (055, play only): `{ "op": "trade", "resource": "wealth", "per_root_city": 2, "pop_per": 5, "min_cities": 2 }`
  gains `per_root_city` × ⌊√cities⌋ + ⌊total pop / `pop_per`⌋; with fewer than `min_cities` city cards in the
  tableau the card can't be played (Caravan).
- `gain_per_keyword` (081): `{ "op": "gain_per_keyword", "resource": "food", "amount": 1, "keywords": ["forest"] }`
  gains `amount` (default 1) per settled territory (in the tableau) with any of `keywords`, printed or rolled; each
  territory counts once. `GameEngine.count_territories_with(keywords)` is the count (Hunt).
- `gain_per_pop` (304): `{ "op": "gain_per_pop", "resource": "wealth", "amount": 1, "per": 3 }` gains `amount` × ⌊pop on
  the card's own territory / `per`⌋ (both default 1): "+1 wealth per 3 pop here". It needs its own territory (a load error
  on techs, events, governments and units, as `grow` "here"), and gains 0 with no territory or population off.
- Harmful ops (072), on any card type: `{ "op": "lose", "resource": "food", "amount": 2 }` takes a resource, never
  below 0 ("−2 food"); `{ "op": "lose_pop", "amount": 1 }` takes pop one at a time from the territory with the most
  pop, ties first in tableau order, the same rule as starvation (`Population.most_pop`).
- Loss ops that scale (268): `{ "op": "lose_pct", "resource": "food", "pct": 25 }` takes `pct`% (1–100) of the stored
  resource, rounded up like Anarchy's drain ("−25% food"); `{ "op": "lose_per_keyword", "resource": "food", "amount": 1,
  "keywords": ["desert"] }` is `gain_per_keyword`'s mirror ("−1 food per desert territory"). Both go through `lose`, so
  they never go below 0 and report `lost`. No shipped card uses them yet (270).
- Standing modifiers (129): buildings, cities, techs, civilizations, governments and events may set `modifiers`, an
  object of `DataLoader.MODIFIER_KEYS` (`actions`, `hand_size`, `housing`, `unrest_limit`, `renewal`, `insight_per_gain`, `administers`) to non-zero ints, e.g.
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
  (Slash and Burn is its real card since 369: trash a card in hand, +1 food).
- `create` puts a new card in `tableau` (default), `hand`, `discard` or `deck` (`GameEngine.CREATE_ZONES`, 048);
  any other zone is a loader error. With `unique: true` (364) it adds nothing while the player owns a copy (one in
  `GameEngine.OWNED_ZONES`: deck, hand, discard, tableau; a trashed one doesn't count); its text ends "if you have none".
- `gain_per_tag` gains `amount` per card with `tag` in `zone` (default `tableau`); with `per` (367, default 1) it gains
  `amount` × ⌊tagged ÷ `per`⌋, text "+1 insight per 2 port".
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
- Wonders built over turns (286): a building may set `project: true` (its cost must be wealth only, ≥ 1: the total to
  pay in; text "Built over turns: up to 1 wealth per pop here each turn."). It plays for just the action
  (`play_cost` {}) as a site on its territory, taking a slot and a worker, with no play effect, upkeep, modifier,
  defence or VP until complete (`is_site`, `site_progress`, `site_cost` = the discounted wealth). `contribute(uid, n)`
  pays wealth in for no action, at most `contribute_limit(uid)`: the least of its territory's pop less what went in
  this turn (`CardInstance.given_this_turn`, reset at turn start), the wealth still owed and the wealth held; 0 while
  idle. Paying the last of it completes the site ("Completed X.") and resolves its play effects. `abandon(uid)` sends
  a site to the discard for no action, its progress lost. Rules in `engine/sites.gd` (`Sites`); the sim bot
  contributes or abandons when that values more (313). A site's details show
  "Being built: 4 / 12 wealth" and offer Contribute and Abandon… (confirmed by `AbandonModal`); its card shows its
  progress.
- Training (164): a building may set `training` (int ≥ 1). `unit_strength(uid)` is a unit's printed strength plus the
  `training` of the working buildings on its station (0 when idle), and defence sums it. A trained unit's face shows
  `unit_strength_tag(uid)` ("Strength 3") and its details explain the bonus.
- Building upgrades (300): a building may set `upgrade_of` (another building's id; never a project, and no cycles). It
  is a build-menu entry only (never in `deck` or `supply`, nor `create`d) and builds onto a base: `build("plough",
  farm_uid)` puts it on the base's territory (`CardInstance.base_uid`), taking no slot and no worker; `build_targets`
  lists the bases that could take it, and a base takes each different upgrade once. An upgrade can be a base
  (Shrine → Temple → Great Temple). It adds its effects, modifiers, housing, defence, training, famine guard and VP
  while its base works, and falls back (counts for nothing) while its base is idle or fallen back
  (`fallen_back_reason` "Its Farm is idle.", "Its Sanctum has fallen back."). `upgrade_base(uid)`, `upgrades_on(uid)`;
  rules in `engine/upgrades.gd` (`Upgrades`). Its text starts "Builds on a Farm."; unlocking it reads "… can now be
  built on a Farm."
- Rural upgrades (305): Ploughed Fields (The Plough) and Irrigation Canals (Irrigation) go on a Farm, Harbor (Sailing,
  coastal) on Fishing Huts, Timber Camp (Bronze Working) on a Hunters' Camp and Shaft Mine (Iron Working) on a Mine; they
  need a tech and no tier. Caravanserai is now Caravan Station (Animal Husbandry) and the Granary opens on turn 1.
  Content tests hold every upgrade to its base: both are build-menu entries, some territory meets both's `requires`,
  and the upgrade never opens in an earlier era.
- Fishing (364): Fishing Huts (coastal or marsh) cost 2 wealth and no food, give ⟳ +1 food and housing 1, and building one
  adds a Net Fishing to the deck if you have none (a unique `create`; an action: +1 food per coastal territory). Salt Pans (Pottery, coastal; ⟳ +1
  food) goes on Fishing Huts beside the Harbor (now ⟳ +1 food, +2 wealth), so the coast has an era-1 upgrade as the
  Farm does. A content test holds every card a building creates to an action.
- Sea trade (367): Sailing hands out a Sea Trade (1 food: +2 wealth per port card; no city minimum, unlike Caravan),
  opens its supply pile (price 2, 6 copies), and gives ⟳ +1 insight per 2 port cards.
- Urban upgrades (306): Temple (Mysticism, Village) goes on a Shrine, and Great Temple (Philosophy, Metropolis; ⟳ +1 VP,
  +1 food per 3 pop here) and House of Life (Medicine, Town) on a Temple; Writing opens the Scribal School (the old
  Library's numbers), and Library (Alphabet, Town; ⟳ +1 insight per 3 pop here) goes on it. The Shrine took the Temple's
  ⟳ +1 VP on a mountain. Content tests: every `tier` is one of `population.tiers` and never lower than its base's; no
  eureka counts only what its own tech (or a later one) opens; no upgrade lowers the unrest limit; a `gain_per_pop`
  upgrade has a tier.
- More urban upgrades (307), each needing a Town unless noted: Merchant Quarter (Credit) on a Market and Mint (Coinage,
  Metropolis) on it; Storehouse (Clay Tokens) on a Granary; City Walls (Masonry) on a Palisade; Multi-storey Houses
  (Engineering) on Courtyard Houses; Textile Works (Weaving) on a Weavers' Workshop; Dockyard (Navigation) on a Harbor.
  Merchant Quarter, Textile Works and Dockyard make ⟳ +1 wealth per 3 pop here. The Aqueduct needs a Town (housing 3).
  Content tests: only the listed pure-discount techs (Mathematics, Astronomy) open nothing; a stand-alone Metropolis
  building is a wonder or a `once` entry.
- Gap buildings (308): Palace (Code of Laws; Metropolis, `once`; 3 VP, +1 action each turn), Shipyard (Sailing, coastal),
  Terraced Fields (Masonry, hills or mountain: Mountains' food building), Reed Works (turn 1, marsh), Cistern
  (Engineering, hills or desert), Dye Works (Weaving, coastal) and Kiln (Pottery). Monument and Forge are no longer
  `once`. Content tests: every territory can hold a food building that isn't an upgrade; a `once` building that isn't a
  wonder needs a tier.
- Upgrades on screen (302): the territory view draws no card for an upgrade; its base's card carries a ribbon per
  upgrade (`upgrade_tree`, depth first: name and `upgrade_rules_text`), hatched with the ochre idle lamp and
  `fallen_back_reason` while it has fallen back, and a "+ Upgrade" chip while it or an upgrade on it could take
  another (`upgrades_for`), opening the Build modal on that row. The modal's Upgrades heading lists
  `upgrade_options(t)` ("Plough … on Farm"), previewed with `build_preview(id, base)`. An upgrade's face reads
  "Upgrade · Farm", its lines led by "Also", with a stamp naming its tier (`upgrade_base_name`, `card_tier_name`).
- Buildings that need a tier (301): a building or upgrade may set `tier` (a `population.tiers` id; ignored with a
  warning when tiers are off). It is built only on a territory at that tier or larger ("Forum needs a Town (Homeland is
  a Village)."), and while its territory is smaller it falls back: it keeps its slot and worker but counts for nothing,
  housing and printed VP included (`fallen_back_reason` "Needs a Town."), and works again by itself when the territory
  grows back. Unlike an idle building (which keeps its housing and VP), a fallen-back card counts for nothing; the
  rule is `engine/fallback.gd` (`Fallback`), derived from pop, never stored. The tier notice names the cards that fall
  back or work again ("Homeland shrinks to a Hamlet. Sanctum falls back."). Text: "Needs a Village."
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
- Buildings may list `requires` (keyword ids, any-of; on another type it is ignored with a warning, and on a unit it is
  an error, 338). Any effect may have a `keyword`; it then applies
  only when its card's territory has that keyword (text: "… (on Flood Plain)").

## The deck model
The main deck is fixed (`deck_model` is `fixed`, the only model the loader accepts). Nothing replaced the planned
deck-building and era-deck models with zones of their own: the deck grows instead through the supply (cards bought onto
the discard, 032), the build menu (buildings and units built straight onto a territory, 295) and techs (which unlock
piles and entries, 140); eras add techs and events to their own decks (027, 074).

## Turn loop (initial)
1. Upkeep: cities and buildings trigger `@upkeep` (produce food), then researched techs, the civilization and the government, then active events
   (which may end), then pop eats food (a shortfall brings or worsens a Famine; a fed upkeep ends it, 083).
2. Draw up to hand size (unplayed cards stay in hand); under Anarchy, renewal is owed.
3. Event (237: from turn 2): draw one event from the event deck and resolve its `play` effects (see Events). It is
   drawn last so it is active all turn: you see it in the Realm and play around it, and an event that lasts N turns
   is active for N play phases.
4. Play: play cards while actions (127) and resources allow, buy cards, play Research cards (id `research`) for insight, and learn techs in the tech tree (140). A hand card can be discarded for free at any time.
5. Cleanup: keep the hand, but over `hand_limit` (7) you must discard down to it before the turn ends; unspent food carries over. The final turn discards the hand. After the last turn (`turn_limit`, 100 in the real data), show final score.

Forecast (035, `upkeep_forecast` in `engine/engine_queries.gd`): returns what the next upkeep does to each resource on hand, food net of what
pop eats (may be negative), plus `starve` (pop the Famine would kill, after guards); `{}` on the last turn or after game over.
It runs the upkeep effects on a fork (`GameEngine.fork`, a new engine on `GameState.copy()`, 051), so the game itself
never changes. Upkeep effects are still limited to resources, bonus score and pop (`Effect.upkeep_ok`, 043). The top bar shows it as "Food: 2 (+1)" (and Wealth, Insight, and "Unrest: 2 (+1)", 144; its limit is in the tooltip, 228),
with the food stat in the warning color when pop would starve.
`turn_forecast()` (309, `TurnLoop.forecast`) is the whole next turn's start for bots: `{score, pop, starve, <resource>:
change}` after upkeep, feeding (food never below 0), era unlocks (their unrest), Anarchy's fall and drain and the raids
that strike (pillage or repel), not the draw, the renewal or the new event. `TurnLoop.start_turn` runs the same steps
(`_settle_in`), so the forecast can't drift from the real turn. The sim bot values positions with it (313).
`fork()` copies the game exactly, the rng and every deck's order included, so a lookahead on it knows the future.
`sample_fork(seed)` (311) is one possible future instead: a fork with a new `SeededRng` from seed that reshuffles
`HIDDEN_ZONES` (deck, event deck, territory deck: their cards known, not their order) and makes its later draws.

Pending decisions (050, `pending()`): an explore choice, a hand-limit discard, a renewal (147), the government
choice (154) or a choice event's options (269). It is one dictionary in the state, `GameState.pending` (172), and `pending()` returns a copy with the
options a discard, renewal or government choice has now. While one is owed, every action is refused with the same
message (`_blocked_error`), except the decision's own action, and a discard still lets you discard, browse the supply
and learn techs. A decision's own action checks the game being over, then another decision owed, then its own
"nothing owed" message (`_owed_error`). A new kind follows the `add-decision` skill.

## Territories (Milestone 2 — built)
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
- **Cost per territory** (320): any card may set `cost_per_territory` ({resource: int ≥ 1}, never unrest, not on a
  project), added to its cost once per settled territory before the civilization's discounts (`Discounts.cost`, so
  `play_cost`, `supply_play_cost`, `build_cost`, `play_error` and the bot all see it). Text "Costs 1 more food for each
  territory you hold.". Real data: Settler 5 food + 1 per territory (6 for the 2nd settlement, 16 for the 12th); every
  card that settles sets it (content test). With 319's admin unrest it makes the soft cap on going wide.
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

## Population (Milestone 3 — built)
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
  relieves when that values more (313).
- Growth cards: the `grow` op (`{ "op": "grow", "amount": 1, "where": "here" | "each" | "best", "count": 3 }`) adds
  pop for free, capped by housing: `here` on the card's own territory (the Granary until 060, upkeep), `each` on every
  settled territory (Harvest Festival until 069, now an event), or with `count` on at most that many, smallest pop
  first among those with room (ties: tableau order; 261). `best` adds it all to one territory: one with idle buildings
  first, else one a pop short of its next settlement tier (283), else the smallest with room (`Population.best_to_grow`,
  261). `here` is a load error on a tech or an event,
  which has no territory (069); `count` only goes with `each`. A card whose play effects are all `each`/`best` grows
  can't be played when it would add no pop: during a Famine, or with every territory at its housing (276).
- Workers: a building needs a free worker (pop − buildings on its territory > 0) as well as a free slot. Without one
  the refusal is "No free worker." and `play_error_detail` / `build_error_detail` explain it for a tooltip (347).
  If pop drops below the building count, the buildings placed last are idle: they skip upkeep (decided
  before pop eats) but keep their printed VP. Cities never use a worker.
- Settlement tiers (281): optional `population.tiers` (`[{ "id", "name", "pop", "slots" }]`, the first at pop 0, pop
  rising strictly, slots never falling; real data Hamlet 0 / Village 4 / Town 8 / Metropolis 13, adding 0 / 1 / 2 / 3
  slots). A settled territory's tier is the last whose `pop` it has reached, derived from pop and never stored
  (`tier(uid)`, `tier_name(uid)`, `next_tier_pop(uid)`, `tier_line(uid)`). Its `slots` add to the territory's and its cities'. A
  building past its territory's slots (placed last first) is idle, as one past its pop is. Reaching or losing a tier
  is a notice ("Grassland grows into a Village."); the territory tooltip, and the territory view beside its
  pop meter (346), name the tier and the next one's pop ("Village: a Town at 8 pop").
- Sea slots (366): optional config `sea_slots` (`{ "keyword", "tag", "slots" }`, parsed in `PopulationConfig`; real data
  coastal / port / 1) gives every settled territory with the keyword that many extra slots that only a building with
  the tag may fill (`sea_slots(uid)`, `free_sea_slots(uid)`; `total_slots` and `free_slots` stay the regular ones).
  Buildings fill slots in the order placed (`Territories.slot_use`): a tagged one takes a free sea slot first, else a
  regular one; one with neither is idle. Another building on a territory whose only free slot is a sea slot is refused
  "Its sea slot takes only port buildings." The tooltip adds "Sea slot: 1 free of 1 (port buildings only)", the live
  line "⚓ S" after "▢ F", the view an outline per free sea slot, and the Build preview a "Free sea slots" line.
- Size unrest (282): a government's optional `tolerates` (a tier id from `population.tiers`; text "Tolerates up to
  Village."; ignored with a warning when tiers are off) is the largest tier it keeps calm. Each upkeep starts by adding
  `size_unrest()`: +1 unrest per tier each settled territory is above it, through `set_unrest` (so the limit stops it),
  before any card's upkeep and so before upkeep takes pop. 0 with unrest or tiers off, no government (Anarchy) or no
  `tolerates`. The forecast counts it.
- Admin unrest (319): a government's optional `administers` (int ≥ 1; text "Administers up to 7 territories.") plus
  the `administers` modifier ("Administration cap +2") is `admin_cap()`, never below 0; -1 (no cap) with no
  government (Anarchy) or one that sets none. `admin_unrest()` is n × (n + 1) ÷ 2 for n settled territories past the
  cap (the k-th past it adds k: 1, 3, 6, 10 in all), 0 with unrest off or no cap. Each upkeep adds it right after size
  unrest, through `set_unrest` (so the limit stops it), before any card's upkeep; the forecast counts it. Real data:
  Chiefdom 4, Kingship 7, Theocracy 6; Code of Laws +1, Bureaucracy +2, Royal Road +1. Only unique cards (techs,
  governments, civilizations, wonders) carry the modifier, so copies can't stack it (content test).
- Score = printed VP + effect VP + total pop × `vp_per_pop`.
- Growth (262): pop grows only from growth cards, never by itself (260's automatic growth from a food surplus is
  gone, and 010's bought Grow with it). Bread and Beer (action, 2 food: +1 pop where it's needed most; 1 in the
  starting deck, 8 in the supply at 2) and Land Grants (action, 5 food: +1 pop on each of your 3 smallest territories
  with room; 4 in the supply at 3). Growth competes for actions and food. In the territory view pop is a meter of pips,
  one per housing (124).
- Code: pop, housing, growth and workers in `engine/population.gd`; the `grow` op in `engine/effects/grow_effect.gd`.

## Techs (Milestone 4 — built)
Techs never enter the main deck. Backlog: 025 (research deck; built; reveal-2 replaced by 140), 026 (passes and the
prerequisite discount; built, removed by 140), 139 (Insight pays for techs; built), 140 (open tech tree; built), 027 (eras, `add_era`, Library; built), 028 (first content; built: 13 techs in eras 1–2, Library via Writing; Pasture, Harbor, Monument,
Pyramids and Forge left the deck and come back through techs), 034 (Research is a card; built), 058 (Stone Age → Bronze
Age tree; built: 7 era-1 techs, Bronze Working adds era 2, 6 era-2 techs), 141–142 (eurekas, diffusion; built), 143
(Iron Age: 6 era-3 techs in the deck, opened by Writing; eurekas on every tech; pacing; built).
- Gating (058): a tech that gives a card creates 1 free copy in the discard and unlocks that card's locked supply pile
  (057), so more copies can be bought. Wonders (tag `wonder`) are created only, one copy each, are projects built over
  turns (286: Oracle and Walls 30 wealth, Pyramids 40, Great Ziggurat 42, Tyre and Royal Road 45, Hanging Gardens and
  Great Library 48), and also carry `culture` (265): era 1 Oracle of Delphi
  (Mysticism, ⟳ +2 insight) and Walls of Uruk (Masonry, defence 4, unrest limit +1); era 2 Pyramids (Priesthood),
  Great Ziggurat (Code of Laws, ⟳ −1 unrest, limit +2), Hanging Gardens (Calendar, fresh water, every territory houses
  1 more), Great Library (Writing, ⟳ +3 insight), Great Harbor of Tyre (Sailing, coastal, ⟳ +1 wealth per coastal
  territory); era 3 Royal Road (Bureaucracy, hand size +1; 273) and Lighthouse of Pharos (Navigation, coastal, port;
  ⟳ +1 wealth per port card; 365). The
  starting deck is the basics (132, config `deck`): Settler 1, Scout 1, Research 1, Barter 2 (2 food → 2 wealth, +1
  action), Storyteller 1 (1 food: draw 2), Bread and Beer 1 (grow 1), plus five cheap actions dealt only, one each (369): Runner (draw 1, +1 action, +1 food),
  Tribute (+1 wealth per city), Assembly of Elders (`order`: −1 unrest, +1 insight; playable in Anarchy), Slash and
  Burn (trash a card in hand, +1 food) and Corvée (+3 wealth, +1 unrest). Early buildings (080) are in the build menu from
  turn 1 (295), never dealt: Farm, Hunters' Camp (forest; adds the one Hunt, +1 food per forest territory; 368), Fishing Huts (coastal or marsh, ⟳ +1 food, housing 1, adds the one Net Fishing; 364) and Shrine (anywhere, 1 VP,
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
  unlocks, `uid` −1 for a future tech, `affordable` whether it is available and the insight covers its cost now (325).
  Optional config
  `era_names` (`{"1": "Stone Age"}`) feeds `era_name(n)`, default "Era n".
- UI: a Knowledge button (T) in the top bar (the current era's name in its tooltip; hidden when the config has no
  research deck) opens the Knowledge screen (208), drawn as a drafting sheet (222): "Insight N · play a Research card
  for more", then one band per era with its title block at the left and its techs as index-card tiles of one size.
  A tile shows the tech's name and a marker (✓ researched, its cost now, "needs Mining" while locked; an available tile the insight
  doesn't cover has muted text, 325) and "✔ Eureka"
  when met, and is filled by state (teal researched, well locked); its tooltip has the state in words, why it can't
  be learned (`buy_tech_error`), what it gives and its eureka. A click, Enter, a right click or I opens the
  details, whose Learn button researches a tech not yet learned (disabled with `buy_tech_error`, 229). An era not reached lies under a vellum printed "<ERA> · OPENS AT 8
  POP OR 15 WEALTH". Researched techs show only in the tech tree (137).

## Supply (backlog 032)
Players can spend wealth to add more copies of existing cards to their deck. No new cards: some of the
starting deck moved into the supply (Scout, Settler, Temple, Granary); 034 adds Research (price 3, 2 copies). Since 058
the building piles (Granary, Pasture, Mine, Temple, Caravan, Monument, Forge, Library, Market, Harbor) start locked.
264 adds locked piles for Stone Circle (Mysticism, ⟳ +1 insight), Courtyard Houses (Pottery, housing 2), Caravanserai
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
- Build menu (295): buildings aren't dealt or bought in the real data. Config `build_menu: { "farm": {}, "granary":
  { "locked": true }, "pyramids": { "locked": true, "once": true } }` (buildings and units only, never also in
  `supply`; default {}) lists them in menu order. `build(card_id, territory_uid := -1)` puts a new copy of an unlocked
  entry on a settled territory for an action and its cost after discounts, as playing it there would (its play
  effects, `card_played`; Anarchy's play rule); `build_error` says why not, `build_menu()` lists the unlocked entries,
  `build_targets(card_id)` the territories it fits now. An `unlock` naming an entry opens it ("X can now be built.");
  a `once` entry (the wonders, Monument, Forge) is built once a game. State: `GameState.locked_builds`, `built_once`.
  Techs unlock their buildings instead of creating a copy. A building card in a deck or the supply still plays (the
  rules fixtures use it).
- Units in the build menu (296): a unit entry is recruited the same way (`build`), homed and stationed on a territory
  with a free worker (no slot, no terrain); "X can now be recruited." A recruited unit that is disbanded or lost to a
  pillage leaves play (no zone), to be recruited again; a unit with no entry (dealt from a deck) still goes to the
  discard. Warriors is an open entry from turn 1.
- `build_preview(card_id, territory_uid)` (299): `{cost, lines}`, each line `[key, before, after]` for what building
  there would change (each resource's `upkeep_forecast`, then `free_slots`, `free_workers`, `defense`, `housing`,
  `actions_left`), from a build on a fork; `{}` when `build_error` refuses. The Build modal (297) shows it.
- UI (297): a territory's view has Build… (B) beside Rename…, and each free slot outline is a "+ Build" key; both open
  the Build modal (`ui/build_modal.gd`, "Build on <territory>"): a selectable list of the build menu under Buildings and
  Units (name and `build_cost`; a refused row dimmed with `build_error`'s reason), and a sheet with the selected
  entry's card, its flavor (354, from `def_details`; none for a unit), then "If built on <territory>" and
  `build_preview`'s lines, or the refusal; Build X / Recruit X (Enter) builds.
  Build… and the slots are disabled with `build_menu_error()` while nothing can be built and hidden with an empty menu.
  A recruited unit's Disband reads "Dismiss it" (`disbands_to_discard`).
- The build ceremony (357, guide §10.8): `build` emits `built(uid)` before `changed`. The new card rests in its slot at
  once under a `BuildCeremony` (`ui/build_ceremony.gd`, on the fx layer): a lamp ring and 12 rays in its plane colour,
  then a BUILT / RECRUITED tag; an upgrade's ring and rays play on its base, no tag. `EventSounds` plays
  `ui.milestone.build` (`.recruit` for a unit) with it, below every other event.
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
  shuffling `event_discard` back in when the deck is empty or holds only raids that can't be drawn yet (266; nothing
  when both are empty), makes it active with
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
  goes to `event_discard` and `raid_resolved(outcome)` reports `{uid, id, target, strength, defense, repelled, units_lost,
  pop_lost, gained, lost, vp}`; `raid_outcome_text(outcome)` is its result line, logged (not a notice) and shown in
  the raid modal with `ui.milestone.pillaged` or `ui.milestone.repelled` (271). A raid drawn on the final turn or the one before never strikes.
  Pacing (257): a raid is drawn only while raids are allowed: `realm_size()` (config `territory_value` per settled
  territory plus the total cost of every city, building and unit in the tableau) is at least `raid_min_size`, no raid
  is active, and `raid_gap` turns have passed since the last strike (`GameState.last_raid_turn`; no gap before the
  first). Otherwise it goes to the event deck's bottom and the next event is drawn; with only such raids left, no
  event that turn. Shipped: `territory_value` 3, `raid_min_size` 12, `raid_gap` 4.
- Choice events (269, `EventChoices`): an event (not a raid) may set `choices`, 2–3 options `{cost?: {resource: n ≥ 1},
  effects}`, at least one free; option effects have no `trigger` and follow an event's own rules (no target, no
  choice). When drawn, after its own play effects, `pending()` is `{kind: PENDING_EVENT_CHOICE, uid, options: [0, …]}`
  and every other action says "Choose how to answer <event> first."; drawn while another decision is owed (a renewal),
  it waits (`CardInstance.choice_waiting`) and is owed once that is paid. `choose_option(i)` / `choose_option_error(i)`
  pay the cost and resolve the effects once, emitting `option_chosen` (`{uid, id, index, gained, lost, vp, …}`, the
  cost in `lost`). Card text: "Choose: pay 2 wealth for +1 VP; or +1 unrest."; `option_text(uid, i)`: "Pay 2 wealth:
  +1 VP". An option without effects reads "pay 4 wealth" / "Pay 4 wealth", or "nothing" / "Nothing" when free (270). The event modal shows the options as buttons in place of OK (a refused one disabled, its reason the tooltip)
  and can't be dismissed; a waiting choice event's modal opens once its choice is owed; choosing shows a notice. The
  sim bot answers with the option whose sample fork values most (313). Shipped: Envoys from the Hills (era 1). `raid_forecast()` lists the announced
  raids with their target's current defence; the UI reads `raid_line`, `raid_tag`, `raid_short` and `raid_warning`.
  Shipped era 1: Raiders (2, grassland/desert), Sea Raiders (3, coastal), Hill Tribes (3, hills/mountain). Rules in
  `Military`.
- Code: `engine/events.gd`, `engine/event_choices.gd` (269).
- Era 2 and 3 events (270): each era the research deck reaches has events; from era 2 each era has a harmful and a
  helpful one and one that scales with the realm, and the most unrest an event adds never falls from one era to the
  next (`test_content`). Era 1 events still harm only by unrest. Shipped era 2 (with Omen of Doom, Bandit Raids, Radical
  Thinkers): Plague (−1 pop, +1 unrest), Granary Fire (−25% food), Drought (2 turns, ⟳ −1 food per desert or grassland
  territory), Silt Flood (+2 food per flood plain), Bumper Harvest (2 turns, ⟳ +1 food per farm), Busy Harbours
  (2 turns, ⟳ +1 wealth per coastal territory), Visiting Scholar (+3 insight), Labour Shortage (−1 action), Tax Revolt
  (pay 4 wealth, or +2 unrest), Wandering Smiths (pay 3 wealth for +3 insight, or nothing). Era 3: Pestilence (−2 pop,
  +1 unrest), Library Burns (−50% insight), Debased Coin (−30% wealth), Storm at Sea (−2 wealth per coastal
  territory), Golden Age (3 turns, +1 action, +1 hand size), School of Philosophers (+5 insight), Succession Crisis
  (pay 6 wealth, or +3 unrest, or −1 pop and +1 unrest), Mercenaries' Offer (pay 4 wealth for a Warriors in the
  discard, or nothing).
- Coastal events (365): era 1 Tuna Run (2 turns, ⟳ +1 food per coastal territory), Beached Whale (+2 food per coastal
  territory) and Shipwreck Salvage (+2 wealth per coastal territory), so the coast is not only raided and wrecked.
  `test_content`: a feature keyword (not a terrain) that events punish, by `lose_per_keyword` or a raid's targets, is
  one some event rewards; no era-1 event takes per keyword.
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
  "Wonders cost 3 less wealth." Real data: Babylon techs −1 insight, Phoenicia supply −1 wealth, Egypt wonders −10
  wealth (−3 until 286 made wonders 3× dearer). Hand cards show their cost after discounts; card details show the printed cost.
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
  A government (205), a tech and an event (215), an action (351) and a building (352) may set `flavor` too, and a
  government or a tech a `quote` (an event, action or building may not); every real tech and government has both
  and every real event, action and building a flavor line. The text follows the style guide's §18 voice (353): present
  tense, ~120 characters a line (the suite caps it at 150, civilizations 200). Flavor and quotes show only in the details
  (and a building's flavor under its card in the Build modal, 354), never on a card face.
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
  that order with the card focus on the default (Left/Right move it, Enter chooses), a click chooses; the civilization modal shows the deck as a row of tabs under its two cards (231). The sim bot chooses by rollout (314).
- Generic bot (313, `sim/generic_bot.gd`, strategy `generic`): no rule for any mechanic. Each step it tries every
  entry of `legal_actions()` but `end_turn` and `revolt` (an owed decision's options when one is owed) on a
  `sample_fork`, values the fork and does the best, stopping when nothing beats doing nothing. Value: score + turns ahead
  × `turn_forecast` score + food, wealth and insight weighed as stock plus forecast change over the turns ahead, with
  diminishing returns + the deck's worth (each card's value measured by playing a copy on a fork; 0 for a card that
  `would_target` nothing) + learned techs' printed cost − 0.5 per unrest the forecast brings in over the turns ahead
  (calming counts only the unrest there is to calm; 321) − a squared penalty as unrest nears its limit. A draw or +1 action within 0.5 of doing nothing gets one more step of lookahead; buys are cut to the 3
  best by card value per price. The sim's only bot since 314, which removed `ScriptedBot`.
- Forecast cache (315): `value()` looks each position's `turn_forecast` up in its `Context` by `forecast_key` (the
  `KEY_STATE_FIELDS` and, for each card in the engine's `forecast_zones()`, the `KEY_CARD_FIELDS`; 336: the board, the
  always-on zones and any zone an effect's `reads_zones()` names, and every other `GameState`/`CardInstance` field is
  listed with why it isn't read, which the suite checks), keyed by turn and dropping turns already past; a turn's rollouts
  share it, so a position forecast once isn't forecast again (about half of all lookups) and the games played are the
  same. `forecast_cache` turns it off; `check_forecasts` compares every
  hit with a fresh forecast and counts mismatches (`forecast_lookups`, `forecasts_computed`, `forecast_checks`,
  `forecast_mismatches`, reset by `play()`).
- Bot rollouts (314, porting 159): `GenericBot.rollout(engine, strategy, government_id, revolt)` plays a sample fork
  `ROLLOUT_TURNS` (12) turns on in cheap mode (no card values, no extra lookahead step) and returns its value; the real
  game is untouched, and every rollout of a turn shares one seed. When the government choice is owed the bot chooses the
  option whose rollout values most (ties: deck order; one option: no rollout). Every `REVOLT_EVERY` (4) turns, at the
  end of the turn and not in the last 6, it revolts when a rollout that revolts to some government in the deck values
  more than staying. Inside a rollout it never revolts and chooses the government the rollout was opened for, else
  the best by value. Strategies: generic, wide (+20 value per settled territory up to `admin_cap()`, 321) and tall (never plays a `settle` card
  past 2 territories). `GenericBot.lookahead_turns` counts the rollout turns (the sim's `lookahead_turns`).
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
  famine below the Realm. The sim bot restores order when that values more (313).
- Renewal (147): with config `unrest.renewal` (int ≥ 0; absent = renewal off), each turn that starts under Anarchy
  owes, after the draw, `pending()` `{kind: PENDING_RENEWAL, count, options}`: count = renewal + (Anarchy's turn − 1)
  + the `renewal` modifier ("Renewal trashes 1 more card"), capped at the options: the hand's, deck's and discard's
  cards but governments, by name then uid (255). `renew(uids)` / `renew_error(uids)` pay it at once, exactly count
  distinct options, each trashed from wherever it is (−1 unrest each; the deck keeps its order); refusals: "Trash a
  card from your hand, deck or discard (not a government).", "Each card can be trashed once.", "Choose 2 cards to
  trash.". Until paid every other action is refused ("Anarchy: trash 2 cards from your hand, deck or discard
  first."). The Renewal modal (`RenewalModal`, not dismissable) lists the options as a ledger: hover or Up/Down shows
  a row's card, a click or Enter chooses it (its lamp lights, `ui.toggle.on`; again, `ui.toggle.off`; past the count
  `ui.reject.locked`), and "Trash N cards" unlocks at the count. The sim bot trashes the combination whose fork values
  most (313). Real data: renewal 1, Mysticism +1.
- Revolution (148, 155): `revolt()` declares one at any time (`GameState.revolt_pending`); Anarchy falls at the next
  turn's start, before upkeep, so its first turn has an Anarchy upkeep. No action used. `revolt_error()`: game over or
  pending, "Without unrest there is no revolution.", "Anarchy already rules.", "A revolution is already under way.",
  "There is no government to overthrow.". `revolt_forecast()` is the counters it would bring. The Revolt button sits
  beside Relieve famine and Restore order whenever you may revolt; its tooltip says Anarchy starts next turn and lasts
  about N turns. The sim bot weighs a revolt by rollout (314, below). Real data: Calls for Reform (2 turns, renewal +1),
  Peasant Uprising (+1 unrest), Radical Thinkers (era 2, 3 turns, renewal +2). Anarchy (an event, +1 action), 4 counters, era
  unrest 3, drain 20%, Feast is the `order` card.
- Anarchy's drain (156): config `unrest.drain_pct` (0–100, absent = 0). Each turn that starts under Anarchy (after any
  fall, before the draw) loses that share of stored food and wealth, rounded up (`Anarchy.drain`, logged as the Anarchy
  card's loss). `upkeep_forecast()` includes it on the stores after upkeep and feeding when Anarchy will rule next turn
  (a revolution pending, or 2+ counters left).
  The top bar shows "Unrest: 2 (+1)" with the limit in its tooltip (228), in the warning colour at the limit; its glyph
  breathes while `anarchy_ahead()` (the next upkeep brings unrest to the limit), held still with Reduce motion. Its
  stats use the `BarStat` variation (20 px) so the bar fits 1920 px. The sim bot plays around the limit through
  its value's unrest risk (313).
  Real data: Settler +1 unrest; Famine ⟳ +1 per counter; Temple ⟳ −1; Shrine and Monument raise the limit by 1 and 2;
  Harvest Festival −1; Feast (supply action, 3 food: −2 unrest, tag `order`); events Grumbling (+1), Peasant Uprising
  (+1), Envoys from the Hills (or +1), in era 2 Omen of Doom (+2), Bandit Raids (⟳ +1, 2 turns), Plague (+1) and Tax
  Revolt (or +2), and in era 3 Pestilence (+1) and Succession Crisis (or +3); era 2 and 3 events also harm otherwise (270).
  No era-1 event adds more than 1 unrest in all (267: play gains, upkeep gains × turns, a raid's larger of pillage and
  repel, a choice event's option that adds most, 269).
- Real data: Chiefdom (2 actions, unrest limit 8; no other bonus; the start), Kingship (3 actions, limit 10, ⟳ +1 wealth; from Code of Laws),
  Theocracy (3 actions, limit 13, ⟳ +1 VP; from Priesthood). Techs that give a government add it to the government deck (154); it has no supply pile.
- UI: one top-bar button names the civilization and the government ("Egypt · Chiefdom"), before Buy Cards and
  Knowledge (088, 115, 119); it opens a modal showing both (flavor, quote, rules), and a played government flies to it.

## Later
- Smarter bots for the simulator (greedy, then search); starvation and era-timing stats
- Save/load, undo (on `GameState.copy()`, 051)
- More eras, wonders, techs, automated rival
