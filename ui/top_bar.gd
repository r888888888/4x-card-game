class_name TopBar
extends HBoxContainer
## The top bar: turn, food, wealth, insight (139) and unrest (144, out of its limit) (with next upkeep's change), score
## and pop, then
## (115) the civilization and government button (one since 119), Buy Cards, Knowledge, Log, End turn (120) and Menu. Any
## change to Food, Wealth, Insight, Unrest, Score or Pop floats its net change up from that counter (126).

const FOOD_COLOR := Palette.GAIN  # the food stat; CardView.WARN_COLOR when pop would starve
# Keys for counter() beside the resources (GameEngine.FOOD, WEALTH, INSIGHT, UNREST) (177).
const SCORE := "score"
const POP := "pop"
const TURN := "turn"

var score_label: Label
var menu_button: Button  # "Menu" (its key, Esc, is in its tooltip: 120)
var log_button: Button  # "Log": opens the log drawer (115); its key, L, is in its tooltip (120)
var end_turn_button: Button  # "End turn", or "Discard N (hand limit M)" while the hand is over its limit (120)
var _turn_label: Label
var _food_label: Label
var _wealth_label: Label
var _insight_label: Label
var _unrest_label: Label  # hidden while unrest is off (144)
var _pop_label: Label
var _identity: Button  # "Egypt · Chiefdom": opens the civilization and government modal; hidden with neither (119)
var _knowledge: Button  # opens the tech tree (059), where techs are learned (140)
var _shown := {}  # counter Label -> the value it last showed; empty for a fresh game, which floats nothing (126)


## on_knowledge opens the tech tree, on_identity the civilization and government modal, on_log toggles the log drawer.
func _init(on_menu: Callable, on_knowledge: Callable, on_identity: Callable, on_log: Callable) -> void:
	add_theme_constant_override("separation", 12)  # tight: the stats and six buttons share 1920 px (115, 139, 144)
	_turn_label = UIKit.stat(self)
	_food_label = UIKit.stat(self, FOOD_COLOR)
	_wealth_label = UIKit.stat(self, Palette.WEALTH)
	_insight_label = UIKit.stat(self, Palette.INSIGHT)
	_unrest_label = UIKit.stat(self, Palette.UNREST)
	for label in [_food_label, _wealth_label, _insight_label, _unrest_label]:
		label.mouse_filter = Control.MOUSE_FILTER_PASS  # for the forecast tooltip
	score_label = UIKit.stat(self, Palette.GAIN)
	_pop_label = UIKit.stat(self, Palette.POP)
	for label in [_turn_label, _food_label, _wealth_label, _insight_label, _unrest_label, score_label, _pop_label]:
		label.theme_type_variation = &"BarStat"
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(spacer)
	_identity = UIKit.button("", on_identity)
	_identity.tooltip_text = "Your civilization and government."
	_identity.hide()
	add_child(_identity)
	_knowledge = UIKit.button("Knowledge", on_knowledge)
	add_child(_knowledge)
	log_button = UIKit.button("Log", on_log)
	log_button.tooltip_text = "Shortcut: L. The game log: everything that happened."
	add_child(log_button)
	end_turn_button = UIKit.button("End turn", func(): Game.engine.end_turn())
	end_turn_button.theme_type_variation = "AccentButton"
	add_child(end_turn_button)
	menu_button = UIKit.button("Menu", on_menu)
	menu_button.tooltip_text = "Shortcut: Esc. New game, restart with a seed, reduce motion, exit."
	add_child(menu_button)


## The counter for key (a resource, SCORE, POP or TURN), or null for an unknown key (177).
func counter(key: String) -> Control:
	return {TURN: _turn_label, GameEngine.FOOD: _food_label, GameEngine.WEALTH: _wealth_label,
		GameEngine.INSIGHT: _insight_label, GameEngine.UNREST: _unrest_label, SCORE: score_label,
		POP: _pop_label}.get(key)


## The whole reading counter(key) shows ("Food: 3 (+1)"), or "" for an unknown key (177).
func counter_text(key: String) -> String:
	var label := counter(key) as Label
	return label.text if label != null else ""


## Forgets the values the counters showed, so a new game's first refresh floats nothing (126).
func reset_counters() -> void:
	_shown = {}


