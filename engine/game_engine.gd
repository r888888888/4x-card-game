class_name GameEngine
extends EngineQueries
## Game rules and player actions. Uses no scene nodes: the UI (or a headless
## script) calls the action methods and listens to the signals.
##
## Turn loop: upkeep -> draw -> play (player) -> event -> cleanup.
##
## The state, its accessors, the signals and the helpers effects call (gain, draw, create_card, …) live in
## EngineCore (engine/engine_core.gd, 125), and the read queries in EngineQueries (engine/engine_queries.gd, 249),
## which this extends. The rules live in modules of static functions that the methods here
## call: TurnLoop, CardPlay, Population, Research, Supply and Territories, and Events. The modules may call the
## engine's _ helpers (_log, _resolve, _make_card from EngineCore; _blocked_error here).

const ZONES: Array[String] = ["deck", "hand", "discard", "tableau", "territory_deck", "frontier", "reveal", "research_deck", "researched", "future_techs", "event_deck", "future_events", "active_events", "event_discard", "civilization", "government", "governments", "removed", "trashed"]
## Zones of always-on permanents outside the tableau: every card there resolves upkeep and scores its printed VP.
const ALWAYS_ON_ZONES: Array[String] = ["researched", "civilization", "government"]
## The zones a create effect may put a new card into.
const CREATE_ZONES: Array[String] = ["tableau", "hand", "discard", "deck"]
## The kinds of decision pending() can report.
const MAX_TERRITORY_NAME := 24  # characters in a territory's name (248)
const PENDING_EXPLORE := "explore"
const PENDING_DISCARD := "discard"
const PENDING_RENEWAL := "renewal"  # Anarchy asks you to trash cards from the discard (147)
const PENDING_GOVERNMENT := "government"  # Anarchy has ended: choose a government from the government deck (154)
## A tech's state in tech_tree(): bought, learnable now, in the research deck but waiting for its prereq (140), or
## in an era not added yet.
const TECH_RESEARCHED := "researched"
const TECH_AVAILABLE := "available"
const TECH_LOCKED := "locked"
const TECH_FUTURE := "future"
## The actions still allowed while a discard is owed (see _blocked_error).
const _DISCARD_ALLOWS: Array[String] = ["discard", "supply", "research"]

## A new engine on a deep copy of this one's state (GameState.copy). Nothing is connected to its signals and
## it logs to its own copy of the log, so playing on it never touches this game.
func fork() -> GameEngine:
	var f := GameEngine.new(card_db, config)
	f.state = state.copy()
	return f


# --- Actions ---

## Starts a new game with seed p_seed as civilization civ_id ("" for the config's starting.civilization, if any).
## Refuses and changes nothing when new_game_error(civ_id) isn't "".
func new_game(p_seed: int, civ_id := "") -> void:
	if new_game_error(civ_id) != "":
		return
	TurnLoop.new_game(self, p_seed, civ_id if civ_id != "" else config.starting.get("civilization", ""))


## Why new_game can't start as civilization civ_id, or "" if it can (a listed civilization, or "" for the
## config's starting one).
func new_game_error(civ_id: String) -> String:
	if civ_id != "" and not civilizations().has(civ_id):
		return "Unknown civilization '%s'." % civ_id
	return ""


## The civilizations a game may start as (config civilizations), in order.
func civilizations() -> Array[String]:
	return config.get("civilizations", [] as Array[String]).duplicate()


## Why the card can't be played right now, or "" if it can.
func play_error(uid: int, target_uid := -1) -> String:
	return CardPlay.error(self, uid, target_uid)


## Pays the cost, moves the card (permanents to the tableau), resolves its "play" effects on
## target_uid, then emits card_played with what happened. A card that needs a target and has only
## one valid target uses it when target_uid is -1; a card that needs none ignores target_uid.
func play_card(uid: int, target_uid := -1) -> bool:
	return CardPlay.play(self, uid, target_uid)


## Why choose(uid) would refuse: no explore choice is open, or uid isn't one of its options. "" if it can.
func choose_error(uid: int) -> String:
	return Territories.choose_error(self, uid)


## Resolves the pending choice: keeps territory uid in the frontier and puts the other revealed
## territories at the bottom of the territory deck. False (and no change) if choose_error says no.
func choose(uid: int) -> bool:
	return Territories.choose(self, uid)


## Why tech uid can't be learned right now, or "" if it can: the game is over or a choice is pending, it isn't in the
## research deck, its prereq isn't researched, or the insight is short.
func buy_tech_error(uid: int) -> String:
	return Research.buy_error(self, uid)


## Learns tech uid from the research deck (140): pays its tech_cost in insight, moves it to the researched row and
## resolves its play effects; no card or action. Once the research deck is empty the lowest waiting era's techs
## arrive. False (and no change) if buy_tech_error says no.
func buy_tech(uid: int) -> bool:
	return Research.buy(self, uid)


## Why a copy of card_id can't be bought from the supply right now, or "" if it can.
func buy_error(card_id: String) -> String:
	return Supply.buy_error(self, card_id)


## Pays buy_price wealth for a new copy of card_id from the supply and puts it on the discard.
## False (and no change) if buy_error says it can't.
func buy(card_id: String) -> bool:
	return Supply.buy(self, card_id)


## Why discard_card(uid) would refuse: the game is over, a choice is pending, or uid isn't in the hand. "" if it
## can, including while an end-of-turn discard is owed.
func discard_error(uid: int) -> String:
	return TurnLoop.discard_error(self, uid)


## Discards one card from the hand for free, any time in the turn. If an end-of-turn discard is
## pending this counts toward it, and the turn ends once the hand is down to the limit. False (and no
## change) if discard_error says no.
func discard_card(uid: int) -> bool:
	return TurnLoop.discard_card(self, uid)


## Why the turn can't end right now, or "" if it can.
func end_turn_error() -> String:
	return _blocked_error("end_turn")


## Ends the turn. Over the hand limit, waits for discard_card calls instead (not on the last turn).
## Does nothing if end_turn_error says no.
func end_turn() -> void:
	TurnLoop.end_turn(self)


## Why settled territory territory_uid can't grow right now, or "" if it can.
func grow_error(territory_uid: int) -> String:
	return Population.grow_error(self, territory_uid)


## Pays grow_cost food for +1 pop on settled territory territory_uid. False (and no change) if
## grow_error says it can't.
func grow(territory_uid: int) -> bool:
	return Population.grow(self, territory_uid)


## Why relieve_famine would refuse: game over or a pending decision, no active Famine, no relief price in the config,
## or not enough to pay it. "" if it can.
func relieve_famine_error() -> String:
	return Famine.relieve_error(self)


## Pays the config's population.famine.relief and the active Famine leaves the game at once (084). False (and no
## change) if relieve_famine_error says no.
func relieve_famine() -> bool:
	return Famine.relieve(self)


## Why revolt would refuse (148, 155): game over or a pending decision, Anarchy already ruling, a revolution already
## declared, or no government ruling. "" if it can.
func revolt_error() -> String:
	return Anarchy.revolt_error(self)


## Declares a revolution (155): Anarchy falls at the next turn's start, before upkeep. Uses no action. False (and no
## change) if revolt_error says no.
func revolt() -> bool:
	return Anarchy.revolt(self)


## Why rename_territory would refuse (248): game over or a pending decision, not a settled territory, or a name blank
## or longer than MAX_TERRITORY_NAME once trimmed. "" if it can.
func rename_territory_error(territory_uid: int, name: String) -> String:
	return Territories.rename_error(self, territory_uid, name)


## Renames settled territory territory_uid to name, trimmed. Uses no action. False (and no change) if
## rename_territory_error says no.
func rename_territory(territory_uid: int, name: String) -> bool:
	return Territories.rename(self, territory_uid, name)


## The lines that describe the Anarchy a revolution now would bring, with this game's numbers (205); [] when
## revolt_error says no.
func revolt_summary() -> Array[String]:
	return Anarchy.revolt_summary(self)


## Why renew(uid) would refuse (147): renewal isn't pending, or uid isn't a discard card other than a government. ""
## if it can.
func renew_error(uid: int) -> String:
	return Anarchy.renew_error(self, uid)


## Trashes discard card uid for Anarchy's renewal: it leaves the game and unrest drops by 1 (147). False (and no
## change) if renew_error says no.
func renew(uid: int) -> bool:
	return Anarchy.renew(self, uid)