## Shows engine e's stats, pulsing the ones that changed, and floats each counter's change up from it on layer
## (126); quiet (a screen covering the bar shows its own) takes the new values without tokens.
func refresh(e: GameEngine, layer: Control = null, quiet := false) -> void:
	UIKit.set_stat(_turn_label, "Turn %d / %d" % [e.turn, e.turn_limit()])
	var forecast := e.upkeep_forecast()
	UIKit.set_stat(_food_label, "Food: %d%s" % [e.resources.get(GameEngine.FOOD, 0), _forecast_text(forecast, GameEngine.FOOD)])
	UIKit.set_stat(_wealth_label, "Wealth: %d%s" % [e.resources.get(GameEngine.WEALTH, 0), _forecast_text(forecast, GameEngine.WEALTH)])
	var starve: int = forecast.get("starve", 0)
	_food_label.add_theme_color_override("font_color", CardView.WARN_COLOR if starve > 0 else FOOD_COLOR)
	_food_label.tooltip_text = "Next upkeep: famine, %d pop will die." % starve if starve > 0 else "In brackets: change at the next upkeep, after pop eats."
	_wealth_label.tooltip_text = "In brackets: change at the next upkeep."
	UIKit.set_stat(_insight_label, "Insight: %d%s" % [e.resources.get(GameEngine.INSIGHT, 0), _forecast_text(forecast, GameEngine.INSIGHT)])
	_insight_label.tooltip_text = "Pays for techs. In brackets: change at the next upkeep."
	_refresh_unrest(e, forecast)
	UIKit.set_stat(score_label, "Score: %d" % e.score())
	_pop_label.visible = e.population_on()
	UIKit.set_stat(_pop_label, "Pop: %d" % e.total_pop())
	var names: PackedStringArray = []
	for zone_name in IdentityModal.ZONES:
		if not e.zone(zone_name).is_empty():
			names.append(e.zone(zone_name).cards[0].def.name)
	_identity.text = " · ".join(names)
	_identity.visible = not names.is_empty()
	var error := e.end_turn_error()
	end_turn_button.disabled = error != ""
	end_turn_button.tooltip_text = error if error != "" else "Shortcut: E. Upkeep, then draw up to your hand size."
	var pending := e.pending()
	if pending.get("kind", "") == GameEngine.PENDING_DISCARD:
		end_turn_button.text = "Discard %d (hand limit %d)" % [pending.count, e.hand_limit()]
	else:
		end_turn_button.text = "End turn"
	_knowledge.visible = e.research_on()
	_knowledge.tooltip_text = "Shortcut: T. The tech tree: every tech by era, what it costs now and what it gives.\nEra: %s." % (
		e.era_name(e.era()))  # the era is here, not on the button, to make room for Insight (139)
	if e.research_card_name() != "":
		_knowledge.tooltip_text += "\nPlay %s card for more insight." % UIKit.with_article(e.research_card_name())
	notification(NOTIFICATION_SORT_CHILDREN)  # lay the counters out at their new widths, so tokens start under them
	_float_changes({_food_label: [e.resources.get(GameEngine.FOOD, 0), GameEngine.FOOD],
		_wealth_label: [e.resources.get(GameEngine.WEALTH, 0), GameEngine.WEALTH],
		_insight_label: [e.resources.get(GameEngine.INSIGHT, 0), GameEngine.INSIGHT],
		_unrest_label: [e.resources.get(GameEngine.UNREST, 0), GameEngine.UNREST], score_label: [e.score(), "VP"],
		_pop_label: [e.total_pop(), "pop"]}, layer, quiet)


## "Unrest: 2 / 5 (+1)" ("Unrest: 2 (+1)" with no limit), in the warning colour at the limit; hidden while unrest is off.
func _refresh_unrest(e: GameEngine, forecast: Dictionary) -> void:
	_unrest_label.visible = e.unrest_on()
	var unrest: int = e.resources.get(GameEngine.UNREST, 0)
	var limit := e.unrest_limit()
	UIKit.set_stat(_unrest_label, "Unrest: %d%s%s" % [unrest, " / %d" % limit if limit >= 0 else "",
		_forecast_text(forecast, GameEngine.UNREST)])
	_unrest_label.add_theme_color_override("font_color", CardView.WARN_COLOR if e.at_unrest_limit() else Palette.UNREST)
	_unrest_label.tooltip_text = ("Civil unrest, out of the most your government tolerates%s. " % (
		"" if limit >= 0 else " (it sets no limit)")) + "In brackets: change at the next upkeep."


## Where the deck and discard are on screen (121): the Log button, whose drawer shows their counts. Dealt cards come
## from it; cards going to the deck or discard fly to it.
func pile_point() -> Vector2:
	return log_button.get_global_rect().get_center()


## "Log •" while the log has lines not yet seen (116).
func set_log_unread(unread: bool) -> void:
	log_button.text = "Log •" if unread else "Log"


## Puts the Supply button after the civilization and government.
func add_supply_button(button: Button) -> void:
	add_child(button)
	move_child(button, _knowledge.get_index())


## The civilization and government button (visible or not).
func identity_button() -> Button:
	return _identity


## Where a card leaving for the civilization and government button flies to (the government a player just played).
func identity_point() -> Vector2:
	return _identity.get_global_rect().get_center()


## For each counter in now (Label -> [value, unit], in the bar's order) whose value changed since it last showed, a
## "+N unit" / "−N unit" token floats up from just below it on layer, each Anim.TOKEN_STAGGER after the one before.
func _float_changes(now: Dictionary, layer: Control, quiet: bool) -> void:
	var n := 0
	for label: Label in now:
		var value: int = now[label][0]
		var change: int = value - _shown.get(label, value)
		_shown[label] = value
		if change == 0 or quiet or layer == null or not label.visible:
			continue
		var below := label.get_global_rect().get_center() + Vector2(0, label.size.y)
		UIKit.float_token(layer, "%s%d %s" % ["+" if change > 0 else "−", absi(change), now[label][1]], below,
			UIKit.GAIN_COLOR if change > 0 else UIKit.COST_COLOR, n * Anim.TOKEN_STAGGER)
		n += 1


## " (+2)" / " (-1)": the forecast change for resource, or "" when there is no next upkeep.
func _forecast_text(forecast: Dictionary, resource: String) -> String:
	if not forecast.has(resource):
		return ""
	return " (%+d)" % forecast[resource]