## Why restore_order would refuse: game over or a pending decision, no Anarchy, its first turn, or not enough wealth.
## "" if it can.
func restore_order_error() -> String:
	return Anarchy.restore_error(self)


## Pays order_relief() and Anarchy ends: a government is to be chosen at once (146, 154, 155). False (and no change) if
## restore_order_error says no.
func restore_order() -> bool:
	return Anarchy.restore(self)


## The government choice's default (254): the uid of the config's starting government when it's in the government
## deck, else the deck's first; -1 when no government choice is owed. pending() lists it first.
func default_government() -> int:
	return Anarchy.default_government(self)


## Why choose_government(uid) would refuse (154): no choice is owed, or uid isn't in the government deck. "" if it can.
func choose_government_error(uid: int) -> String:
	return Anarchy.choose_government_error(self, uid)


## Government uid leaves the government deck and rules, its play effects resolving (its cost unpaid), and unrest
## drops to at most half its limit (154). Uses no action. False (and no change) if choose_government_error says no.
func choose_government(uid: int) -> bool:
	return Anarchy.choose_government(self, uid)


## Why move_unit(uid, territory_uid) would refuse (163): game over or a pending decision, no action left, uid not a
## unit in the tableau, territory_uid not a settled territory, the unit's own station, or the unit moved this turn.
## "" if it can.
func move_unit_error(uid: int, territory_uid: int) -> String:
	return Military.move_error(self, uid, territory_uid)


## Stations unit uid on settled territory territory_uid (163); its home and worker stay. Uses an action. False (and no
## change) if move_unit_error says no.
func move_unit(uid: int, territory_uid: int) -> bool:
	return Military.move(self, uid, territory_uid)


## The settled territories unit uid can move to now (163), in tableau order; [] when unit_move_block says it can't.
func move_targets(uid: int) -> Array[int]:
	return Military.move_targets(self, uid)


## Why unit uid can't move anywhere now (163): move_unit_error's reasons that don't depend on the target, or nowhere
## else to go; "" when move_targets isn't empty.
func unit_move_block(uid: int) -> String:
	return Military.move_block(self, uid)


## Unit uid's strength (164): printed strength plus the training of working buildings on its station; 0 when idle or
## not a unit in the tableau.
func unit_strength(uid: int) -> int:
	return Military.unit_strength(self, uid)


## "Strength 3" for a unit trained by a building on its station (164), for its face; "" for anything else.
func unit_strength_tag(uid: int) -> String:
	return Military.strength_tag(self, uid)


## Why disband(uid) would refuse (163): game over or a pending decision, or uid not a unit in the tableau. "" if it can.
func disband_error(uid: int) -> String:
	return Military.disband_error(self, uid)


## Unit uid goes from the tableau to the discard, freeing its worker on its home (163). Uses no action. False (and no
## change) if disband_error says no.
func disband(uid: int) -> bool:
	return Military.disband(self, uid)


# --- Internals (the modules call these too) ---

## Unrest dropped: a ruling Anarchy keeps its lowered counters (155).
func _unrest_lowered() -> void:
	Anarchy.calm(self)


## Why action ("play", "grow", "buy", "end_turn", "supply", "discard", "research") is blocked by the game being over
## or by a pending() decision, or "". Only discarding, browsing the supply and learning techs go on while a discard is
## owed.
func _blocked_error(action: String) -> String:
	if is_over:
		return "The game is over."
	match state.pending.get("kind", ""):
		PENDING_GOVERNMENT:
			return "Choose a government first."
		PENDING_EXPLORE:
			return "Choose a territory first."
		PENDING_RENEWAL:
			var n: int = state.pending.count
			return "Anarchy: trash %d card%s from your discard first." % [n, "" if n == 1 else "s"]
		PENDING_DISCARD:
			return "" if _DISCARD_ALLOWS.has(action) else "Discard down to %d cards first." % config.hand_limit
	return ""


## The first reason a decision's own action (choose, renew, choose_government) refuses (172): the game being over,
## then another decision owed (its _blocked_error message), then nothing_owed when kind isn't owed; "" while kind is.
func _owed_error(kind: String, nothing_owed: String) -> String:
	if is_over:
		return "The game is over."
	var owed: String = state.pending.get("kind", "")
	if owed == "":
		return nothing_owed
	return "" if owed == kind else _blocked_error(kind)
